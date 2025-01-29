#!/bin/bash

# Configuration
source .env
TEST_DURATION=30  # seconds
PAYLOAD_SIZE="10M"

# Create test file
dd if=/dev/urandom of=testfile bs=1M count=10 2>/dev/null

# Function to run tests against one endpoint
test_endpoint() {
    local endpoint=$1
    local provider=$2
    local instance_num=$3

    echo "Testing $provider instance $instance_num at $endpoint"
    
    # Latency test (100 pings)
    echo "Running latency test..."
    total_latency=0
    max_latency=0
    min_latency=999999
    latency_count=100

    for ((i=1; i<=latency_count; i++)); do
        latency=$(curl -w "%{time_total}" -o /dev/null -s "$endpoint/ping")
        total_latency=$(echo "$total_latency + $latency" | bc)
        if (( $(echo "$latency > $max_latency" | bc -l) )); then
            max_latency=$latency
        fi
        if (( $(echo "$latency < $min_latency" | bc -l) )); then
            min_latency=$latency
        fi
        sleep 0.1
    done

    avg_latency=$(echo "scale=4; $total_latency / $latency_count" | bc)
    echo "Latency results for $provider instance $instance_num: Avg = ${avg_latency}s, Max = ${max_latency}s, Min = ${min_latency}s"

    # Upload test
    echo "Running upload test..."
    upload_speeds=()
    for ((i=1; i<=10; i++)); do
        speed=$(curl -X POST -w "%{speed_upload}" -o /dev/null -s --data-binary "@testfile" "$endpoint/upload")
        upload_speeds+=("$speed")
        sleep 1
    done

    avg_upload_speed=$(echo "${upload_speeds[@]}" | awk '{sum=0; for (i=1; i<=NF; i++) sum+=$i; print sum/NF}')
    echo "Upload speed for $provider instance $instance_num: Avg = $(echo "scale=2; $avg_upload_speed/1024/1024" | bc) MB/s"

    # Download test
    echo "Running download test..."
    download_speeds=()
    for ((i=1; i<=10; i++)); do
        speed=$(curl -w "%{speed_download}" -o /dev/null -s "$endpoint/download/10485760")
        download_speeds+=("$speed")
        sleep 1
    done

    avg_download_speed=$(echo "${download_speeds[@]}" | awk '{sum=0; for (i=1; i<=NF; i++) sum+=$i; print sum/NF}')
    echo "Download speed for $provider instance $instance_num: Avg = $(echo "scale=2; $avg_download_speed/1024/1024" | bc) MB/s"
}

# Run tests for AWS instances
for i in {1..3}; do
    endpoint_var="AWS_ENDPOINT_${i}"
    test_endpoint "${!endpoint_var}" "AWS" "$i" &
done

# Run tests for GCP instances
for i in {1..3}; do
    endpoint_var="GCP_ENDPOINT_${i}"
    test_endpoint "${!endpoint_var}" "GCP" "$i" &
done

# Run tests for Azure instances
for i in {1..3}; do
    endpoint_var="AZURE_ENDPOINT_${i}"
    test_endpoint "${!endpoint_var}" "Azure" "$i" &
done

# Wait for all tests to complete
wait

# Cleanup
rm testfile

echo "All tests completed. Check Grafana dashboard at http://localhost:3000"
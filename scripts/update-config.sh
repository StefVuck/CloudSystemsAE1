#!/bin/bash

cd terraform
# Get the IPs from terraform output as JSON arrays
AWS_IPS=$(terraform output -json aws_public_ips | jq -r '.[]')
GCP_IPS=$(terraform output -json gcp_public_ips | jq -r '.[]')
AZURE_IPS=$(terraform output -json azure_public_ips | jq -r '.[]')


cd ../scripts
# Update .env file for test script
echo "# AWS Endpoints" > .env
counter=1
echo "$AWS_IPS" | while read -r ip; do
    echo "AWS_ENDPOINT_${counter}=http://${ip}:8080" >> .env
    ((counter++))
done

echo -e "\n# GCP Endpoints" >> .env
counter=1
echo "$GCP_IPS" | while read -r ip; do
    echo "GCP_ENDPOINT_${counter}=http://${ip}:8080" >> .env
    ((counter++))
done

echo -e "\n# Azure Endpoints" >> .env
counter=1
echo "$AZURE_IPS" | while read -r ip; do
    echo "AZURE_ENDPOINT_${counter}=http://${ip}:8080" >> .env
    ((counter++))
done

cd ../network-client
# Create prometheus.yml
cat > prometheus.yml << EOF
global:
  scrape_interval: 5s

scrape_configs:
  - job_name: 'cloud-performance'
    static_configs:
EOF

# Add AWS targets
echo "$AWS_IPS" | while read -r ip; do
    cat >> prometheus.yml << EOF
      - targets: ['${ip}:8080']
        labels:
          provider: 'aws'
EOF
done

# Add GCP targets
echo "$GCP_IPS" | while read -r ip; do
    cat >> prometheus.yml << EOF
      - targets: ['${ip}:8080']
        labels:
          provider: 'gcp'
EOF
done

# Add Azure targets
echo "$AZURE_IPS" | while read -r ip; do
    cat >> prometheus.yml << EOF
      - targets: ['${ip}:8080']
        labels:
          provider: 'azure'
EOF
done

# Restart prometheus container to pick up new config
docker-compose restart prometheus
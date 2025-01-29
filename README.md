# Cloud Performance Testing Framework

A framework for testing and comparing performance across multiple cloud providers (AWS, GCP, Azure).

## Prerequisites

- Terraform >= 1.0
- Go >= 1.19
- Docker and Docker Compose
- AWS CLI configured with appropriate credentials
- GCP CLI (`gcloud`) with application-default login configured
- Azure CLI (`az`) logged into your account

## Setup

1. Build the Go application:
```bash
cd network-perf
GOOS=linux GOARCH=arm64 go build -o server-binary main.go
# Host the binary somewhere accessible (e.g., GitHub releases, S3)
```

2. Create `terraform.tfvars` from `terraform.tfvars.example`:

See [Terraform Setup](#terraform-setup) for more.


3. Set up cloud provider access:
```bash
# AWS
aws configure

# GCP
gcloud auth application-default login

# Azure
az login
```

4. Initialize and apply Terraform:
```bash
cd terraform
terraform init
terraform apply
```

5. Update monitoring configuration:
```bash
./scripts/update-config.sh
```

6. Start monitoring stack:
```bash
cd network-client
docker-compose up -d
```

7. Run performance tests:
```bash
./scripts/test.sh
```

## Architecture

This framework deploys:
- 3 VMs in AWS (t2.micro)
- 3 VMs in GCP (e2-micro)
- 3 VMs in Azure (Standard_B1s)

Each VM runs a Go application that exposes:
- `/ping` for latency testing
- `/upload` for upload speed testing
- `/download/{size}` for download speed testing
- `/metrics` for Prometheus metrics (unused)

Monitoring:
- Prometheus collects metrics from all VMs
- Grafana provides visualization dashboards
- Tests measure latency, throughput, and error rates

Security:
- All VMs have port 8080 open for testing
- SSH access is configured with your public key
- Each cloud has appropriate firewall/security group rules

## File Structure
```
cloud-performance-test/
├── terraform/              # Infrastructure as Code
├── app/                    # Go application
├── monitoring/             # Prometheus & Grafana
└── scripts/               # Test and configuration scripts
```

## Accessing Dashboards

Once running:
- Grafana: http://localhost:3000 (admin/admin)
- Prometheus: http://localhost:9090


## Extra
###  Terraform Setup
#### GCP Variables:
>    Read from GUI under Projects

For gcp_credentials_file:
```bash
# Install gcloud CLI if not already installed
# Then run:
gcloud auth application-default login
# This creates credentials.json, for you to copy the path to
```
#### Azure Variables:

```bash
╰─ # Get subscription ID
az account show --query id --output tsv

# Get tenant ID
az account show --query tenantId --output tsv
```

#### SSH Key:
```bash
# Generate if you don't have one
ssh-keygen -t rsa -b 4096

# Get ssh_public_key content
cat ~/.ssh/id_rsa.pub
```
#### App Binary URL:
```bash
# Upload to AWS S3
aws s3 mb s3://my-performance-test-bucket
aws s3 cp ./app/performance-test s3://my-performance-test-bucket/
aws s3 presign s3://my-performance-test-bucket/performance-test --expires-in 604800
# This gives you a temporary URL valid for 7 days
```

## Grafana Panes:
Legend should always be set to `{{provider}}`

### Latency:
`rate(network_latency_seconds_sum[1m]) / rate(network_latency_seconds_count[1m])`

### Download Throughput
`rate(network_throughput_bytes_total{direction="download"}[1m])`

### Upload Throughput
`rate(network_throughput_bytes_total{direction="upload"}[1m])`

### Error Rate
`rate(network_connection_errors_total[1m])`



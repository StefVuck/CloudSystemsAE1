To run this, you want `scp` the `network-perf/` folder onto your VM, and make sure that you have set your inbound port rules to allow port 8080.

You can then run the following (for ubuntu):
```bash
sudo apt update && sudo apt install golang-go -y
cd network-perf && go build && GIN_MODE=release ./network-perf
```
And now it should look "frozen" and you should have this VM ready.

Once you have all VMs ready you can proceed with the: [[#network-client]]

# network-client
You should create a .env file with the following format:
```
AWS_ENDPOINT="http://<public-ip>:8080"
GCP_ENDPOINT="http://<public-ip>:8080"
AZURE_ENDPOINT="http://<public-ip>:8080"
```

This folder contains the code to be run on the client testing the different cloud providers, you should `docker-compose up` before running the `test.sh` script

Once it runs you should open the grafana dashboard at `http://localhost:3000`, using default user `admin` and password `admin`
Grafana should add `http://prometheus:9090` as a datasource and then you should create a dashboard with the following panes

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



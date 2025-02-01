#!/bin/bash
set -e

# Install necessary dependencies
apt-get update
apt-get install -y wget systemd curl

# Create a dedicated user for running the application
useradd -m -s /bin/bash performanceapp

# Create directory for the application
mkdir -p /opt/performance-test
cd /opt/performance-test

# Download the application binary
wget ${APP_BINARY_URL} -O performance-test
chmod +x performance-test

# Set ownership
chown -R performanceapp:performanceapp /opt/performance-test

# Create systemd service
cat > /etc/systemd/system/performance-test.service << EOF
[Unit]
Description=Performance Test Service
After=network.target

[Service]
Type=simple
User=performanceapp
WorkingDirectory=/opt/performance-test
ExecStart=/opt/performance-test/performance-test
Restart=always
RestartSec=5

# Security settings
ProtectSystem=full
PrivateTmp=true
NoNewPrivileges=true

# Environment
Environment=PORT=8080

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
systemctl daemon-reload
systemctl enable performance-test
systemctl start performance-test

# Wait for the service to be up
for i in {1..30}; do
    if curl -s http://localhost:8080/ping > /dev/null; then
        echo "Service is up!"
        exit 0
    fi
    sleep 2
done

echo "Service failed to start within 60 seconds"
exit 1
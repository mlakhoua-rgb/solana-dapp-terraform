#!/bin/bash
set -e

# Update system packages
yum update -y

# Install Node.js and npm
curl -sL https://rpm.nodesource.com/setup_20.x | bash -
yum install -y nodejs

# Install pnpm
npm install -g pnpm

# Install git
yum install -y git

# Install CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm

# Create application directory
mkdir -p /opt/solana-dapp
cd /opt/solana-dapp

# Clone the repository (replace with your actual repo)
git clone https://github.com/mlakhoua-rgb/solana-dapp-poc.git .

# Install dependencies
pnpm install

# Build the application
pnpm build

# Create systemd service for the application
cat > /etc/systemd/system/solana-dapp.service << 'EOF'
[Unit]
Description=Solana dApp
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/opt/solana-dapp
ExecStart=/usr/bin/node dist/index.js
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
Environment="NODE_ENV=production"
Environment="PORT=3000"

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
systemctl daemon-reload
systemctl enable solana-dapp
systemctl start solana-dapp

# Configure CloudWatch agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/config.json << 'EOF'
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/messages",
            "log_group_name": "/aws/ec2/${environment}/system",
            "log_stream_name": "{instance_id}"
          },
          {
            "file_path": "/var/log/secure",
            "log_group_name": "/aws/ec2/${environment}/auth",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  },
  "metrics": {
    "namespace": "SolanaDApp",
    "metrics_collected": {
      "cpu": {
        "measurement": [
          {
            "name": "cpu_usage_idle",
            "rename": "CPU_IDLE",
            "unit": "Percent"
          },
          "cpu_usage_iowait"
        ],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": [
          {
            "name": "used_percent",
            "rename": "DISK_USED",
            "unit": "Percent"
          }
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "/"
        ]
      },
      "mem": {
        "measurement": [
          {
            "name": "mem_used_percent",
            "rename": "MEM_USED",
            "unit": "Percent"
          }
        ],
        "metrics_collection_interval": 60
      }
    }
  }
}
EOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json

echo "Solana dApp deployment completed successfully"

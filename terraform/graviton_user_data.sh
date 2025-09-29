#!/bin/bash

# Graviton-optimized user data script for AI workloads
# This script optimizes the system for AI inference tasks

# Update system with ARM64 optimizations
yum update -y

# Install performance monitoring tools
yum install -y htop iotop nethogs sysstat

# Install Docker with ARM64 optimizations
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Configure Docker for AI workloads
cat > /etc/docker/daemon.json << EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "default-ulimits": {
    "memlock": {
      "Hard": -1,
      "Name": "memlock",
      "Soft": -1
    }
  },
  "default-shm-size": "2g"
}
EOF

systemctl restart docker

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

# Login to ECR
aws ecr get-login-password --region ${aws_region} | docker login --username AWS --password-stdin ${ecr_repo_url}

# Create application directory
mkdir -p /opt/app
cd /opt/app

# Create optimized docker-compose.yml for AI workloads
cat > docker-compose.yml << EOF
version: '3.8'
services:
  app:
    image: ${ecr_repo_url}:latest
    ports:
      - "8000:8000"
    environment:
      - DATABASE_URL=${database_url}
      - REDIS_URL=${redis_url}
      - AWS_REGION=${aws_region}
      - WORKERS=4
      - MAX_REQUESTS=1000
      - MAX_REQUESTS_JITTER=100
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 3G
        reservations:
          memory: 2G
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    # Optimize for AI workloads
    ulimits:
      memlock:
        soft: -1
        hard: -1
    shm_size: 2g
    tmpfs:
      - /tmp:size=1g,noexec,nosuid,nodev
EOF

# Create systemd service for the application
cat > /etc/systemd/system/ai-app.service << EOF
[Unit]
Description=Multi-tenant AI Application
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/app
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
systemctl enable ai-app.service
systemctl start ai-app.service

# Configure system optimizations for AI workloads
echo 'vm.swappiness=10' >> /etc/sysctl.conf
echo 'vm.dirty_ratio=15' >> /etc/sysctl.conf
echo 'vm.dirty_background_ratio=5' >> /etc/sysctl.conf
echo 'net.core.somaxconn=65535' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_max_syn_backlog=65535' >> /etc/sysctl.conf

# Apply sysctl changes
sysctl -p

# Setup log rotation for AI workloads
cat > /etc/logrotate.d/ai-app << EOF
/opt/app/logs/*.log {
  rotate 7
  daily
  compress
  size=100M
  missingok
  delaycompress
  copytruncate
  notifempty
}
EOF

# Create monitoring script for AI metrics
cat > /opt/app/monitor.sh << 'EOF'
#!/bin/bash

# Custom CloudWatch metrics for AI workloads
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)

# Get application metrics
APP_RESPONSE_TIME=$(curl -s -w "%{time_total}" -o /dev/null http://localhost:8000/health)
APP_CPU_USAGE=$(docker stats --no-stream --format "table {{.CPUPerc}}" ai-app_app_1 | tail -n 1 | sed 's/%//')
APP_MEMORY_USAGE=$(docker stats --no-stream --format "table {{.MemUsage}}" ai-app_app_1 | tail -n 1 | awk '{print $1}' | sed 's/[^0-9.]//g')

# Send custom metrics to CloudWatch
aws cloudwatch put-metric-data \
  --namespace "Custom/AI" \
  --metric-data MetricName=ResponseTime,Value=$APP_RESPONSE_TIME,Unit=Seconds \
  --region $REGION

aws cloudwatch put-metric-data \
  --namespace "Custom/AI" \
  --metric-data MetricName=AppCPUUsage,Value=$APP_CPU_USAGE,Unit=Percent \
  --region $REGION

aws cloudwatch put-metric-data \
  --namespace "Custom/AI" \
  --metric-data MetricName=AppMemoryUsage,Value=$APP_MEMORY_USAGE,Unit=Bytes \
  --region $REGION
EOF

chmod +x /opt/app/monitor.sh

# Setup cron job for monitoring
echo "*/5 * * * * /opt/app/monitor.sh" | crontab -

# Install CloudWatch agent for enhanced monitoring
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/arm64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm

# Configure CloudWatch agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << EOF
{
  "metrics": {
    "namespace": "CWAgent",
    "metrics_collected": {
      "cpu": {
        "measurement": ["cpu_usage_idle", "cpu_usage_iowait", "cpu_usage_user", "cpu_usage_system"],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": ["used_percent"],
        "metrics_collection_interval": 60,
        "resources": ["*"]
      },
      "diskio": {
        "measurement": ["io_time"],
        "metrics_collection_interval": 60,
        "resources": ["*"]
      },
      "mem": {
        "measurement": ["mem_used_percent"],
        "metrics_collection_interval": 60
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/opt/app/logs/app.log",
            "log_group_name": "/aws/ec2/ai-app",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  }
}
EOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
  -s

echo "Graviton-optimized AI application setup completed successfully!"

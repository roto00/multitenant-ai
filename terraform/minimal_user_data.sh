#!/bin/bash

# Minimal startup user data script
# Optimized for cost and simplicity

# Update system
yum update -y

# Install Docker
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

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

# Create minimal docker-compose.yml
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
      - WORKERS=2
      - MAX_REQUESTS=100
      - MAX_REQUESTS_JITTER=10
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    # Minimal resource limits
    deploy:
      resources:
        limits:
          memory: 1G
        reservations:
          memory: 512M
EOF

# Create systemd service
cat > /etc/systemd/system/ai-app.service << EOF
[Unit]
Description=Minimal Multi-tenant AI Application
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

# Setup basic log rotation
cat > /etc/logrotate.d/ai-app << EOF
/opt/app/logs/*.log {
  rotate 3
  daily
  compress
  size=10M
  missingok
  delaycompress
  copytruncate
  notifempty
}
EOF

echo "Minimal startup configuration completed successfully!"

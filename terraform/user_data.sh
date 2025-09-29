#!/bin/bash

# User data script for EC2 instances
# This script sets up Docker and runs the application

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

# Login to ECR
aws ecr get-login-password --region ${aws_region} | docker login --username AWS --password-stdin ${ecr_repo_url}

# Create application directory
mkdir -p /opt/app
cd /opt/app

# Create docker-compose.yml
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
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
EOF

# Start the application
docker-compose up -d

# Setup log rotation
cat > /etc/logrotate.d/docker << EOF
/var/lib/docker/containers/*/*.log {
  rotate 7
  daily
  compress
  size=1M
  missingok
  delaycompress
  copytruncate
}
EOF

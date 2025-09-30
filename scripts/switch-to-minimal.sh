#!/bin/bash

# Switch to Minimal POC Deployment
# This script switches from the full POC to a minimal version for faster deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Switching to Minimal POC Deployment${NC}"
echo -e "${YELLOW}This will create a simplified version that deploys in ~5-8 minutes${NC}"
echo ""

# Navigate to terraform directory
cd /home/robthomas/git/mutlitenant-ai/terraform

# Backup current configuration
echo -e "${YELLOW}Backing up current configuration...${NC}"
mkdir -p backup-$(date +%Y%m%d-%H%M%S)
cp *.tf backup-$(date +%Y%m%d-%H%M%S)/ 2>/dev/null || true

# Move current files to alternatives
echo -e "${YELLOW}Moving current files to alternatives...${NC}"
mkdir -p alternatives
mv main.tf poc-isolated.tf eks-autoscaling.tf alternatives/ 2>/dev/null || true

# Use minimal configuration
echo -e "${YELLOW}Using minimal POC configuration...${NC}"
cp minimal-poc.tf main.tf

# Initialize terraform with new configuration
echo -e "${YELLOW}Initializing Terraform...${NC}"
terraform init

# Show what will be deployed
echo -e "${GREEN}Minimal POC will deploy:${NC}"
echo "✅ Single VPC with 1 public subnet (us-west-2a only)"
echo "✅ Single RDS PostgreSQL instance (shared for both tenants)"
echo "✅ Single Redis instance (shared for both tenants)"
echo "✅ Single ECS Fargate service"
echo "✅ Application Load Balancer"
echo "✅ S3 bucket for shared storage"
echo "✅ CloudWatch logging"
echo ""
echo -e "${YELLOW}Estimated deployment time: 5-8 minutes${NC}"
echo -e "${YELLOW}Estimated monthly cost: $45-65${NC}"
echo ""

# Ask for confirmation
read -p "Do you want to deploy the minimal POC? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}Deploying minimal POC...${NC}"
    terraform apply -auto-approve
else
    echo -e "${YELLOW}Deployment cancelled. You can run 'terraform apply' when ready.${NC}"
fi

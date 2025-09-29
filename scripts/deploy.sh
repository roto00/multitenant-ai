#!/bin/bash

# Multi-tenant AI Platform Deployment Script
# This script deploys the entire infrastructure and application

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
AWS_REGION=${AWS_REGION:-us-east-1}
PROJECT_NAME=${PROJECT_NAME:-multitenant-ai}
ENVIRONMENT=${ENVIRONMENT:-prod}

echo -e "${GREEN}Starting deployment of Multi-tenant AI Platform${NC}"

# Check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}Checking prerequisites...${NC}"
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        echo -e "${RED}AWS CLI is not installed. Please install it first.${NC}"
        exit 1
    fi
    
    # Check if Terraform is installed
    if ! command -v terraform &> /dev/null; then
        echo -e "${RED}Terraform is not installed. Please install it first.${NC}"
        exit 1
    fi
    
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Docker is not installed. Please install it first.${NC}"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        echo -e "${RED}AWS credentials not configured. Please run 'aws configure'${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Prerequisites check passed${NC}"
}

# Deploy infrastructure
deploy_infrastructure() {
    echo -e "${YELLOW}Deploying infrastructure with Terraform...${NC}"
    
    cd terraform
    
    # Initialize Terraform
    terraform init
    
    # Check if terraform.tfvars exists
    if [ ! -f "terraform.tfvars" ]; then
        echo -e "${YELLOW}Creating terraform.tfvars from example...${NC}"
        cp terraform.tfvars.example terraform.tfvars
        echo -e "${RED}Please edit terraform.tfvars with your configuration before continuing${NC}"
        exit 1
    fi
    
    # Plan and apply
    terraform plan
    terraform apply -auto-approve
    
    # Get outputs
    ECR_REPO_URL=$(terraform output -raw ecr_repository_url)
    ALB_DNS_NAME=$(terraform output -raw alb_dns_name)
    
    echo -e "${GREEN}Infrastructure deployed successfully${NC}"
    echo -e "${GREEN}ECR Repository: $ECR_REPO_URL${NC}"
    echo -e "${GREEN}Load Balancer: $ALB_DNS_NAME${NC}"
    
    cd ..
}

# Build and push Docker images
build_and_push_images() {
    echo -e "${YELLOW}Building and pushing Docker images...${NC}"
    
    # Get ECR repository URL
    ECR_REPO_URL=$(cd terraform && terraform output -raw ecr_repository_url)
    
    # Login to ECR
    aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPO_URL
    
    # Build and push backend
    echo -e "${YELLOW}Building backend image...${NC}"
    cd backend
    docker build -t $ECR_REPO_URL:latest .
    docker push $ECR_REPO_URL:latest
    cd ..
    
    # Build and push frontend
    echo -e "${YELLOW}Building frontend image...${NC}"
    cd frontend
    docker build -t $ECR_REPO_URL-frontend:latest .
    docker push $ECR_REPO_URL-frontend:latest
    cd ..
    
    echo -e "${GREEN}Images built and pushed successfully${NC}"
}

# Update ECS service
update_ecs_service() {
    echo -e "${YELLOW}Updating ECS service...${NC}"
    
    CLUSTER_NAME=$(cd terraform && terraform output -raw ecs_cluster_name)
    SERVICE_NAME=$(cd terraform && terraform output -raw ecs_service_name)
    
    aws ecs update-service \
        --cluster $CLUSTER_NAME \
        --service $SERVICE_NAME \
        --force-new-deployment \
        --region $AWS_REGION
    
    echo -e "${GREEN}ECS service update initiated${NC}"
}

# Wait for deployment
wait_for_deployment() {
    echo -e "${YELLOW}Waiting for deployment to complete...${NC}"
    
    CLUSTER_NAME=$(cd terraform && terraform output -raw ecs_cluster_name)
    SERVICE_NAME=$(cd terraform && terraform output -raw ecs_service_name)
    
    aws ecs wait services-stable \
        --cluster $CLUSTER_NAME \
        --services $SERVICE_NAME \
        --region $AWS_REGION
    
    echo -e "${GREEN}Deployment completed successfully${NC}"
}

# Main deployment function
main() {
    check_prerequisites
    deploy_infrastructure
    build_and_push_images
    update_ecs_service
    wait_for_deployment
    
    ALB_DNS_NAME=$(cd terraform && terraform output -raw alb_dns_name)
    
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Deployment completed successfully!${NC}"
    echo -e "${GREEN}Application URL: http://$ALB_DNS_NAME${NC}"
    echo -e "${GREEN}========================================${NC}"
}

# Run main function
main "$@"

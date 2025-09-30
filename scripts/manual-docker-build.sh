#!/bin/bash

# Manual Docker Build Script for Multi-Tenant AI Platform
# This script builds the Docker image locally and pushes to ECR

set -e

echo "🚀 Starting Manual Docker Build for Multi-Tenant AI Platform..."

# Configuration
AWS_REGION="us-west-2"
ECR_REPO_URL="665832050599.dkr.ecr.us-west-2.amazonaws.com/multitenant-ai-minimal-backend"
IMAGE_TAG="latest"

echo "📦 ECR Repository: $ECR_REPO_URL"
echo "🏷️  Image Tag: $IMAGE_TAG"

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker and try again."
    exit 1
fi

# Authenticate with ECR
echo "🔐 Authenticating with ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPO_URL

# Build the Docker image
echo "🏗️  Building Docker image..."
cd backend
docker build -t multitenant-ai-minimal-backend:$IMAGE_TAG .

# Tag the image for ECR
echo "🏷️  Tagging image for ECR..."
docker tag multitenant-ai-minimal-backend:$IMAGE_TAG $ECR_REPO_URL:$IMAGE_TAG

# Push the image to ECR
echo "📤 Pushing image to ECR..."
docker push $ECR_REPO_URL:$IMAGE_TAG

echo "✅ Docker image built and pushed successfully!"

# Get infrastructure details
cd ../terraform
ALB_DNS=$(terraform output -raw alb_dns_name)
DB_ENDPOINT=$(terraform output -raw database_endpoint)
REDIS_ENDPOINT=$(terraform output -raw redis_endpoint)
S3_BUCKET=$(terraform output -raw s3_bucket_name)

echo ""
echo "🎉 Build Complete!"
echo "================================"
echo "🌐 Application URL: http://$ALB_DNS"
echo "📦 ECR Repository: $ECR_REPO_URL"
echo "🗄️  Database: $DB_ENDPOINT"
echo "⚡ Redis: $REDIS_ENDPOINT"
echo "📁 S3 Bucket: $S3_BUCKET"
echo ""
echo "🔧 Next Steps:"
echo "1. Update ECS task definition with new image"
echo "2. Deploy frontend admin dashboard"
echo "3. Configure monitoring and alerts"
echo "4. Test multi-tenant functionality"
echo ""

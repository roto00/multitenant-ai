#!/bin/bash

# Build and Deploy Script for Multi-Tenant AI Platform
# Run this script with sudo: sudo ./scripts/build-and-deploy.sh

set -e

echo "🚀 Starting Multi-Tenant AI Platform Deployment..."

# Get the ECR repository URL
ECR_REPO_URL=$(cd terraform && terraform output -raw ecr_repository_url)
echo "📦 ECR Repository: $ECR_REPO_URL"

# Authenticate with ECR
echo "🔐 Authenticating with ECR..."
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin $ECR_REPO_URL

# Build the Docker image
echo "🏗️  Building Docker image..."
cd backend
docker build -t multitenant-ai-minimal-backend .

# Tag the image for ECR
echo "🏷️  Tagging image for ECR..."
docker tag multitenant-ai-minimal-backend:latest $ECR_REPO_URL:latest

# Push the image to ECR
echo "📤 Pushing image to ECR..."
docker push $ECR_REPO_URL:latest

echo "✅ Docker image built and pushed successfully!"

# Get infrastructure details
cd ../terraform
ALB_DNS=$(terraform output -raw alb_dns_name)
DB_ENDPOINT=$(terraform output -raw database_endpoint)
REDIS_ENDPOINT=$(terraform output -raw redis_endpoint)
S3_BUCKET=$(terraform output -raw s3_bucket_name)

echo ""
echo "🎉 Deployment Complete!"
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

#!/bin/bash

# Multi-tenant AI Platform - Service Management Script
# This script helps you easily shutdown and startup AWS services to save costs

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
AWS_REGION="us-west-2"
CLUSTER_NAME="multitenant-ai-minimal-cluster"
SERVICE_NAME="multitenant-ai-minimal-service"
DB_INSTANCE_ID="multitenant-ai-minimal-db"
REDIS_GROUP_ID="multitenant-ai-minimal-redis"

echo -e "${BLUE}🤖 Multi-tenant AI Platform - Service Management${NC}"
echo "=================================================="

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}Checking prerequisites...${NC}"
    
    if ! command_exists aws; then
        echo -e "${RED}❌ AWS CLI not found. Please install it first.${NC}"
        exit 1
    fi
    
    if ! command_exists terraform; then
        echo -e "${RED}❌ Terraform not found. Please install it first.${NC}"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        echo -e "${RED}❌ AWS credentials not configured. Please run 'aws configure' first.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Prerequisites check passed${NC}"
}

# Function to get current status
get_status() {
    echo -e "${BLUE}📊 Current Service Status:${NC}"
    echo "=========================="
    
    # ECS Service Status
    echo -e "${YELLOW}ECS Service:${NC}"
    aws ecs describe-services \
        --cluster $CLUSTER_NAME \
        --services $SERVICE_NAME \
        --region $AWS_REGION \
        --query 'services[0].{Status:status,RunningCount:runningCount,DesiredCount:desiredCount}' \
        --output table 2>/dev/null || echo "  Service not found or not accessible"
    
    # RDS Status
    echo -e "${YELLOW}RDS Database:${NC}"
    aws rds describe-db-instances \
        --db-instance-identifier $DB_INSTANCE_ID \
        --region $AWS_REGION \
        --query 'DBInstances[0].{Status:DBInstanceStatus,Class:DBInstanceClass}' \
        --output table 2>/dev/null || echo "  Database not found or not accessible"
    
    # ElastiCache Status
    echo -e "${YELLOW}ElastiCache Redis:${NC}"
    aws elasticache describe-replication-groups \
        --replication-group-id $REDIS_GROUP_ID \
        --region $AWS_REGION \
        --query 'ReplicationGroups[0].{Status:Status,NodeType:CacheNodeType}' \
        --output table 2>/dev/null || echo "  Redis cluster not found or not accessible"
    
    echo ""
}

# Function to shutdown services
shutdown_services() {
    echo -e "${RED}🛑 Shutting down services to save costs...${NC}"
    echo "============================================="
    
    # 1. Scale down ECS service
    echo -e "${YELLOW}1. Scaling down ECS service...${NC}"
    aws ecs update-service \
        --cluster $CLUSTER_NAME \
        --service $SERVICE_NAME \
        --desired-count 0 \
        --region $AWS_REGION \
        --output table
    
    echo -e "${GREEN}✅ ECS service scaled down to 0 tasks${NC}"
    
    # 2. Stop RDS database
    echo -e "${YELLOW}2. Stopping RDS database...${NC}"
    aws rds stop-db-instance \
        --db-instance-identifier $DB_INSTANCE_ID \
        --region $AWS_REGION \
        --output table
    
    echo -e "${GREEN}✅ RDS database stopped${NC}"
    
    # 3. Delete ElastiCache cluster
    echo -e "${YELLOW}3. Deleting ElastiCache cluster...${NC}"
    aws elasticache delete-replication-group \
        --replication-group-id $REDIS_GROUP_ID \
        --region $AWS_REGION \
        --output table
    
    echo -e "${GREEN}✅ ElastiCache cluster deleted${NC}"
    
    echo ""
    echo -e "${GREEN}🎉 All services have been shut down!${NC}"
    echo -e "${YELLOW}💰 You're now saving costs on:${NC}"
    echo "   • ECS Fargate tasks (0 running)"
    echo "   • RDS database (stopped)"
    echo "   • ElastiCache Redis (deleted)"
    echo ""
    echo -e "${BLUE}💡 To restart services, run: $0 start${NC}"
}

# Function to startup services
startup_services() {
    echo -e "${GREEN}🚀 Starting up services...${NC}"
    echo "============================="
    
    # 1. Start RDS database
    echo -e "${YELLOW}1. Starting RDS database...${NC}"
    aws rds start-db-instance \
        --db-instance-identifier $DB_INSTANCE_ID \
        --region $AWS_REGION \
        --output table
    
    echo -e "${GREEN}✅ RDS database starting up${NC}"
    
    # 2. Recreate ElastiCache cluster using Terraform
    echo -e "${YELLOW}2. Recreating ElastiCache cluster...${NC}"
    cd terraform
    terraform apply -target=aws_elasticache_replication_group.main -auto-approve
    cd ..
    
    echo -e "${GREEN}✅ ElastiCache cluster recreated${NC}"
    
    # 3. Wait for database to be available
    echo -e "${YELLOW}3. Waiting for database to be available...${NC}"
    aws rds wait db-instance-available \
        --db-instance-identifier $DB_INSTANCE_ID \
        --region $AWS_REGION
    
    echo -e "${GREEN}✅ Database is now available${NC}"
    
    # 4. Scale up ECS service
    echo -e "${YELLOW}4. Scaling up ECS service...${NC}"
    aws ecs update-service \
        --cluster $CLUSTER_NAME \
        --service $SERVICE_NAME \
        --desired-count 1 \
        --region $AWS_REGION \
        --output table
    
    echo -e "${GREEN}✅ ECS service scaled up to 1 task${NC}"
    
    # 5. Wait for service to be stable
    echo -e "${YELLOW}5. Waiting for service to be stable...${NC}"
    aws ecs wait services-stable \
        --cluster $CLUSTER_NAME \
        --services $SERVICE_NAME \
        --region $AWS_REGION
    
    echo ""
    echo -e "${GREEN}🎉 All services are now running!${NC}"
    
    # Get the ALB URL
    ALB_URL=$(cd terraform && terraform output -raw alb_dns_name 2>/dev/null || echo "Not available")
    if [ "$ALB_URL" != "Not available" ]; then
        echo -e "${BLUE}🌐 Your application is available at:${NC}"
        echo "   http://$ALB_URL"
        echo "   http://$ALB_URL/docs (API Documentation)"
        echo "   http://$ALB_URL/ping (Health Check)"
    fi
}

# Function to show help
show_help() {
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  status    Show current status of all services"
    echo "  shutdown  Shutdown all services to save costs"
    echo "  start     Start all services"
    echo "  help      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 status     # Check current status"
    echo "  $0 shutdown   # Turn off everything to save money"
    echo "  $0 start      # Turn everything back on"
    echo ""
    echo "Cost Savings:"
    echo "  • ECS Fargate: ~$0.04/hour per task"
    echo "  • RDS db.t3.micro: ~$0.017/hour when running"
    echo "  • ElastiCache: ~$0.017/hour when running"
    echo "  • Total savings: ~$0.09/hour when shut down"
}

# Main script logic
main() {
    check_prerequisites
    
    case "${1:-help}" in
        "status")
            get_status
            ;;
        "shutdown")
            get_status
            echo ""
            read -p "Are you sure you want to shutdown all services? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                shutdown_services
            else
                echo -e "${YELLOW}Operation cancelled.${NC}"
            fi
            ;;
        "start")
            get_status
            echo ""
            read -p "Are you sure you want to start all services? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                startup_services
            else
                echo -e "${YELLOW}Operation cancelled.${NC}"
            fi
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

# Run main function with all arguments
main "$@"

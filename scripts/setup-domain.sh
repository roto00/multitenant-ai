#!/bin/bash

# Setup Domain for Multi-tenant AI Platform
# This script helps you configure a custom domain for your application

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🌐 Multi-tenant AI Platform - Domain Setup${NC}"
echo "=================================================="

# Check if domain is provided
if [ -z "$1" ]; then
    echo -e "${YELLOW}Usage: $0 <domain-name>${NC}"
    echo ""
    echo "Examples:"
    echo "  $0 ai.yourdomain.com"
    echo "  $0 multitenant.yourdomain.com"
    echo "  $0 demo.yourdomain.com"
    echo ""
    echo -e "${YELLOW}Note: You need to own the domain or have access to its DNS settings.${NC}"
    exit 1
fi

DOMAIN_NAME="$1"
echo -e "${GREEN}Setting up domain: ${DOMAIN_NAME}${NC}"

# Change to terraform directory
cd "$(dirname "$0")/../terraform"

echo -e "${YELLOW}Step 1: Updating Terraform configuration...${NC}"
terraform apply -var="domain_name=${DOMAIN_NAME}" -auto-approve

echo -e "${YELLOW}Step 2: Getting Route53 name servers...${NC}"
NAME_SERVERS=$(terraform output -json route53_name_servers | jq -r '.[]')

echo -e "${GREEN}✅ Route53 hosted zone created successfully!${NC}"
echo ""
echo -e "${BLUE}📋 Next Steps:${NC}"
echo "1. Go to your domain registrar (where you bought the domain)"
echo "2. Update the nameservers to:"
for ns in $NAME_SERVERS; do
    echo "   - $ns"
done
echo ""
echo -e "${YELLOW}⚠️  Important:${NC}"
echo "- DNS propagation can take 24-48 hours"
echo "- You can test immediately using the ALB URL:"
ALB_URL=$(terraform output -raw alb_dns_name)
echo "   http://${ALB_URL}"
echo ""
echo -e "${GREEN}🎉 Once DNS propagates, your app will be available at:${NC}"
echo "   http://${DOMAIN_NAME}"
echo "   http://www.${DOMAIN_NAME}"
echo ""
echo -e "${BLUE}📚 API Documentation will be at:${NC}"
echo "   http://${DOMAIN_NAME}/docs"

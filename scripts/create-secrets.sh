#!/bin/bash

# Create Secrets for Multi-Tenant AI Platform POC
# This script creates all necessary secrets in AWS Secrets Manager

set -e

# Configuration
AWS_REGION="us-west-2"
PROJECT_NAME="multitenant-ai-poc"
ACCOUNT_ID="665832050599"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Creating secrets for Multi-Tenant AI Platform POC${NC}"
echo -e "${YELLOW}Account: ${ACCOUNT_ID}${NC}"
echo -e "${YELLOW}Region: ${AWS_REGION}${NC}"
echo ""

# Function to create secret
create_secret() {
    local secret_name="$1"
    local secret_value="$2"
    local description="$3"
    
    echo -e "${YELLOW}Creating secret: ${secret_name}${NC}"
    
    # Check if secret already exists
    if aws secretsmanager describe-secret --secret-id "$secret_name" --region "$AWS_REGION" >/dev/null 2>&1; then
        echo -e "${YELLOW}Secret ${secret_name} already exists. Updating...${NC}"
        aws secretsmanager update-secret \
            --secret-id "$secret_name" \
            --secret-string "$secret_value" \
            --region "$AWS_REGION" \
            --description "$description"
    else
        aws secretsmanager create-secret \
            --name "$secret_name" \
            --secret-string "$secret_value" \
            --description "$description" \
            --region "$AWS_REGION"
    fi
    
    echo -e "${GREEN}✓ Secret ${secret_name} created/updated${NC}"
}

# Function to generate random password
generate_password() {
    local length=${1:-16}
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-${length}
}

echo -e "${GREEN}=== Creating Shared Platform Secrets ===${NC}"

# Shared platform secrets
create_secret "${PROJECT_NAME}/shared/database-password" "$(generate_password 24)" "Shared database password for platform"
create_secret "${PROJECT_NAME}/shared/redis-password" "$(generate_password 24)" "Shared Redis password for platform"
create_secret "${PROJECT_NAME}/shared/jwt-secret" "$(generate_password 32)" "JWT secret for authentication"

echo ""
echo -e "${GREEN}=== Creating Tenant 1 Secrets ===${NC}"

# Tenant 1 secrets
create_secret "${PROJECT_NAME}/tenant-1/database-password" "$(generate_password 24)" "Database password for tenant 1"
create_secret "${PROJECT_NAME}/tenant-1/redis-password" "$(generate_password 24)" "Redis password for tenant 1"
create_secret "${PROJECT_NAME}/tenant-1/encryption-key" "$(generate_password 32)" "Encryption key for tenant 1 data"

echo ""
echo -e "${GREEN}=== Creating Tenant 2 Secrets ===${NC}"

# Tenant 2 secrets
create_secret "${PROJECT_NAME}/tenant-2/database-password" "$(generate_password 24)" "Database password for tenant 2"
create_secret "${PROJECT_NAME}/tenant-2/redis-password" "$(generate_password 24)" "Redis password for tenant 2"
create_secret "${PROJECT_NAME}/tenant-2/encryption-key" "$(generate_password 32)" "Encryption key for tenant 2 data"

echo ""
echo -e "${GREEN}=== Creating AI Provider Secrets ===${NC}"

# AI Provider secrets (you'll need to replace these with actual API keys)
create_secret "${PROJECT_NAME}/ai-providers/openai-api-key" "sk-your-openai-api-key-here" "OpenAI API key for AI services"
create_secret "${PROJECT_NAME}/ai-providers/huggingface-api-key" "hf_your-huggingface-token-here" "HuggingFace API key for AI services"
create_secret "${PROJECT_NAME}/ai-providers/custom-model-api-key" "your-custom-model-api-key" "Custom model API key"

echo ""
echo -e "${GREEN}=== Creating Admin Secrets ===${NC}"

# Admin secrets
create_secret "${PROJECT_NAME}/admin/root-password" "$(generate_password 24)" "Root admin password"
create_secret "${PROJECT_NAME}/admin/backup-encryption-key" "$(generate_password 32)" "Backup encryption key"

echo ""
echo -e "${GREEN}=== Creating Monitoring Secrets ===${NC}"

# Monitoring secrets
create_secret "${PROJECT_NAME}/monitoring/grafana-admin-password" "$(generate_password 24)" "Grafana admin password"
create_secret "${PROJECT_NAME}/monitoring/prometheus-auth-token" "$(generate_password 32)" "Prometheus authentication token"

echo ""
echo -e "${GREEN}=== Creating CI/CD Secrets ===${NC}"

# CI/CD secrets
create_secret "${PROJECT_NAME}/cicd/github-token" "ghp_your-github-token-here" "GitHub token for CI/CD"
create_secret "${PROJECT_NAME}/cicd/docker-registry-password" "$(generate_password 24)" "Docker registry password"

echo ""
echo -e "${GREEN}=== Creating External Service Secrets ===${NC}"

# External service secrets
create_secret "${PROJECT_NAME}/external/email-smtp-password" "$(generate_password 24)" "SMTP password for email notifications"
create_secret "${PROJECT_NAME}/external/slack-webhook-url" "https://hooks.slack.com/services/your/slack/webhook" "Slack webhook URL for notifications"

echo ""
echo -e "${GREEN}=== Verifying Secrets ===${NC}"

# List all created secrets
echo -e "${YELLOW}Created secrets:${NC}"
aws secretsmanager list-secrets \
    --region "$AWS_REGION" \
    --query "SecretList[?contains(Name, '${PROJECT_NAME}')].Name" \
    --output table

echo ""
echo -e "${GREEN}=== Creating IAM Policies for Secret Access ===${NC}"

# Create IAM policy for shared platform access
cat > /tmp/shared-platform-secrets-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "secretsmanager:GetSecretValue",
                "secretsmanager:DescribeSecret"
            ],
            "Resource": [
                "arn:aws:secretsmanager:${AWS_REGION}:${ACCOUNT_ID}:secret:${PROJECT_NAME}/shared/*",
                "arn:aws:secretsmanager:${AWS_REGION}:${ACCOUNT_ID}:secret:${PROJECT_NAME}/ai-providers/*"
            ]
        }
    ]
}
EOF

# Create IAM policy for tenant 1 access
cat > /tmp/tenant-1-secrets-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "secretsmanager:GetSecretValue",
                "secretsmanager:DescribeSecret"
            ],
            "Resource": [
                "arn:aws:secretsmanager:${AWS_REGION}:${ACCOUNT_ID}:secret:${PROJECT_NAME}/tenant-1/*",
                "arn:aws:secretsmanager:${AWS_REGION}:${ACCOUNT_ID}:secret:${PROJECT_NAME}/shared/*",
                "arn:aws:secretsmanager:${AWS_REGION}:${ACCOUNT_ID}:secret:${PROJECT_NAME}/ai-providers/*"
            ]
        }
    ]
}
EOF

# Create IAM policy for tenant 2 access
cat > /tmp/tenant-2-secrets-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "secretsmanager:GetSecretValue",
                "secretsmanager:DescribeSecret"
            ],
            "Resource": [
                "arn:aws:secretsmanager:${AWS_REGION}:${ACCOUNT_ID}:secret:${PROJECT_NAME}/tenant-2/*",
                "arn:aws:secretsmanager:${AWS_REGION}:${ACCOUNT_ID}:secret:${PROJECT_NAME}/shared/*",
                "arn:aws:secretsmanager:${AWS_REGION}:${ACCOUNT_ID}:secret:${PROJECT_NAME}/ai-providers/*"
            ]
        }
    ]
}
EOF

# Create IAM policies
aws iam create-policy \
    --policy-name "${PROJECT_NAME}-shared-platform-secrets-policy" \
    --policy-document file:///tmp/shared-platform-secrets-policy.json \
    --description "Policy for shared platform secret access" \
    --region "$AWS_REGION" || echo "Policy already exists"

aws iam create-policy \
    --policy-name "${PROJECT_NAME}-tenant-1-secrets-policy" \
    --policy-document file:///tmp/tenant-1-secrets-policy.json \
    --description "Policy for tenant 1 secret access" \
    --region "$AWS_REGION" || echo "Policy already exists"

aws iam create-policy \
    --policy-name "${PROJECT_NAME}-tenant-2-secrets-policy" \
    --policy-document file:///tmp/tenant-2-secrets-policy.json \
    --description "Policy for tenant 2 secret access" \
    --region "$AWS_REGION" || echo "Policy already exists"

# Clean up temporary files
rm -f /tmp/shared-platform-secrets-policy.json
rm -f /tmp/tenant-1-secrets-policy.json
rm -f /tmp/tenant-2-secrets-policy.json

echo ""
echo -e "${GREEN}=== Secret Creation Complete ===${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Update AI provider API keys with real values"
echo "2. Deploy Terraform infrastructure"
echo "3. Deploy Kubernetes secrets"
echo "4. Test secret access from pods"
echo ""
echo -e "${GREEN}Total secrets created: $(aws secretsmanager list-secrets --region $AWS_REGION --query "SecretList[?contains(Name, '${PROJECT_NAME}')].Name" --output text | wc -w)${NC}"
echo -e "${YELLOW}Estimated monthly cost: $10-20${NC}"

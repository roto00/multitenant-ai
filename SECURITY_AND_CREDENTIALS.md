# Security and Credentials Management

## Overview
This document outlines how credentials and secrets are stored and managed in the multi-tenant AI platform, ensuring security and proper isolation between tenants.

## Credential Storage Locations

### **1. AWS Secrets Manager**
**Primary location for all sensitive credentials**

#### **Shared Platform Secrets:**
```
aws secretsmanager create-secret \
  --name "multitenant-ai-poc/shared/database-password" \
  --description "Shared database password for platform" \
  --secret-string "SecurePassword123!"

aws secretsmanager create-secret \
  --name "multitenant-ai-poc/shared/redis-password" \
  --description "Shared Redis password for platform" \
  --secret-string "RedisSecurePass123!"
```

#### **Tenant-Specific Secrets:**
```
# Tenant 1 Secrets
aws secretsmanager create-secret \
  --name "multitenant-ai-poc/tenant-1/database-password" \
  --description "Database password for tenant 1" \
  --secret-string "Tenant1SecurePass123!"

aws secretsmanager create-secret \
  --name "multitenant-ai-poc/tenant-1/redis-password" \
  --description "Redis password for tenant 1" \
  --secret-string "Tenant1RedisPass123!"

# Tenant 2 Secrets
aws secretsmanager create-secret \
  --name "multitenant-ai-poc/tenant-2/database-password" \
  --description "Database password for tenant 2" \
  --secret-string "Tenant2SecurePass123!"

aws secretsmanager create-secret \
  --name "multitenant-ai-poc/tenant-2/redis-password" \
  --description "Redis password for tenant 2" \
  --secret-string "Tenant2RedisPass123!"
```

#### **AI Provider API Keys:**
```
# OpenAI API Key
aws secretsmanager create-secret \
  --name "multitenant-ai-poc/ai-providers/openai-api-key" \
  --description "OpenAI API key for AI services" \
  --secret-string "sk-your-openai-api-key-here"

# HuggingFace API Key
aws secretsmanager create-secret \
  --name "multitenant-ai-poc/ai-providers/huggingface-api-key" \
  --description "HuggingFace API key for AI services" \
  --secret-string "hf_your-huggingface-token-here"

# Custom Model API Keys
aws secretsmanager create-secret \
  --name "multitenant-ai-poc/ai-providers/custom-model-api-key" \
  --description "Custom model API key" \
  --secret-string "your-custom-model-api-key"
```

### **2. Kubernetes Secrets**
**Runtime secrets for pod access**

#### **Shared Platform Secrets:**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: shared-platform-secrets
  namespace: default
type: Opaque
data:
  database-password: U2VjdXJlUGFzc3dvcmQxMjMh  # base64 encoded
  redis-password: UmVkaXNTZWN1cmVQYXNzMTIzIQ==  # base64 encoded
```

#### **Tenant-Specific Secrets:**
```yaml
# Tenant 1 Secrets
apiVersion: v1
kind: Secret
metadata:
  name: tenant-1-secrets
  namespace: tenant-1
type: Opaque
data:
  database-password: VGVuYW50MVNlY3VyZVBhc3MxMjMh  # base64 encoded
  redis-password: VGVuYW50MVJlZGlzUGFzczEyMyE=  # base64 encoded

---
# Tenant 2 Secrets
apiVersion: v1
kind: Secret
metadata:
  name: tenant-2-secrets
  namespace: tenant-2
type: Opaque
data:
  database-password: VGVuYW50MlNlY3VyZVBhc3MxMjMh  # base64 encoded
  redis-password: VGVuYW50MlJlZGlzUGFzczEyMyE=  # base64 encoded
```

### **3. Environment Variables**
**Non-sensitive configuration**

#### **Backend Configuration:**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: backend-config
  namespace: default
data:
  AWS_REGION: "us-west-2"
  DATABASE_HOST: "multitenant-ai-poc-shared-db.cluster-xyz.us-west-2.rds.amazonaws.com"
  REDIS_HOST: "multitenant-ai-poc-shared-redis.xyz.cache.amazonaws.com"
  LOG_LEVEL: "INFO"
  ENVIRONMENT: "poc"
```

#### **Tenant-Specific Configuration:**
```yaml
# Tenant 1 Config
apiVersion: v1
kind: ConfigMap
metadata:
  name: tenant-1-config
  namespace: tenant-1
data:
  TENANT_ID: "tenant-1"
  DATABASE_HOST: "multitenant-ai-poc-tenant-1-db.cluster-xyz.us-west-2.rds.amazonaws.com"
  REDIS_HOST: "multitenant-ai-poc-tenant-1-redis.xyz.cache.amazonaws.com"
  S3_BUCKET: "multitenant-ai-poc-tenant-1-data-xyz"
  KMS_KEY_ID: "arn:aws:kms:us-west-2:665832050599:key/tenant-1-key-id"
```

### **4. IAM Roles and Policies**
**Service-to-service authentication**

#### **EKS Service Account IAM Roles:**
```yaml
# Shared Platform Role
apiVersion: v1
kind: ServiceAccount
metadata:
  name: shared-platform-sa
  namespace: default
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::665832050599:role/multitenant-ai-poc-shared-platform-role
```

#### **Tenant-Specific Service Accounts:**
```yaml
# Tenant 1 Service Account
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tenant-1-sa
  namespace: tenant-1
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::665832050599:role/multitenant-ai-poc-tenant-1-role

---
# Tenant 2 Service Account
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tenant-2-sa
  namespace: tenant-2
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::665832050599:role/multitenant-ai-poc-tenant-2-role
```

## Security Implementation

### **1. Encryption at Rest**
- **RDS**: Encrypted with tenant-specific KMS keys
- **ElastiCache**: Encrypted with tenant-specific KMS keys
- **S3**: Encrypted with tenant-specific KMS keys
- **EBS**: Encrypted with tenant-specific KMS keys

### **2. Encryption in Transit**
- **TLS 1.2+** for all API communications
- **mTLS** for service-to-service communication
- **VPN/Private endpoints** for database access

### **3. Access Control**
- **IAM roles** for service-to-service authentication
- **Kubernetes RBAC** for pod-level access control
- **Network policies** for pod-to-pod communication
- **Security groups** for network-level access control

### **4. Secret Rotation**
- **Automatic rotation** for database passwords (every 30 days)
- **Manual rotation** for API keys (as needed)
- **Versioned secrets** in AWS Secrets Manager

## Credential Management Workflow

### **1. Initial Setup**
```bash
# Create secrets in AWS Secrets Manager
./scripts/create-secrets.sh

# Deploy Kubernetes secrets
kubectl apply -f kubernetes/secrets/

# Verify secret access
kubectl get secrets -n tenant-1
kubectl get secrets -n tenant-2
```

### **2. Runtime Access**
```python
# Backend service accessing secrets
import boto3
import json

def get_secret(secret_name):
    client = boto3.client('secretsmanager', region_name='us-west-2')
    response = client.get_secret_value(SecretId=secret_name)
    return json.loads(response['SecretString'])

# Get tenant-specific database password
db_password = get_secret('multitenant-ai-poc/tenant-1/database-password')
```

### **3. Secret Rotation**
```bash
# Rotate database password
aws secretsmanager update-secret \
  --secret-id "multitenant-ai-poc/tenant-1/database-password" \
  --secret-string "NewTenant1SecurePass123!"

# Update Kubernetes secret
kubectl create secret generic tenant-1-secrets \
  --from-literal=database-password="NewTenant1SecurePass123!" \
  --namespace=tenant-1 \
  --dry-run=client -o yaml | kubectl apply -f -
```

## Security Best Practices

### **1. Secret Naming Convention**
```
multitenant-ai-poc/{tenant-id}/{secret-type}
multitenant-ai-poc/shared/{secret-type}
multitenant-ai-poc/ai-providers/{provider-name}
```

### **2. Access Patterns**
- **Least privilege** - Only necessary permissions
- **Tenant isolation** - No cross-tenant access
- **Audit logging** - All secret access logged
- **Regular rotation** - Automated password rotation

### **3. Monitoring and Alerting**
- **Secret access monitoring** via CloudTrail
- **Failed access attempts** via CloudWatch
- **Unusual access patterns** via GuardDuty
- **Cost monitoring** for secret storage

## Deployment Security Checklist

### **Pre-Deployment:**
- [ ] Generate strong passwords (16+ characters)
- [ ] Create AWS Secrets Manager secrets
- [ ] Configure IAM roles with least privilege
- [ ] Set up KMS keys for encryption
- [ ] Configure network security groups

### **During Deployment:**
- [ ] Deploy secrets to Kubernetes
- [ ] Verify secret access from pods
- [ ] Test tenant isolation
- [ ] Configure monitoring and alerting

### **Post-Deployment:**
- [ ] Verify all secrets are encrypted
- [ ] Test secret rotation
- [ ] Monitor access patterns
- [ ] Set up cost alerts

## Cost Considerations

### **AWS Secrets Manager Costs:**
- **$0.40 per secret per month**
- **$0.05 per 10,000 API calls**
- **Estimated cost**: $5-10/month for POC

### **KMS Costs:**
- **$1 per key per month**
- **$0.03 per 10,000 requests**
- **Estimated cost**: $5-10/month for POC

### **Total Security Costs:**
- **Secrets Manager**: $5-10/month
- **KMS**: $5-10/month
- **Total**: $10-20/month

## Troubleshooting

### **Common Issues:**

#### **1. Secret Access Denied**
```bash
# Check IAM role permissions
aws iam get-role-policy --role-name multitenant-ai-poc-tenant-1-role --policy-name SecretsManagerAccess

# Verify service account annotation
kubectl describe serviceaccount tenant-1-sa -n tenant-1
```

#### **2. Secret Not Found**
```bash
# List all secrets
aws secretsmanager list-secrets --query 'SecretList[?contains(Name, `multitenant-ai-poc`)]'

# Check secret exists
aws secretsmanager describe-secret --secret-id "multitenant-ai-poc/tenant-1/database-password"
```

#### **3. Kubernetes Secret Issues**
```bash
# Check secret exists
kubectl get secrets -n tenant-1

# Verify secret content
kubectl get secret tenant-1-secrets -n tenant-1 -o yaml
```

## Conclusion

The multi-tenant AI platform uses a **layered security approach**:

1. **AWS Secrets Manager** - Primary secret storage
2. **Kubernetes Secrets** - Runtime secret access
3. **IAM Roles** - Service-to-service authentication
4. **KMS Encryption** - Data encryption at rest
5. **Network Security** - Communication encryption

This approach ensures:
- **Complete tenant isolation** - No cross-tenant access
- **Secure secret management** - Encrypted and rotated
- **Audit compliance** - All access logged
- **Cost optimization** - Minimal security overhead

The total security cost for the POC is approximately **$10-20/month**, which is a small price to pay for enterprise-grade security and compliance.

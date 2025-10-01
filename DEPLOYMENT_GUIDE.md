# Multi-tenant AI Platform - Deployment & Troubleshooting Guide

## 🚀 Deployment Overview

This guide covers deploying, managing, and troubleshooting the Multi-tenant AI Platform on AWS. The platform uses a modern cloud-native architecture with ECS Fargate, RDS, ElastiCache, and Application Load Balancer.

## 📋 Prerequisites

### Required Tools
- **AWS CLI** (v2.0+) configured with appropriate permissions
- **Terraform** (v1.0+)
- **Docker** (for local development)
- **Git** (for version control)
- **Python 3.11+** (for local development)

### AWS Permissions
Your AWS user/role needs permissions for:
- ECS (clusters, services, task definitions)
- RDS (databases, subnet groups)
- ElastiCache (replication groups, subnet groups)
- EC2 (VPC, subnets, security groups, load balancers)
- ECR (repositories, images)
- CodeBuild (projects, builds)
- Route53 (hosted zones, records)
- IAM (roles, policies)
- CloudWatch (logs, metrics)

## 🏗️ Infrastructure Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        AWS Cloud                            │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │   Route53   │  │     ALB     │  │   CodeBuild │         │
│  │   (DNS)     │  │  (Load      │  │   (CI/CD)   │         │
│  │             │  │  Balancer)  │  │             │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
│           │              │              │                  │
│           └──────────────┼──────────────┘                  │
│                          │                                 │
│  ┌───────────────────────▼───────────────────────┐         │
│  │              ECS Fargate Cluster              │         │
│  │  ┌─────────────────────────────────────────┐  │         │
│  │  │         FastAPI Application             │  │         │
│  │  │  • Multi-tenant AI Platform            │  │         │
│  │  │  • Chat API                            │  │         │
│  │  │  • RAG Capabilities                    │  │         │
│  │  │  • Admin Interface                     │  │         │
│  │  └─────────────────────────────────────────┘  │         │
│  └───────────────────────┬───────────────────────┘         │
│                          │                                 │
│  ┌───────────────────────┼───────────────────────┐         │
│  │  ┌─────────────┐      │      ┌─────────────┐  │         │
│  │  │ PostgreSQL  │      │      │   Redis     │  │         │
│  │  │    (RDS)    │      │      │(ElastiCache)│  │         │
│  │  │             │      │      │             │  │         │
│  │  └─────────────┘      │      └─────────────┘  │         │
│  └───────────────────────┼───────────────────────┘         │
│                          │                                 │
│  ┌───────────────────────▼───────────────────────┐         │
│  │              S3 Bucket                        │         │
│  │  • Shared Storage                            │         │
│  │  • Document Storage                          │         │
│  │  • Backup Storage                            │         │
│  └───────────────────────────────────────────────┘         │
└─────────────────────────────────────────────────────────────┘
```

## 🚀 Initial Deployment

### Step 1: Clone and Setup

```bash
# Clone the repository
git clone https://github.com/roto00/multitenant-ai.git
cd multitenant-ai

# Verify AWS CLI configuration
aws sts get-caller-identity

# Verify Terraform installation
terraform version
```

### Step 2: Configure Environment

```bash
# Copy and edit Terraform variables
cp terraform/terraform.tfvars.example terraform/terraform.tfvars

# Edit terraform.tfvars with your configuration
nano terraform/terraform.tfvars
```

**Example terraform.tfvars:**
```hcl
project_name = "multitenant-ai-minimal"
aws_region = "us-west-2"
database_password = "SecurePassword123!"
domain_name = ""  # Optional: your custom domain
```

### Step 3: Deploy Infrastructure

```bash
cd terraform

# Initialize Terraform
terraform init

# Plan the deployment
terraform plan

# Apply the infrastructure
terraform apply
```

### Step 4: Build and Deploy Application

```bash
# Build and push Docker images
cd ..
./scripts/build-and-deploy.sh
```

### Step 5: Verify Deployment

```bash
# Check application health
curl http://$(terraform output -raw alb_dns_name)/ping

# Should return: "pong"
```

## 🔄 CI/CD Pipeline

### GitHub Actions Workflow

The platform includes a GitHub Actions workflow for automated deployment:

```yaml
# .github/workflows/deploy.yml
name: Deploy Multi-tenant AI Platform

on:
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      - name: Install dependencies
        run: |
          cd backend
          pip install -r requirements.txt
      - name: Run tests
        run: |
          cd backend
          python -m pytest tests/ -v

  deploy:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-west-2
      - name: Deploy to AWS
        run: ./scripts/deploy.sh
```

### CodeBuild Integration

The platform also supports AWS CodeBuild for deployment:

```bash
# Trigger CodeBuild deployment
aws codebuild start-build \
  --project-name multitenant-ai-minimal-backend-build \
  --region us-west-2
```

## 🛠️ Management Commands

### Application Management

```bash
# Check ECS service status
aws ecs describe-services \
  --cluster multitenant-ai-minimal-cluster \
  --services multitenant-ai-minimal-service \
  --region us-west-2

# Scale the service
aws ecs update-service \
  --cluster multitenant-ai-minimal-cluster \
  --service multitenant-ai-minimal-service \
  --desired-count 2 \
  --region us-west-2

# Force new deployment
aws ecs update-service \
  --cluster multitenant-ai-minimal-cluster \
  --service multitenant-ai-minimal-service \
  --force-new-deployment \
  --region us-west-2
```

### Database Management

```bash
# Get database endpoint
terraform output database_endpoint

# Connect to database (requires psql)
psql -h $(terraform output -raw database_endpoint) \
     -U postgres \
     -d multitenant_ai

# Create database backup
aws rds create-db-snapshot \
  --db-instance-identifier multitenant-ai-minimal-db \
  --db-snapshot-identifier multitenant-ai-backup-$(date +%Y%m%d) \
  --region us-west-2
```

### Cache Management

```bash
# Get Redis endpoint
terraform output redis_endpoint

# Connect to Redis (requires redis-cli)
redis-cli -h $(terraform output -raw redis_endpoint) -p 6379

# Clear cache
redis-cli -h $(terraform output -raw redis_endpoint) -p 6379 FLUSHALL
```

## 🔍 Monitoring & Logging

### CloudWatch Logs

```bash
# View application logs
aws logs get-log-events \
  --log-group-name /ecs/multitenant-ai-minimal \
  --log-stream-name ecs/backend/$(aws ecs list-tasks --cluster multitenant-ai-minimal-cluster --service-name multitenant-ai-minimal-service --query 'taskArns[0]' --output text | cut -d'/' -f3) \
  --region us-west-2

# View CodeBuild logs
aws logs get-log-events \
  --log-group-name /aws/codebuild/multitenant-ai-minimal-backend-build \
  --log-stream-name $(aws codebuild list-builds-for-project --project-name multitenant-ai-minimal-backend-build --query 'ids[0]' --output text) \
  --region us-west-2
```

### Health Monitoring

```bash
# Check ALB target health
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arn) \
  --region us-west-2

# Check application health
curl -s http://$(terraform output -raw alb_dns_name)/health | jq .

# Check database connectivity
aws rds describe-db-instances \
  --db-instance-identifier multitenant-ai-minimal-db \
  --region us-west-2 \
  --query 'DBInstances[0].DBInstanceStatus'
```

## 🚨 Troubleshooting Guide

### Common Issues and Solutions

#### 1. Application Not Responding (504/503 Errors)

**Symptoms:**
- ALB returns 504 Gateway Timeout or 503 Service Unavailable
- Health checks failing

**Diagnosis:**
```bash
# Check target health
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arn) \
  --region us-west-2

# Check ECS service status
aws ecs describe-services \
  --cluster multitenant-ai-minimal-cluster \
  --services multitenant-ai-minimal-service \
  --region us-west-2
```

**Solutions:**
1. **Security Group Issues**: Ensure port 8000 is open
   ```bash
   aws ec2 authorize-security-group-ingress \
     --group-id $(terraform output -raw security_group_id) \
     --protocol tcp \
     --port 8000 \
     --cidr 0.0.0.0/0 \
     --region us-west-2
   ```

2. **Task Definition Issues**: Check container configuration
   ```bash
   aws ecs describe-task-definition \
     --task-definition multitenant-ai-minimal-task \
     --region us-west-2
   ```

3. **Application Startup Issues**: Check logs
   ```bash
   aws logs get-log-events \
     --log-group-name /ecs/multitenant-ai-minimal \
     --log-stream-name ecs/backend/$(aws ecs list-tasks --cluster multitenant-ai-minimal-cluster --query 'taskArns[0]' --output text | cut -d'/' -f3) \
     --region us-west-2
   ```

#### 2. Database Connection Issues

**Symptoms:**
- Application fails to start
- Database connection timeouts

**Diagnosis:**
```bash
# Check RDS status
aws rds describe-db-instances \
  --db-instance-identifier multitenant-ai-minimal-db \
  --region us-west-2

# Test database connectivity
psql -h $(terraform output -raw database_endpoint) \
     -U postgres \
     -d multitenant_ai \
     -c "SELECT 1;"
```

**Solutions:**
1. **Security Group**: Ensure database security group allows connections from ECS
2. **Subnet Group**: Verify database subnet group includes private subnets
3. **Credentials**: Check database password in environment variables

#### 3. Redis Connection Issues

**Symptoms:**
- Application fails to start
- Redis connection timeouts

**Diagnosis:**
```bash
# Check ElastiCache status
aws elasticache describe-replication-groups \
  --replication-group-id multitenant-ai-minimal-redis \
  --region us-west-2

# Test Redis connectivity
redis-cli -h $(terraform output -raw redis_endpoint) -p 6379 ping
```

**Solutions:**
1. **Security Group**: Ensure Redis security group allows connections from ECS
2. **SSL Configuration**: Check Redis URL format (rediss:// for SSL)
3. **Subnet Group**: Verify cache subnet group configuration

#### 4. Memory Issues (Exit Code 137)

**Symptoms:**
- Tasks stop with exit code 137
- Application crashes during startup

**Solutions:**
1. **Increase Memory**: Update task definition memory allocation
   ```bash
   # Edit terraform/main.tf
   memory = 4096  # Increase from 2048
   
   # Apply changes
   terraform apply
   ```

2. **Optimize Application**: Reduce memory usage in application code

#### 5. Build Failures

**Symptoms:**
- CodeBuild fails
- Docker build errors

**Diagnosis:**
```bash
# Check CodeBuild logs
aws logs get-log-events \
  --log-group-name /aws/codebuild/multitenant-ai-minimal-backend-build \
  --log-stream-name $(aws codebuild list-builds-for-project --project-name multitenant-ai-minimal-backend-build --query 'ids[0]' --output text) \
  --region us-west-2
```

**Solutions:**
1. **Dependencies**: Check requirements.txt for version conflicts
2. **Dockerfile**: Verify Docker build configuration
3. **ECR Permissions**: Ensure CodeBuild has ECR push permissions

### Debug Commands

```bash
# Get all resource information
terraform output

# Check all ECS tasks
aws ecs list-tasks --cluster multitenant-ai-minimal-cluster --region us-west-2

# Get task details
aws ecs describe-tasks \
  --cluster multitenant-ai-minimal-cluster \
  --tasks $(aws ecs list-tasks --cluster multitenant-ai-minimal-cluster --query 'taskArns[0]' --output text) \
  --region us-west-2

# Check security groups
aws ec2 describe-security-groups \
  --group-ids $(terraform output -raw security_group_id) \
  --region us-west-2

# Check load balancer
aws elbv2 describe-load-balancers \
  --names $(terraform output -raw alb_name) \
  --region us-west-2
```

## 🔧 Maintenance Tasks

### Regular Maintenance

#### Weekly Tasks
- [ ] Check application logs for errors
- [ ] Monitor resource usage and costs
- [ ] Review security group rules
- [ ] Verify backup schedules

#### Monthly Tasks
- [ ] Update dependencies and security patches
- [ ] Review and rotate API keys
- [ ] Analyze usage patterns and optimize
- [ ] Test disaster recovery procedures

#### Quarterly Tasks
- [ ] Review and update infrastructure
- [ ] Performance testing and optimization
- [ ] Security audit and penetration testing
- [ ] Update documentation

### Backup and Recovery

#### Database Backups
```bash
# Create manual backup
aws rds create-db-snapshot \
  --db-instance-identifier multitenant-ai-minimal-db \
  --db-snapshot-identifier multitenant-ai-manual-$(date +%Y%m%d-%H%M%S) \
  --region us-west-2

# Restore from backup
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier multitenant-ai-restored \
  --db-snapshot-identifier multitenant-ai-manual-20251001-120000 \
  --region us-west-2
```

#### Application Data Backups
```bash
# Backup S3 bucket
aws s3 sync s3://$(terraform output -raw s3_bucket_name) s3://backup-bucket/$(date +%Y%m%d)/

# Export Redis data
redis-cli -h $(terraform output -raw redis_endpoint) -p 6379 BGSAVE
```

### Scaling Operations

#### Horizontal Scaling
```bash
# Scale ECS service
aws ecs update-service \
  --cluster multitenant-ai-minimal-cluster \
  --service multitenant-ai-minimal-service \
  --desired-count 3 \
  --region us-west-2
```

#### Vertical Scaling
```bash
# Update task definition with more resources
# Edit terraform/main.tf
cpu = 2048      # Increase from 1024
memory = 4096   # Increase from 2048

# Apply changes
terraform apply
```

## 🔒 Security Hardening

### Network Security
- Use private subnets for databases
- Implement least-privilege security groups
- Enable VPC Flow Logs
- Use AWS WAF for additional protection

### Application Security
- Regular security updates
- Input validation and sanitization
- Rate limiting and DDoS protection
- Secure environment variable handling

### Data Security
- Encryption at rest and in transit
- Regular security audits
- Access logging and monitoring
- Backup encryption

## 📊 Cost Optimization

### Resource Optimization
- Use appropriate instance sizes
- Implement auto-scaling
- Monitor and optimize database queries
- Use spot instances for non-critical workloads

### Cost Monitoring
```bash
# Get cost information
aws ce get-cost-and-usage \
  --time-period Start=2025-10-01,End=2025-10-31 \
  --granularity MONTHLY \
  --metrics BlendedCost
```

## 🆘 Emergency Procedures

### Service Outage Response
1. **Immediate Response**
   - Check ALB health
   - Verify ECS service status
   - Review application logs
   - Check database connectivity

2. **Escalation**
   - Contact AWS support if needed
   - Notify stakeholders
   - Document incident details

3. **Recovery**
   - Implement fixes
   - Test thoroughly
   - Monitor for stability
   - Post-incident review

### Disaster Recovery
1. **Backup Verification**
   - Test database restore procedures
   - Verify application deployment process
   - Check infrastructure provisioning

2. **Recovery Testing**
   - Regular disaster recovery drills
   - Document recovery procedures
   - Train team members

## 📞 Support Contacts

### Internal Support
- **System Administrator**: [Your contact info]
- **Development Team**: [Team contact info]
- **On-call Engineer**: [Emergency contact]

### AWS Support
- **AWS Support Center**: https://console.aws.amazon.com/support/
- **AWS Documentation**: https://docs.aws.amazon.com/
- **AWS Status Page**: https://status.aws.amazon.com/

### External Resources
- **FastAPI Documentation**: https://fastapi.tiangolo.com/
- **Terraform Documentation**: https://www.terraform.io/docs/
- **Docker Documentation**: https://docs.docker.com/

---

## 📋 Quick Reference

### Essential Commands
```bash
# Check application status
curl http://$(terraform output -raw alb_dns_name)/ping

# View logs
aws logs get-log-events --log-group-name /ecs/multitenant-ai-minimal --log-stream-name $(aws ecs list-tasks --cluster multitenant-ai-minimal-cluster --query 'taskArns[0]' --output text | cut -d'/' -f3)

# Scale service
aws ecs update-service --cluster multitenant-ai-minimal-cluster --service multitenant-ai-minimal-service --desired-count 2

# Force deployment
aws ecs update-service --cluster multitenant-ai-minimal-cluster --service multitenant-ai-minimal-service --force-new-deployment
```

### Key URLs
- **Application**: `http://mtai-poc-alb-1783388022.us-west-2.elb.amazonaws.com`
- **API Docs**: `http://mtai-poc-alb-1783388022.us-west-2.elb.amazonaws.com/docs`
- **Health Check**: `http://mtai-poc-alb-1783388022.us-west-2.elb.amazonaws.com/ping`

### Important Resources
- **Terraform State**: `terraform/terraform.tfstate`
- **Logs**: CloudWatch `/ecs/multitenant-ai-minimal`
- **Database**: RDS `multitenant-ai-minimal-db`
- **Cache**: ElastiCache `multitenant-ai-minimal-redis`

---

**Last Updated**: October 1, 2025  
**Platform Version**: 1.0.0  
**Infrastructure Version**: Terraform 1.0+

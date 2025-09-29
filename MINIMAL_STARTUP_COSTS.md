# Minimal Startup Costs - 2 Trial Tenants

## Overview
This document outlines the **absolute minimum** AWS infrastructure costs for getting started with 2 trial tenants while maintaining core functionality.

## Architecture Summary

### **Minimal Components:**
- **1x EC2 t4g.small** (ARM64 Graviton) - Auto-scaling 1-2 instances
- **1x RDS db.t4g.micro** (PostgreSQL) - Single AZ
- **1x ElastiCache cache.t4g.micro** (Redis) - Single node
- **1x Application Load Balancer** - Basic tier
- **1x VPC** - Single AZ, no NAT Gateway
- **CloudWatch Logs** - 3-day retention

### **What's Excluded for Cost Savings:**
- ❌ **NAT Gateway** (~$45/month) - Using public subnets
- ❌ **Multi-AZ deployment** - Single AZ only
- ❌ **GPU instances** - CPU-only for now
- ❌ **CDN/CloudFront** - Direct ALB access
- ❌ **Advanced monitoring** - Basic CloudWatch only
- ❌ **Backup retention** - Minimal backups

## Detailed Cost Breakdown

### **Monthly Costs (USD)**

| Component | Instance Type | Quantity | Monthly Cost | Notes |
|-----------|---------------|----------|--------------|-------|
| **EC2 Instances** | t4g.small | 1-2 | $15-30 | ARM64 Graviton, auto-scaling |
| **RDS Database** | db.t4g.micro | 1 | $12-15 | Single AZ, 20GB storage |
| **ElastiCache Redis** | cache.t4g.micro | 1 | $8-12 | Single node, minimal memory |
| **Application Load Balancer** | ALB | 1 | $16-20 | Basic tier |
| **Data Transfer** | - | - | $5-10 | Minimal traffic |
| **CloudWatch Logs** | - | - | $2-5 | 3-day retention |
| **Storage (EBS)** | gp3 | 20GB | $2-3 | For EC2 instances |
| **ECR Repository** | - | 1 | $1-2 | Container images |
| **Route 53** | - | 1 | $0.50 | DNS (if using custom domain) |
| **Total** | | | **$61-97** | **Per month** |

### **Cost per Tenant:**
- **Trial Tenant 1**: ~$30-48/month
- **Trial Tenant 2**: ~$30-48/month
- **Infrastructure Overhead**: ~$1-1/month

## Scaling Considerations

### **When to Scale Up:**

#### **At 10+ Users per Tenant:**
- **Cost**: $80-120/month
- **Changes**: Add 1 more EC2 instance, upgrade RDS to t4g.small

#### **At 50+ Users per Tenant:**
- **Cost**: $150-250/month
- **Changes**: Multi-AZ RDS, ElastiCache cluster, add monitoring

#### **At 100+ Users per Tenant:**
- **Cost**: $300-500/month
- **Changes**: EKS cluster, dedicated resources, advanced monitoring

## Cost Optimization Tips

### **Immediate Savings:**
1. **Use Spot Instances**: 60-70% savings on EC2 (with risk)
2. **Reserved Instances**: 30-40% savings for 1-year commitment
3. **S3 Intelligent Tiering**: Automatic cost optimization
4. **CloudWatch Logs**: Reduce retention to 1 day

### **Advanced Optimizations:**
1. **Lambda + API Gateway**: $20-40/month for very low traffic
2. **Serverless Aurora**: Pay-per-request database
3. **ElastiCache Serverless**: Pay-per-request caching

## Alternative Minimal Architectures

### **Option 1: Serverless (Ultra-Minimal)**
```
Lambda + API Gateway + Aurora Serverless + ElastiCache Serverless
```
- **Cost**: $20-40/month
- **Limitations**: Cold starts, 15-minute timeout
- **Best for**: Very low traffic, proof-of-concept

### **Option 2: Container on Fargate**
```
Fargate + RDS + ElastiCache
```
- **Cost**: $80-120/month
- **Benefits**: No server management, auto-scaling
- **Limitations**: Higher per-vCPU cost

### **Option 3: Current Minimal (Recommended)**
```
EC2 + RDS + ElastiCache + ALB
```
- **Cost**: $61-97/month
- **Benefits**: Full control, easy to scale, cost-effective
- **Best for**: Getting started with room to grow

## Implementation Steps

### **Phase 1: Deploy Minimal Infrastructure**
```bash
# 1. Clone the repository
git clone <your-repo>
cd multitenant-ai

# 2. Configure Terraform
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your settings

# 3. Deploy minimal infrastructure
terraform init
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"
```

### **Phase 2: Deploy Application**
```bash
# 1. Build and push Docker images
cd backend
docker build -t <ecr-repo-url>:latest .
docker push <ecr-repo-url>:latest

# 2. Update ECS service or EC2 instances
# (Automatic if using the provided user data script)
```

### **Phase 3: Configure Tenants**
```bash
# 1. Create first tenant
curl -X POST http://<alb-dns>/api/v1/tenants \
  -H "Content-Type: application/json" \
  -d '{"name": "tenant1", "domain": "tenant1.example.com", "display_name": "Trial Tenant 1"}'

# 2. Create second tenant
curl -X POST http://<alb-dns>/api/v1/tenants \
  -H "Content-Type: application/json" \
  -d '{"name": "tenant2", "domain": "tenant2.example.com", "display_name": "Trial Tenant 2"}'
```

## Monitoring & Alerts

### **Essential Monitoring:**
- **CPU Utilization**: Alert at 80%
- **Memory Usage**: Alert at 85%
- **Database Connections**: Alert at 80% of max
- **Response Time**: Alert at 5 seconds
- **Error Rate**: Alert at 5%

### **Cost Monitoring:**
- **Daily Cost Alerts**: Set at $5/day
- **Monthly Budget**: Set at $100/month
- **Cost Anomaly Detection**: Enable in AWS Cost Explorer

## Security Considerations

### **Minimal Security Setup:**
- **VPC**: Isolated network
- **Security Groups**: Restrictive access
- **IAM Roles**: Least privilege
- **Encryption**: At rest and in transit
- **SSL/TLS**: HTTPS only

### **Production Readiness:**
- **WAF**: Web Application Firewall
- **Secrets Manager**: For sensitive data
- **Backup Strategy**: Automated backups
- **Monitoring**: Comprehensive logging

## Growth Path

### **Month 1-2: Trial Phase**
- **Cost**: $61-97/month
- **Users**: 2-20 total
- **Focus**: Product validation, user feedback

### **Month 3-6: Early Growth**
- **Cost**: $150-300/month
- **Users**: 20-100 total
- **Focus**: Feature development, performance optimization

### **Month 6-12: Scale Phase**
- **Cost**: $500-1000/month
- **Users**: 100-500 total
- **Focus**: Multi-tenant optimization, enterprise features

### **Year 2+: Enterprise Scale**
- **Cost**: $2000-5000/month
- **Users**: 500+ total
- **Focus**: Global distribution, advanced features

## Conclusion

### **Recommended Starting Point:**
- **Architecture**: EC2 + RDS + ElastiCache + ALB
- **Cost**: $61-97/month
- **Capacity**: 2 trial tenants, 10-20 users total
- **Growth**: Easy to scale as needed

### **Key Benefits:**
✅ **Low cost**: Under $100/month to start
✅ **Scalable**: Easy to add resources
✅ **Full-featured**: All core AI capabilities
✅ **Production-ready**: Secure and reliable
✅ **ARM64 optimized**: 20-40% cost savings

### **Next Steps:**
1. **Deploy minimal infrastructure**
2. **Set up 2 trial tenants**
3. **Monitor costs and performance**
4. **Scale up as user base grows**
5. **Optimize costs continuously**

This minimal setup gives you a solid foundation to validate your multi-tenant AI platform while keeping costs under $100/month. As you grow, you can easily scale up to the enterprise architecture when needed.

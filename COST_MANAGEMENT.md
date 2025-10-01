# 💰 Cost Management Guide

## Current AWS Resources & Costs

### Running Costs (Per Hour)
| Service | Instance Type | Cost/Hour | Status |
|---------|---------------|-----------|---------|
| **ECS Fargate** | 1 vCPU, 2GB RAM | ~$0.04 | ✅ Scaled to 0 |
| **RDS PostgreSQL** | db.t3.micro | ~$0.017 | 🛑 Stopped |
| **ElastiCache Redis** | cache.t3.micro | ~$0.017 | 🗑️ Deleted |
| **ALB** | Standard | ~$0.0225 | ✅ Running |
| **ECR** | Storage only | ~$0.001 | ✅ Running |
| **S3** | Storage only | ~$0.0001 | ✅ Running |

### Total Cost Savings
- **When Running**: ~$0.10/hour (~$2.40/day)
- **When Shut Down**: ~$0.025/hour (~$0.60/day)
- **Daily Savings**: ~$1.80/day
- **Monthly Savings**: ~$54/month

## 🛠️ Service Management

### Quick Commands

```bash
# Check current status
./scripts/manage-services.sh status

# Shutdown everything (save costs)
./scripts/manage-services.sh shutdown

# Start everything back up
./scripts/manage-services.sh start
```

### Manual Commands

#### Shutdown Services
```bash
# Scale down ECS
aws ecs update-service --cluster multitenant-ai-minimal-cluster --service multitenant-ai-minimal-service --desired-count 0 --region us-west-2

# Stop RDS
aws rds stop-db-instance --db-instance-identifier multitenant-ai-minimal-db --region us-west-2

# Delete ElastiCache
aws elasticache delete-replication-group --replication-group-id multitenant-ai-minimal-redis --region us-west-2
```

#### Startup Services
```bash
# Start RDS
aws rds start-db-instance --db-instance-identifier multitenant-ai-minimal-db --region us-west-2

# Recreate ElastiCache
cd terraform && terraform apply -target=aws_elasticache_replication_group.main -auto-approve

# Scale up ECS
aws ecs update-service --cluster multitenant-ai-minimal-cluster --service multitenant-ai-minimal-service --desired-count 1 --region us-west-2
```

## 📊 Cost Monitoring

### AWS Cost Explorer
1. Go to AWS Cost Explorer
2. Filter by service: ECS, RDS, ElastiCache
3. Set time range to monitor daily costs

### Cost Alerts
Set up billing alerts in AWS:
- **Daily**: $5 threshold
- **Monthly**: $50 threshold

### Resource Tagging
All resources are tagged with:
- `Name`: Resource identifier
- `Project`: multitenant-ai-minimal
- `Environment`: production

## 🎯 Optimization Tips

### Right-Sizing
- **ECS**: Currently 1 vCPU, 2GB RAM (good for development)
- **RDS**: db.t3.micro (smallest available)
- **ElastiCache**: cache.t3.micro (smallest available)

### Scheduled Shutdown
Consider using AWS Lambda + EventBridge to automatically:
- Shutdown services at night (e.g., 10 PM)
- Startup services in morning (e.g., 8 AM)

### Reserved Instances
For production use, consider:
- RDS Reserved Instances (up to 75% savings)
- ElastiCache Reserved Nodes (up to 50% savings)

## 🚨 Cost Alerts

### High Usage Scenarios
- **ECS Auto-scaling**: Monitor for unexpected scaling
- **Database Connections**: Watch for connection leaks
- **API Usage**: Monitor token consumption costs

### Emergency Shutdown
If costs spike unexpectedly:
```bash
# Emergency shutdown
./scripts/manage-services.sh shutdown

# Check what's running
aws ecs list-tasks --cluster multitenant-ai-minimal-cluster --region us-west-2
```

## 📈 Scaling Costs

### Horizontal Scaling (More Instances)
- **ECS**: Linear cost increase
- **RDS**: Read replicas cost extra
- **ElastiCache**: Cluster mode costs more

### Vertical Scaling (Larger Instances)
| Instance Type | vCPU | RAM | Cost/Hour | Use Case |
|---------------|------|-----|-----------|----------|
| db.t3.micro | 2 | 1GB | $0.017 | Development |
| db.t3.small | 2 | 2GB | $0.034 | Small production |
| db.t3.medium | 2 | 4GB | $0.068 | Medium production |

## 🔄 Backup Costs

### RDS Snapshots
- **Automated**: 7 days retention (included)
- **Manual**: $0.095/GB/month
- **Cross-region**: Additional transfer costs

### S3 Storage
- **Standard**: $0.023/GB/month
- **IA**: $0.0125/GB/month (for backups)

## 💡 Best Practices

### Development
- ✅ Shutdown services when not in use
- ✅ Use smallest instance sizes
- ✅ Monitor costs daily
- ✅ Set up billing alerts

### Production
- ✅ Use Reserved Instances
- ✅ Implement auto-scaling
- ✅ Monitor resource utilization
- ✅ Regular cost reviews

### Cost Optimization
- ✅ Delete unused resources
- ✅ Use spot instances for non-critical workloads
- ✅ Implement caching strategies
- ✅ Optimize database queries

## 📞 Cost Support

### AWS Support
- **Basic**: No cost support
- **Developer**: $29/month + usage
- **Business**: $100/month + usage

### Cost Management Tools
- **AWS Cost Explorer**: Free
- **AWS Budgets**: Free
- **AWS Cost Anomaly Detection**: Free
- **Third-party tools**: CloudHealth, Cloudyn

---

## 🎯 Quick Reference

| Action | Command | Cost Impact |
|--------|---------|-------------|
| **Check Status** | `./scripts/manage-services.sh status` | None |
| **Shutdown All** | `./scripts/manage-services.sh shutdown` | Save ~$0.075/hour |
| **Start All** | `./scripts/manage-services.sh start` | Cost ~$0.075/hour |
| **Emergency Stop** | `aws ecs update-service --desired-count 0` | Immediate savings |

**Remember**: ALB, ECR, and S3 continue running even when shut down (minimal costs).

---

*Last Updated: October 1, 2025*
*Estimated costs based on us-west-2 pricing*

# POC Configuration for Multi-Tenant AI Platform
# Account: 665832050599
# User: RobThomas

# AWS Configuration
aws_region = "us-west-2"  # Oregon - good for cost optimization
project_name = "multitenant-ai-poc"

# Database Configuration
database_password = "SecurePassword123!"  # Change this to a secure password
tenant_passwords = [
  "Tenant1SecurePass123!",
  "Tenant2SecurePass123!"
]
tenant_redis_passwords = [
  "Tenant1RedisPass123!",
  "Tenant2RedisPass123!"
]

# EKS Configuration
eks_version = "1.28"
node_instance_types = ["t4g.small", "t4g.micro"]
gpu_instance_types = ["g5.xlarge", "g5.2xlarge"]

# RDS Configuration
rds_instance_class = "db.t4g.micro"  # Smallest Graviton3 instance for POC
rds_allocated_storage = 20
rds_max_allocated_storage = 100

# ElastiCache Configuration
redis_node_type = "cache.t4g.micro"  # Smallest Graviton3 Redis for POC
redis_num_cache_nodes = 1

# ECS Configuration (if using ECS instead of EKS)
ecs_cpu = 512
ecs_memory = 1024
ecs_desired_count = 0  # Start with 0 for auto-scaling

# Auto-scaling Configuration
min_nodes = 0
max_nodes = 5
desired_nodes = 0  # Start with 0 for cost optimization

# Environment
environment = "poc"
data_isolation = "strict"
cost_optimization = true

# Monitoring
enable_monitoring = true
log_retention_days = 3  # Minimal for POC
enable_cost_alerts = true
monthly_budget_limit = 400  # $400/month budget alert

# Security
enable_encryption = true
enable_waf = false  # Disable for POC to save costs
enable_cloudtrail = true

# Multi-provider AI Configuration
enable_bedrock = true
enable_openai = true
enable_huggingface = true
enable_custom_models = true

# Custom model training
enable_gpu_training = true
gpu_training_instances = ["g5.xlarge"]
max_gpu_instances = 2

# Tags
tags = {
  Project = "MultiTenantAI"
  Environment = "POC"
  Owner = "RobThomas"
  CostCenter = "AI-Platform-POC"
  DataIsolation = "Strict"
  AutoScaling = "Enabled"
}

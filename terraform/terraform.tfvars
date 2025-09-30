# Minimal POC Configuration for Multi-Tenant AI Platform
# Account: 665832050599
# User: RobThomas

# AWS Configuration
aws_region = "us-west-2"  # Oregon - good for cost optimization
project_name = "multitenant-ai-minimal"

# Database Configuration
database_password = "SecurePassword123!"  # Change this to a secure password

# RDS Configuration
rds_instance_class = "db.t4g.micro"  # Smallest Graviton3 instance for POC

# ElastiCache Configuration
redis_node_type = "cache.t4g.micro"  # Smallest Graviton3 Redis for POC

# ECS Configuration
ecs_cpu = 512
ecs_memory = 1024
ecs_desired_count = 1  # Start with 1 for minimal POC

# Environment
environment = "minimal-poc"

# Tags
tags = {
  Project = "MultiTenantAI"
  Environment = "Minimal-POC"
  Owner = "RobThomas"
  CostCenter = "AI-Platform-Minimal"
}
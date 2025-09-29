variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "multitenant-ai"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "database_name" {
  description = "Name of the database"
  type        = string
  default     = "multitenant_ai"
}

variable "database_username" {
  description = "Database username"
  type        = string
  default     = "postgres"
}

variable "database_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "ecs_cpu" {
  description = "CPU units for ECS task"
  type        = number
  default     = 512
}

variable "ecs_memory" {
  description = "Memory for ECS task"
  type        = number
  default     = 1024
}

variable "ecs_desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 2
}

variable "redis_node_type" {
  description = "Redis node type"
  type        = string
  default     = "cache.t3.micro"
}

variable "tenant_passwords" {
  description = "Database passwords for each tenant"
  type        = list(string)
  default     = ["Tenant1SecurePass123!", "Tenant2SecurePass123!"]
}

variable "tenant_redis_passwords" {
  description = "Redis passwords for each tenant"
  type        = list(string)
  default     = ["Tenant1RedisPass123!", "Tenant2RedisPass123!"]
}

variable "min_nodes" {
  description = "Minimum number of nodes"
  type        = number
  default     = 0
}

variable "max_nodes" {
  description = "Maximum number of nodes"
  type        = number
  default     = 5
}

variable "desired_nodes" {
  description = "Desired number of nodes"
  type        = number
  default     = 0
}

variable "max_gpu_instances" {
  description = "Maximum number of GPU instances"
  type        = number
  default     = 2
}

variable "monthly_budget_limit" {
  description = "Monthly budget limit for cost alerts"
  type        = number
  default     = 400
}

variable "redis_num_cache_nodes" {
  description = "Number of cache nodes for Redis"
  type        = number
  default     = 1
}

variable "node_instance_types" {
  description = "Instance types for EKS nodes"
  type        = list(string)
  default     = ["t4g.small", "t4g.micro"]
}

variable "gpu_instance_types" {
  description = "GPU instance types for training"
  type        = list(string)
  default     = ["g5.xlarge", "g5.2xlarge"]
}

variable "eks_version" {
  description = "EKS cluster version"
  type        = string
  default     = "1.28"
}


variable "data_isolation" {
  description = "Data isolation level"
  type        = string
  default     = "strict"
}

variable "cost_optimization" {
  description = "Enable cost optimization"
  type        = bool
  default     = true
}

variable "enable_monitoring" {
  description = "Enable monitoring"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Log retention days"
  type        = number
  default     = 3
}

variable "enable_cost_alerts" {
  description = "Enable cost alerts"
  type        = bool
  default     = true
}

variable "enable_encryption" {
  description = "Enable encryption"
  type        = bool
  default     = true
}

variable "enable_waf" {
  description = "Enable WAF"
  type        = bool
  default     = false
}

variable "enable_cloudtrail" {
  description = "Enable CloudTrail"
  type        = bool
  default     = true
}

variable "enable_bedrock" {
  description = "Enable AWS Bedrock"
  type        = bool
  default     = true
}

variable "enable_openai" {
  description = "Enable OpenAI"
  type        = bool
  default     = true
}

variable "enable_huggingface" {
  description = "Enable HuggingFace"
  type        = bool
  default     = true
}

variable "enable_custom_models" {
  description = "Enable custom models"
  type        = bool
  default     = true
}

variable "gpu_training_instances" {
  description = "GPU training instance types"
  type        = list(string)
  default     = ["g5.xlarge"]
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

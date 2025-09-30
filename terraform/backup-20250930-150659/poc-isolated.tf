# Proof of Concept - Isolated Multi-Tenant AI Platform
# Designed for 2 trial clients with complete data isolation

# VPC with dedicated subnets for 2 tenants
resource "aws_vpc" "poc_isolated" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-poc-isolated-vpc"
    Environment = "poc"
    DataIsolation = "strict"
  }
}

# Dedicated subnets for 2 tenants
resource "aws_subnet" "tenant_dedicated" {
  count = 2  # Only 2 tenants for POC

  vpc_id                  = aws_vpc.poc_isolated.id
  cidr_block              = "10.0.${count.index + 1}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index % 2]
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-tenant-${count.index + 1}-subnet"
    Tenant = "tenant-${count.index + 1}"
    Type = "dedicated"
    AZ = data.aws_availability_zones.available.names[count.index % 2]
  }
}

# Shared subnets for common services
resource "aws_subnet" "shared_public" {
  count = 2  # Only 2 AZs for POC

  vpc_id                  = aws_vpc.poc_isolated.id
  cidr_block              = "10.0.${count.index + 10}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-shared-public-subnet-${count.index + 1}"
    Type = "shared-public"
    AZ = data.aws_availability_zones.available.names[count.index]
  }
}

resource "aws_subnet" "shared_private" {
  count = 2  # Only 2 AZs for POC

  vpc_id            = aws_vpc.poc_isolated.id
  cidr_block        = "10.0.${count.index + 20}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.project_name}-shared-private-subnet-${count.index + 1}"
    Type = "shared-private"
    AZ = data.aws_availability_zones.available.names[count.index]
  }
}

# Internet Gateway
resource "aws_internet_gateway" "poc_isolated" {
  vpc_id = aws_vpc.poc_isolated.id

  tags = {
    Name = "${var.project_name}-poc-isolated-igw"
  }
}

# NAT Gateways (only 2 for POC)
resource "aws_eip" "poc_nat" {
  count = 2

  domain = "vpc"
  depends_on = [aws_internet_gateway.poc_isolated]

  tags = {
    Name = "${var.project_name}-poc-nat-eip-${count.index + 1}"
    AZ = data.aws_availability_zones.available.names[count.index]
  }
}

resource "aws_nat_gateway" "poc_isolated" {
  count = 2

  allocation_id = aws_eip.poc_nat[count.index].id
  subnet_id     = aws_subnet.shared_public[count.index].id

  tags = {
    Name = "${var.project_name}-poc-nat-gateway-${count.index + 1}"
    AZ = data.aws_availability_zones.available.names[count.index]
  }

  depends_on = [aws_internet_gateway.poc_isolated]
}

# Route Tables
resource "aws_route_table" "shared_public" {
  vpc_id = aws_vpc.poc_isolated.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.poc_isolated.id
  }

  tags = {
    Name = "${var.project_name}-shared-public-rt"
  }
}

resource "aws_route_table" "shared_private" {
  count = 2

  vpc_id = aws_vpc.poc_isolated.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.poc_isolated[count.index].id
  }

  tags = {
    Name = "${var.project_name}-shared-private-rt-${count.index + 1}"
    AZ = data.aws_availability_zones.available.names[count.index]
  }
}

# Route Table Associations
resource "aws_route_table_association" "shared_public" {
  count = 2

  subnet_id      = aws_subnet.shared_public[count.index].id
  route_table_id = aws_route_table.shared_public.id
}

resource "aws_route_table_association" "shared_private" {
  count = 2

  subnet_id      = aws_subnet.shared_private[count.index].id
  route_table_id = aws_route_table.shared_private[count.index].id
}

# Shared EKS cluster for common services
resource "aws_eks_cluster" "poc_shared" {
  name     = "${var.project_name}-poc-shared-cluster"
  role_arn = aws_iam_role.eks_cluster.arn
  version  = "1.28"

  vpc_config {
    subnet_ids              = aws_subnet.shared_private[*].id
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = ["0.0.0.0/0"]
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator"]

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_vpc_resource_controller,
  ]

  tags = {
    Name = "${var.project_name}-poc-shared-cluster"
    Environment = "poc"
    Workload = "Shared-Services"
  }
}

# Dedicated EKS clusters for 2 tenants
resource "aws_eks_cluster" "tenant_dedicated" {
  count = 2  # Only 2 tenants for POC

  name     = "${var.project_name}-tenant-${count.index + 1}-cluster"
  role_arn = aws_iam_role.eks_cluster.arn
  version  = "1.28"

  vpc_config {
    subnet_ids              = [
      aws_subnet.tenant_dedicated[count.index].id,
      aws_subnet.shared_private[count.index == 0 ? 1 : 0].id
    ]
    endpoint_private_access = true
    endpoint_public_access  = false  # Private only for tenant clusters
    public_access_cidrs     = []
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator"]

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_vpc_resource_controller,
  ]

  tags = {
    Name = "${var.project_name}-tenant-${count.index + 1}-cluster"
    Environment = "poc"
    Tenant = "tenant-${count.index + 1}"
    DataIsolation = "strict"
  }
}

# Node groups for shared cluster
resource "aws_eks_node_group" "shared_general" {
  cluster_name    = aws_eks_cluster.poc_shared.name
  node_group_name = "shared-general-nodes"
  node_role_arn   = aws_iam_role.eks_node_group.arn
  subnet_ids      = aws_subnet.shared_private[*].id

  capacity_type  = "ON_DEMAND"
  instance_types = ["t4g.small", "t4g.micro"]  # Smaller instances for POC

  scaling_config {
    desired_size = 1
    max_size     = 3
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  ami_type       = "AL2_ARM_64"
  disk_size      = 50  # Smaller disk for POC

  labels = {
    workload-type = "shared-general"
    node-type     = "on-demand"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_container_registry_read_only,
  ]

  tags = {
    Name = "${var.project_name}-shared-general-nodes"
  }
}

# GPU nodes for shared cluster (for model training)
resource "aws_eks_node_group" "shared_gpu" {
  cluster_name    = aws_eks_cluster.poc_shared.name
  node_group_name = "shared-gpu-nodes"
  node_role_arn   = aws_iam_role.eks_node_group.arn
  subnet_ids      = aws_subnet.shared_private[*].id

  capacity_type  = "ON_DEMAND"
  instance_types = ["g5.xlarge"]  # Smaller GPU instance for POC

  scaling_config {
    desired_size = 0  # Start with 0, scale up when needed
    max_size     = 2
    min_size     = 0
  }

  update_config {
    max_unavailable = 1
  }

  ami_type       = "AL2_x86_64_GPU"
  disk_size      = 100

  labels = {
    workload-type = "gpu-training"
    node-type     = "gpu"
    "nvidia.com/gpu" = "true"
  }

  taint {
    key    = "gpu-training"
    value  = "true"
    effect = "NO_SCHEDULE"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_container_registry_read_only,
  ]

  tags = {
    Name = "${var.project_name}-shared-gpu-nodes"
  }
}

# Dedicated node groups for each tenant cluster
resource "aws_eks_node_group" "tenant_dedicated" {
  count = 2

  cluster_name    = aws_eks_cluster.tenant_dedicated[count.index].name
  node_group_name = "tenant-${count.index + 1}-nodes"
  node_role_arn   = aws_iam_role.eks_node_group.arn
  subnet_ids      = [aws_subnet.tenant_dedicated[count.index].id]

  capacity_type  = "ON_DEMAND"
  instance_types = ["t4g.medium"]  # Smaller instances for POC

  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  ami_type       = "AL2_ARM_64"
  disk_size      = 50  # Smaller disk for POC

  labels = {
    workload-type = "tenant-dedicated"
    node-type     = "on-demand"
    tenant = "tenant-${count.index + 1}"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_container_registry_read_only,
  ]

  tags = {
    Name = "${var.project_name}-tenant-${count.index + 1}-nodes"
    Tenant = "tenant-${count.index + 1}"
  }
}

# Dedicated RDS instances for each tenant
resource "aws_db_instance" "tenant_dedicated" {
  count = 2

  identifier = "${var.project_name}-tenant-${count.index + 1}-db"

  engine         = "postgres"
  engine_version = "15.7"
  instance_class = "db.t4g.micro"  # Smallest Graviton3 RDS instance

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id           = aws_kms_key.tenant_keys[count.index].arn

  db_name  = "tenant_${count.index + 1}_db"
  username = "tenant_${count.index + 1}_user"
  password = var.tenant_passwords[count.index]

  vpc_security_group_ids = [aws_security_group.tenant_rds[count.index].id]
  db_subnet_group_name   = aws_db_subnet_group.tenant_dedicated[count.index].name

  backup_retention_period = 1  # Minimal backup for POC
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"

  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Name = "${var.project_name}-tenant-${count.index + 1}-database"
    Tenant = "tenant-${count.index + 1}"
    DataIsolation = "strict"
  }
}

# RDS subnet groups for each tenant
resource "aws_db_subnet_group" "tenant_dedicated" {
  count = 2

  name       = "${var.project_name}-tenant-${count.index + 1}-db-subnet-group"
  subnet_ids = [
    aws_subnet.tenant_dedicated[count.index].id,
    aws_subnet.shared_private[count.index == 0 ? 1 : 0].id
  ]

  tags = {
    Name = "${var.project_name}-tenant-${count.index + 1}-db-subnet-group"
    Tenant = "tenant-${count.index + 1}"
  }
}

# Dedicated ElastiCache Redis for each tenant
resource "aws_elasticache_replication_group" "tenant_dedicated" {
  count = 2

  replication_group_id       = "${var.project_name}-tenant-${count.index + 1}-redis"
  description                = "Dedicated Redis for tenant ${count.index + 1}"
  
  node_type                  = "cache.t4g.micro"  # Smallest Graviton3 Redis
  port                       = 6379
  parameter_group_name       = "default.redis7"
  
  num_cache_clusters         = 1  # Single node for POC
  
  subnet_group_name          = aws_elasticache_subnet_group.tenant_dedicated[count.index].name
  security_group_ids         = [aws_security_group.tenant_redis[count.index].id]
  
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = var.tenant_redis_passwords[count.index]
  
  snapshot_retention_limit = 1  # Minimal backup for POC
  snapshot_window         = "03:00-05:00"
  
  tags = {
    Name = "${var.project_name}-tenant-${count.index + 1}-redis"
    Tenant = "tenant-${count.index + 1}"
    DataIsolation = "strict"
  }
}

# ElastiCache subnet groups for each tenant
resource "aws_elasticache_subnet_group" "tenant_dedicated" {
  count = 2

  name       = "${var.project_name}-tenant-${count.index + 1}-cache-subnet"
  subnet_ids = [
    aws_subnet.tenant_dedicated[count.index].id,
    aws_subnet.shared_private[count.index == 0 ? 1 : 0].id
  ]

  tags = {
    Name = "${var.project_name}-tenant-${count.index + 1}-cache-subnet"
    Tenant = "tenant-${count.index + 1}"
  }
}

# Dedicated S3 buckets for each tenant
resource "aws_s3_bucket" "tenant_dedicated" {
  count = 2

  bucket = "${var.project_name}-tenant-${count.index + 1}-data-${random_string.bucket_suffix[count.index].result}"

  tags = {
    Name = "${var.project_name}-tenant-${count.index + 1}-data"
    Tenant = "tenant-${count.index + 1}"
    DataIsolation = "strict"
  }
}

resource "aws_s3_bucket_versioning" "tenant_dedicated" {
  count = 2

  bucket = aws_s3_bucket.tenant_dedicated[count.index].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tenant_dedicated" {
  count = 2

  bucket = aws_s3_bucket.tenant_dedicated[count.index].id

  rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.tenant_keys[count.index].arn
        sse_algorithm     = "aws:kms"
      }
  }
}

resource "aws_s3_bucket_public_access_block" "tenant_dedicated" {
  count = 2

  bucket = aws_s3_bucket.tenant_dedicated[count.index].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# KMS keys for each tenant
resource "aws_kms_key" "tenant_keys" {
  count = 2

  description             = "KMS key for tenant ${count.index + 1} data encryption"
  deletion_window_in_days = 7

  tags = {
    Name = "${var.project_name}-tenant-${count.index + 1}-kms-key"
    Tenant = "tenant-${count.index + 1}"
  }
}

resource "aws_kms_alias" "tenant_keys" {
  count = 2

  name          = "alias/${var.project_name}-tenant-${count.index + 1}"
  target_key_id = aws_kms_key.tenant_keys[count.index].key_id
}

# Random strings for S3 bucket names
resource "random_string" "bucket_suffix" {
  count = 2

  length  = 8
  special = false
  upper   = false
}

# Security Groups for each tenant
resource "aws_security_group" "tenant_rds" {
  count = 2

  name_prefix = "${var.project_name}-tenant-${count.index + 1}-rds-"
  vpc_id      = aws_vpc.poc_isolated.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.tenant_eks[count.index].id]
  }

  tags = {
    Name = "${var.project_name}-tenant-${count.index + 1}-rds-sg"
    Tenant = "tenant-${count.index + 1}"
  }
}

resource "aws_security_group" "tenant_redis" {
  count = 2

  name_prefix = "${var.project_name}-tenant-${count.index + 1}-redis-"
  vpc_id      = aws_vpc.poc_isolated.id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.tenant_eks[count.index].id]
  }

  tags = {
    Name = "${var.project_name}-tenant-${count.index + 1}-redis-sg"
    Tenant = "tenant-${count.index + 1}"
  }
}

resource "aws_security_group" "tenant_eks" {
  count = 2

  name_prefix = "${var.project_name}-tenant-${count.index + 1}-eks-"
  vpc_id      = aws_vpc.poc_isolated.id

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["10.0.${count.index + 1}.0/24"]  # Only from tenant subnet
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-tenant-${count.index + 1}-eks-sg"
    Tenant = "tenant-${count.index + 1}"
  }
}

# Application Load Balancer for shared services
resource "aws_lb" "poc_shared" {
  name               = "mtai-poc-shared-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.shared_alb.id]
  subnets            = aws_subnet.shared_public[*].id

  enable_deletion_protection = false

  tags = {
    Name = "${var.project_name}-poc-shared-alb"
    Environment = "poc"
  }
}

# ALB Target Group
resource "aws_lb_target_group" "poc_shared" {
  name     = "${var.project_name}-poc-shared-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.poc_isolated.id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${var.project_name}-poc-shared-target-group"
  }
}

# ALB Listener
resource "aws_lb_listener" "poc_shared" {
  load_balancer_arn = aws_lb.poc_shared.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.poc_shared.arn
  }
}

# Security Groups
resource "aws_security_group" "shared_alb" {
  name_prefix = "${var.project_name}-poc-shared-alb-"
  vpc_id      = aws_vpc.poc_isolated.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-poc-shared-alb-sg"
  }
}

# IAM roles (reusing from previous configurations)
resource "aws_iam_role" "eks_cluster" {
  name = "${var.project_name}-poc-eks-cluster-role"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role" "eks_node_group" {
  name = "${var.project_name}-poc-eks-node-group-role"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

# IAM policy attachments
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role_policy_attachment" "eks_vpc_resource_controller" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "eks_container_registry_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_group.name
}

# Outputs
output "poc_alb_dns_name" {
  description = "DNS name of the POC load balancer"
  value       = aws_lb.poc_shared.dns_name
}

output "tenant_database_endpoints" {
  description = "RDS instance endpoints"
  value       = [for db in aws_db_instance.tenant_dedicated : db.endpoint]
  sensitive   = true
}

output "tenant_redis_endpoints" {
  description = "Redis cluster endpoints"
  value       = [for redis in aws_elasticache_replication_group.tenant_dedicated : redis.primary_endpoint_address]
  sensitive   = true
}

output "tenant_s3_buckets" {
  description = "S3 bucket names"
  value       = [for bucket in aws_s3_bucket.tenant_dedicated : bucket.bucket]
}

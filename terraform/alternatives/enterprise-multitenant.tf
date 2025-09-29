# Enterprise-scale multi-tenant AI platform architecture
# Designed for 500+ users per company, multiple companies, 5000+ concurrent users

# Global VPC with multiple AZs for high availability
resource "aws_vpc" "enterprise_main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-enterprise-vpc"
    Environment = var.environment
    Workload = "Multi-Tenant-AI"
  }
}

# Multiple public subnets across AZs
resource "aws_subnet" "enterprise_public" {
  count = 6  # 3 AZs × 2 subnets per AZ

  vpc_id                  = aws_vpc.enterprise_main.id
  cidr_block              = "10.0.${count.index + 1}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index % 3]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet-${count.index + 1}"
    Type = "Public"
    AZ   = data.aws_availability_zones.available.names[count.index % 3]
  }
}

# Multiple private subnets across AZs
resource "aws_subnet" "enterprise_private" {
  count = 6  # 3 AZs × 2 subnets per AZ

  vpc_id            = aws_vpc.enterprise_main.id
  cidr_block        = "10.0.${count.index + 10}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index % 3]

  tags = {
    Name = "${var.project_name}-private-subnet-${count.index + 1}"
    Type = "Private"
    AZ   = data.aws_availability_zones.available.names[count.index % 3]
  }
}

# Internet Gateway
resource "aws_internet_gateway" "enterprise_main" {
  vpc_id = aws_vpc.enterprise_main.id

  tags = {
    Name = "${var.project_name}-enterprise-igw"
  }
}

# NAT Gateways for each AZ (high availability)
resource "aws_eip" "enterprise_nat" {
  count = 3  # One per AZ

  domain = "vpc"
  depends_on = [aws_internet_gateway.enterprise_main]

  tags = {
    Name = "${var.project_name}-nat-eip-${count.index + 1}"
    AZ   = data.aws_availability_zones.available.names[count.index]
  }
}

resource "aws_nat_gateway" "enterprise_main" {
  count = 3

  allocation_id = aws_eip.enterprise_nat[count.index].id
  subnet_id     = aws_subnet.enterprise_public[count.index].id

  tags = {
    Name = "${var.project_name}-nat-gateway-${count.index + 1}"
    AZ   = data.aws_availability_zones.available.names[count.index]
  }

  depends_on = [aws_internet_gateway.enterprise_main]
}

# Route Tables
resource "aws_route_table" "enterprise_public" {
  vpc_id = aws_vpc.enterprise_main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.enterprise_main.id
  }

  tags = {
    Name = "${var.project_name}-enterprise-public-rt"
  }
}

resource "aws_route_table" "enterprise_private" {
  count = 3  # One per AZ

  vpc_id = aws_vpc.enterprise_main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.enterprise_main[count.index].id
  }

  tags = {
    Name = "${var.project_name}-enterprise-private-rt-${count.index + 1}"
    AZ   = data.aws_availability_zones.available.names[count.index]
  }
}

# Route Table Associations
resource "aws_route_table_association" "enterprise_public" {
  count = 6

  subnet_id      = aws_subnet.enterprise_public[count.index].id
  route_table_id = aws_route_table.enterprise_public.id
}

resource "aws_route_table_association" "enterprise_private" {
  count = 6

  subnet_id      = aws_subnet.enterprise_private[count.index].id
  route_table_id = aws_route_table.enterprise_private[count.index % 3].id
}

# Enterprise-scale EKS cluster
resource "aws_eks_cluster" "enterprise_main" {
  name     = "${var.project_name}-enterprise-cluster"
  role_arn = aws_iam_role.eks_cluster.arn
  version  = "1.28"

  vpc_config {
    subnet_ids              = concat(aws_subnet.enterprise_private[*].id)
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = ["0.0.0.0/0"]
  }

  # Enable logging
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_vpc_resource_controller,
  ]

  tags = {
    Name = "${var.project_name}-enterprise-cluster"
    Environment = var.environment
    Workload = "Multi-Tenant-AI"
  }
}

# Multiple node groups for different workloads
resource "aws_eks_node_group" "enterprise_general" {
  cluster_name    = aws_eks_cluster.enterprise_main.name
  node_group_name = "general-nodes"
  node_role_arn   = aws_iam_role.eks_node_group.arn
  subnet_ids      = aws_subnet.enterprise_private[*].id

  capacity_type  = "ON_DEMAND"
  instance_types = ["c6g.2xlarge", "c6g.4xlarge"]  # Graviton3 for cost efficiency

  scaling_config {
    desired_size = 3
    max_size     = 20
    min_size     = 3
  }

  update_config {
    max_unavailable = 1
  }

  ami_type       = "AL2_ARM_64"
  disk_size      = 100

  labels = {
    workload-type = "general"
    node-type     = "on-demand"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_container_registry_read_only,
  ]

  tags = {
    Name = "${var.project_name}-general-nodes"
  }
}

# Spot instances for cost optimization
resource "aws_eks_node_group" "enterprise_spot" {
  cluster_name    = aws_eks_cluster.enterprise_main.name
  node_group_name = "spot-nodes"
  node_role_arn   = aws_iam_role.eks_node_group.arn
  subnet_ids      = aws_subnet.enterprise_private[*].id

  capacity_type  = "SPOT"
  instance_types = ["c6g.2xlarge", "c6g.4xlarge", "m6g.2xlarge", "r6g.2xlarge"]

  scaling_config {
    desired_size = 0
    max_size     = 50
    min_size     = 0
  }

  update_config {
    max_unavailable = 1
  }

  ami_type       = "AL2_ARM_64"
  disk_size      = 100

  labels = {
    workload-type = "spot"
    node-type     = "spot"
    cost-optimized = "true"
  }

  taints {
    key    = "spot-instance"
    value  = "true"
    effect = "NO_SCHEDULE"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_container_registry_read_only,
  ]

  tags = {
    Name = "${var.project_name}-spot-nodes"
  }
}

# GPU nodes for high-performance AI workloads
resource "aws_eks_node_group" "enterprise_gpu" {
  cluster_name    = aws_eks_cluster.enterprise_main.name
  node_group_name = "gpu-nodes"
  node_role_arn   = aws_iam_role.eks_node_group.arn
  subnet_ids      = aws_subnet.enterprise_private[*].id

  capacity_type  = "ON_DEMAND"
  instance_types = ["g5.2xlarge", "g5.4xlarge"]  # NVIDIA A10G GPUs

  scaling_config {
    desired_size = 2
    max_size     = 10
    min_size     = 0
  }

  update_config {
    max_unavailable = 1
  }

  ami_type       = "AL2_x86_64_GPU"
  disk_size      = 200

  labels = {
    workload-type = "gpu"
    node-type     = "gpu"
    nvidia.com/gpu = "true"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_container_registry_read_only,
  ]

  tags = {
    Name = "${var.project_name}-gpu-nodes"
  }
}

# Multi-AZ RDS cluster for high availability
resource "aws_rds_cluster" "enterprise_main" {
  cluster_identifier = "${var.project_name}-enterprise-cluster"
  
  engine         = "aurora-postgresql"
  engine_version = "15.4"
  engine_mode    = "provisioned"
  
  database_name   = var.database_name
  master_username = var.database_username
  master_password = var.database_password
  
  backup_retention_period = 7
  preferred_backup_window = "03:00-04:00"
  preferred_maintenance_window = "sun:04:00-sun:05:00"
  
  db_subnet_group_name   = aws_db_subnet_group.enterprise_main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  
  storage_encrypted = true
  kms_key_id       = aws_kms_key.rds.arn
  
  skip_final_snapshot = true
  deletion_protection = false
  
  # Performance optimizations
  performance_insights_enabled = true
  performance_insights_retention_period = 7
  
  # Multi-AZ configuration
  availability_zones = data.aws_availability_zones.available.names
  
  tags = {
    Name = "${var.project_name}-enterprise-cluster"
    Environment = var.environment
    Workload = "Multi-Tenant-AI"
  }
}

# RDS cluster instances
resource "aws_rds_cluster_instance" "enterprise_main" {
  count = 3  # Multi-AZ setup
  
  identifier         = "${var.project_name}-enterprise-${count.index + 1}"
  cluster_identifier = aws_rds_cluster.enterprise_main.id
  instance_class     = "db.r6g.xlarge"  # Graviton3 for cost efficiency
  engine             = aws_rds_cluster.enterprise_main.engine
  engine_version     = aws_rds_cluster.enterprise_main.engine_version
  
  performance_insights_enabled = true
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_enhanced_monitoring.arn
  
  tags = {
    Name = "${var.project_name}-enterprise-${count.index + 1}"
    Environment = var.environment
  }
}

# RDS subnet group
resource "aws_db_subnet_group" "enterprise_main" {
  name       = "${var.project_name}-enterprise-db-subnet-group"
  subnet_ids = aws_subnet.enterprise_private[*].id

  tags = {
    Name = "${var.project_name}-enterprise-db-subnet-group"
  }
}

# ElastiCache Redis cluster for caching
resource "aws_elasticache_replication_group" "enterprise_main" {
  replication_group_id       = "${var.project_name}-enterprise-redis"
  description                = "Enterprise Redis cluster for multi-tenant caching"
  
  node_type                  = "r6g.xlarge"  # Graviton3 for cost efficiency
  port                       = 6379
  parameter_group_name       = "default.redis7"
  
  num_cache_clusters         = 6  # Multi-AZ setup
  
  subnet_group_name          = aws_elasticache_subnet_group.enterprise_main.name
  security_group_ids         = [aws_security_group.redis.id]
  
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  
  # Performance optimizations
  snapshot_retention_limit = 7
  snapshot_window         = "03:00-05:00"
  
  # Multi-AZ configuration
  automatic_failover_enabled = true
  multi_az_enabled          = true
  
  tags = {
    Name = "${var.project_name}-enterprise-redis"
    Environment = var.environment
    Workload = "Multi-Tenant-AI"
  }
}

# ElastiCache subnet group
resource "aws_elasticache_subnet_group" "enterprise_main" {
  name       = "${var.project_name}-enterprise-cache-subnet"
  subnet_ids = aws_subnet.enterprise_private[*].id
}

# Application Load Balancer with multiple target groups
resource "aws_lb" "enterprise_main" {
  name               = "${var.project_name}-enterprise-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.enterprise_public[*].id

  enable_deletion_protection = false

  tags = {
    Name = "${var.project_name}-enterprise-alb"
    Environment = var.environment
    Workload = "Multi-Tenant-AI"
  }
}

# Target group for general workloads
resource "aws_lb_target_group" "enterprise_general" {
  name     = "${var.project_name}-general-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.enterprise_main.id
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
    Name = "${var.project_name}-general-target-group"
  }
}

# Target group for GPU workloads
resource "aws_lb_target_group" "enterprise_gpu" {
  name     = "${var.project_name}-gpu-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.enterprise_main.id
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
    Name = "${var.project_name}-gpu-target-group"
  }
}

# ALB Listener with intelligent routing
resource "aws_lb_listener" "enterprise_main" {
  load_balancer_arn = aws_lb.enterprise_main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.enterprise_general.arn
  }
}

# Routing rules for different workloads
resource "aws_lb_listener_rule" "gpu_workloads" {
  listener_arn = aws_lb_listener.enterprise_main.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.enterprise_gpu.arn
  }

  condition {
    path_pattern {
      values = ["/api/v1/gpu/*", "/api/v1/inference/*"]
    }
  }
}

# CloudFront distribution for global content delivery
resource "aws_cloudfront_distribution" "enterprise_main" {
  origin {
    domain_name = aws_lb.enterprise_main.dns_name
    origin_id   = "enterprise-alb"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "enterprise-alb"

    forwarded_values {
      query_string = true
      headers      = ["Authorization", "CloudFront-Forwarded-Proto"]
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  # Cache behavior for API endpoints
  ordered_cache_behavior {
    path_pattern     = "/api/*"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "enterprise-alb"

    forwarded_values {
      query_string = true
      headers      = ["Authorization", "CloudFront-Forwarded-Proto"]
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "https-only"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name = "${var.project_name}-enterprise-cdn"
    Environment = var.environment
  }
}

# KMS key for encryption
resource "aws_kms_key" "rds" {
  description             = "KMS key for RDS encryption"
  deletion_window_in_days = 7

  tags = {
    Name = "${var.project_name}-rds-kms-key"
  }
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${var.project_name}-rds"
  target_key_id = aws_kms_key.rds.key_id
}

# Security Groups
resource "aws_security_group" "enterprise_alb" {
  name_prefix = "${var.project_name}-enterprise-alb-"
  vpc_id      = aws_vpc.enterprise_main.id

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
    Name = "${var.project_name}-enterprise-alb-sg"
  }
}

resource "aws_security_group" "enterprise_eks" {
  name_prefix = "${var.project_name}-enterprise-eks-"
  vpc_id      = aws_vpc.enterprise_main.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.enterprise_alb.id]
  }

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.enterprise_alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-enterprise-eks-sg"
  }
}

resource "aws_security_group" "enterprise_rds" {
  name_prefix = "${var.project_name}-enterprise-rds-"
  vpc_id      = aws_vpc.enterprise_main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.enterprise_eks.id]
  }

  tags = {
    Name = "${var.project_name}-enterprise-rds-sg"
  }
}

resource "aws_security_group" "enterprise_redis" {
  name_prefix = "${var.project_name}-enterprise-redis-"
  vpc_id      = aws_vpc.enterprise_main.id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.enterprise_eks.id]
  }

  tags = {
    Name = "${var.project_name}-enterprise-redis-sg"
  }
}

# IAM roles (reusing from previous configurations)
resource "aws_iam_role" "eks_cluster" {
  name = "${var.project_name}-enterprise-eks-cluster-role"

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
  name = "${var.project_name}-enterprise-eks-node-group-role"

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

resource "aws_iam_role" "rds_enhanced_monitoring" {
  name = "${var.project_name}-enterprise-rds-enhanced-monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
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

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  role       = aws_iam_role.rds_enhanced_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

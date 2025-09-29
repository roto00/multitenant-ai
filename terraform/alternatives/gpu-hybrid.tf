# Hybrid GPU + Bedrock architecture for multi-tenant AI platform
# This configuration provides both ultra-low latency GPU inference and cost-effective Bedrock

# GPU-enabled EKS cluster for custom model inference
resource "aws_eks_cluster" "gpu_cluster" {
  name     = "${var.project_name}-gpu-cluster"
  role_arn = aws_iam_role.eks_cluster.arn
  version  = "1.28"

  vpc_config {
    subnet_ids              = aws_subnet.private[*].id
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = ["0.0.0.0/0"]
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_vpc_resource_controller,
  ]

  tags = {
    Name = "${var.project_name}-gpu-cluster"
    Workload = "AI-GPU-Inference"
  }
}

# EKS Node Group with GPU instances
resource "aws_eks_node_group" "gpu_nodes" {
  cluster_name    = aws_eks_cluster.gpu_cluster.name
  node_group_name = "gpu-nodes"
  node_role_arn   = aws_iam_role.eks_node_group.arn
  subnet_ids      = aws_subnet.private[*].id

  capacity_type  = "ON_DEMAND"
  instance_types = ["g5.xlarge", "g5.2xlarge"]  # NVIDIA A10G GPUs

  scaling_config {
    desired_size = 1
    max_size     = 5
    min_size     = 0  # Scale to zero when not needed
  }

  update_config {
    max_unavailable = 1
  }

  # GPU-specific configurations
  ami_type       = "AL2_x86_64_GPU"
  disk_size      = 100

  labels = {
    workload-type = "gpu-inference"
    node-type     = "gpu"
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

# Spot instance node group for cost optimization
resource "aws_eks_node_group" "gpu_spot_nodes" {
  cluster_name    = aws_eks_cluster.gpu_cluster.name
  node_group_name = "gpu-spot-nodes"
  node_role_arn   = aws_iam_role.eks_node_group.arn
  subnet_ids      = aws_subnet.private[*].id

  capacity_type  = "SPOT"
  instance_types = ["g5.xlarge", "g5.2xlarge", "g4dn.xlarge"]

  scaling_config {
    desired_size = 0  # Start with 0, scale based on demand
    max_size     = 10
    min_size     = 0
  }

  update_config {
    max_unavailable = 1
  }

  ami_type       = "AL2_x86_64_GPU"
  disk_size      = 100

  labels = {
    workload-type = "gpu-inference"
    node-type     = "gpu-spot"
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
    Name = "${var.project_name}-gpu-spot-nodes"
  }
}

# AWS Inferentia instances for cost-effective inference
resource "aws_eks_node_group" "inferentia_nodes" {
  cluster_name    = aws_eks_cluster.gpu_cluster.name
  node_group_name = "inferentia-nodes"
  node_role_arn   = aws_iam_role.eks_node_group.arn
  subnet_ids      = aws_subnet.private[*].id

  capacity_type  = "ON_DEMAND"
  instance_types = ["inf1.xlarge", "inf1.2xlarge"]  # AWS Inferentia

  scaling_config {
    desired_size = 1
    max_size     = 3
    min_size     = 0
  }

  update_config {
    max_unavailable = 1
  }

  ami_type       = "AL2_x86_64"
  disk_size      = 100

  labels = {
    workload-type = "inferentia-inference"
    node-type     = "inferentia"
    cost-optimized = "true"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_container_registry_read_only,
  ]

  tags = {
    Name = "${var.project_name}-inferentia-nodes"
  }
}

# IAM roles for EKS
resource "aws_iam_role" "eks_cluster" {
  name = "${var.project_name}-eks-cluster-role"

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
  name = "${var.project_name}-eks-node-group-role"

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

# GPU-optimized RDS for model metadata
resource "aws_db_instance" "gpu_main" {
  identifier = "${var.project_name}-gpu-db"

  engine         = "postgres"
  engine_version = "15.4"
  instance_class = "db.r6g.xlarge"  # Larger instance for GPU workloads

  allocated_storage     = 200
  max_allocated_storage = 2000
  storage_type          = "gp3"
  storage_encrypted     = true
  storage_throughput    = 4000

  db_name  = var.database_name
  username = var.database_username
  password = var.database_password

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name

  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"

  performance_insights_enabled = true
  performance_insights_retention_period = 7

  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Name = "${var.project_name}-gpu-database"
    Workload = "AI-GPU-Inference"
  }
}

# Enhanced ElastiCache for GPU workloads
resource "aws_elasticache_replication_group" "gpu_main" {
  replication_group_id       = "${var.project_name}-gpu-redis"
  description                = "GPU-optimized Redis cluster"
  
  node_type                  = "r6g.xlarge"  # Larger instance for GPU workloads
  port                       = 6379
  parameter_group_name       = "default.redis7"
  
  num_cache_clusters         = 3
  
  subnet_group_name          = aws_elasticache_subnet_group.main.name
  security_group_ids         = [aws_security_group.redis.id]
  
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  
  snapshot_retention_limit = 7
  snapshot_window         = "03:00-05:00"
  
  tags = {
    Name = "${var.project_name}-gpu-redis"
    Workload = "AI-GPU-Inference"
  }
}

# Application Load Balancer for routing
resource "aws_lb" "gpu_main" {
  name               = "${var.project_name}-gpu-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false

  tags = {
    Name = "${var.project_name}-gpu-alb"
    Workload = "AI-GPU-Inference"
  }
}

# Target group for GPU inference
resource "aws_lb_target_group" "gpu_inference" {
  name     = "${var.project_name}-gpu-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
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

# ALB Listener with routing rules
resource "aws_lb_listener" "gpu_main" {
  load_balancer_arn = aws_lb.gpu_main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn  # Default to Bedrock
  }
}

# Routing rule for GPU inference
resource "aws_lb_listener_rule" "gpu_inference" {
  listener_arn = aws_lb_listener.gpu_main.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.gpu_inference.arn
  }

  condition {
    path_pattern {
      values = ["/api/v1/gpu/*"]
    }
  }
}

# CloudWatch dashboard for GPU monitoring
resource "aws_cloudwatch_dashboard" "gpu_dashboard" {
  dashboard_name = "${var.project_name}-gpu-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/EKS", "cluster_failed_request_count", "ClusterName", aws_eks_cluster.gpu_cluster.name],
            [".", "cluster_request_count", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "EKS Cluster Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", "${var.project_name}-gpu-nodes"],
            [".", "GPUUtilization", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "GPU Node Metrics"
          period  = 300
        }
      }
    ]
  })
}

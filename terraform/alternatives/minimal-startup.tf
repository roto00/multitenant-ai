# Minimal startup configuration for 2 trial tenants
# Optimized for cost while maintaining functionality

# Single AZ VPC for cost savings
resource "aws_vpc" "minimal_main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-minimal-vpc"
    Environment = "startup"
  }
}

# Single public subnet (no NAT Gateway needed)
resource "aws_subnet" "minimal_public" {
  vpc_id                  = aws_vpc.minimal_main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-minimal-public-subnet"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "minimal_main" {
  vpc_id = aws_vpc.minimal_main.id

  tags = {
    Name = "${var.project_name}-minimal-igw"
  }
}

# Route Table
resource "aws_route_table" "minimal_public" {
  vpc_id = aws_vpc.minimal_main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.minimal_main.id
  }

  tags = {
    Name = "${var.project_name}-minimal-public-rt"
  }
}

resource "aws_route_table_association" "minimal_public" {
  subnet_id      = aws_subnet.minimal_public.id
  route_table_id = aws_route_table.minimal_public.id
}

# Single EC2 instance with auto-scaling (minimal)
resource "aws_launch_template" "minimal_app" {
  name_prefix   = "${var.project_name}-minimal-"
  image_id      = data.aws_ami.amazon_linux_arm64.id
  instance_type = "t4g.small"  # Smallest ARM64 Graviton instance
  
  vpc_security_group_ids = [aws_security_group.minimal_ec2.id]
  
  user_data = base64encode(templatefile("${path.module}/minimal_user_data.sh", {
    ecr_repo_url = aws_ecr_repository.main.repository_url
    database_url = "postgresql://${var.database_username}:${var.database_password}@${aws_db_instance.minimal_main.endpoint}/${var.database_name}"
    redis_url    = "redis://${aws_elasticache_replication_group.minimal_main.primary_endpoint_address}:6379"
  }))
  
  iam_instance_profile {
    name = aws_iam_instance_profile.minimal_app.name
  }
  
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-minimal-app"
    }
  }
}

# Auto Scaling Group (1-2 instances)
resource "aws_autoscaling_group" "minimal_app" {
  name                = "${var.project_name}-minimal-asg"
  vpc_zone_identifier = [aws_subnet.minimal_public.id]
  target_group_arns   = [aws_lb_target_group.minimal_main.arn]
  health_check_type   = "ELB"
  health_check_grace_period = 300
  
  min_size         = 1
  max_size         = 2
  desired_capacity = 1
  
  launch_template {
    id      = aws_launch_template.minimal_app.id
    version = "$Latest"
  }
  
  tag {
    key                 = "Name"
    value               = "${var.project_name}-minimal-asg"
    propagate_at_launch = false
  }
}

# Simple auto-scaling policy
resource "aws_autoscaling_policy" "minimal_scale_up" {
  name                   = "${var.project_name}-minimal-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.minimal_app.name
}

resource "aws_autoscaling_policy" "minimal_scale_down" {
  name                   = "${var.project_name}-minimal-scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.minimal_app.name
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "minimal_cpu_high" {
  alarm_name          = "${var.project_name}-minimal-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "High CPU utilization"
  alarm_actions       = [aws_autoscaling_policy.minimal_scale_up.arn]
  
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.minimal_app.name
  }
}

resource "aws_cloudwatch_metric_alarm" "minimal_cpu_low" {
  alarm_name          = "${var.project_name}-minimal-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "20"
  alarm_description   = "Low CPU utilization"
  alarm_actions       = [aws_autoscaling_policy.minimal_scale_down.arn]
  
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.minimal_app.name
  }
}

# Minimal RDS instance (single AZ)
resource "aws_db_instance" "minimal_main" {
  identifier = "${var.project_name}-minimal-db"

  engine         = "postgres"
  engine_version = "15.4"
  instance_class = "db.t4g.micro"  # Smallest Graviton3 RDS instance

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.database_name
  username = var.database_username
  password = var.database_password

  vpc_security_group_ids = [aws_security_group.minimal_rds.id]
  db_subnet_group_name   = aws_db_subnet_group.minimal_main.name

  backup_retention_period = 1  # Minimal backup retention
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"

  skip_final_snapshot = true
  deletion_protection = false

  # Single AZ for cost savings
  multi_az = false

  tags = {
    Name = "${var.project_name}-minimal-database"
  }
}

# RDS Subnet Group (single subnet)
resource "aws_db_subnet_group" "minimal_main" {
  name       = "${var.project_name}-minimal-db-subnet-group"
  subnet_ids = [aws_subnet.minimal_public.id]

  tags = {
    Name = "${var.project_name}-minimal-db-subnet-group"
  }
}

# Minimal ElastiCache Redis (single node)
resource "aws_elasticache_replication_group" "minimal_main" {
  replication_group_id       = "${var.project_name}-minimal-redis"
  description                = "Minimal Redis for startup"
  
  node_type                  = "cache.t4g.micro"  # Smallest Graviton3 Redis
  port                       = 6379
  parameter_group_name       = "default.redis7"
  
  num_cache_clusters         = 1  # Single node for cost savings
  
  subnet_group_name          = aws_elasticache_subnet_group.minimal_main.name
  security_group_ids         = [aws_security_group.minimal_redis.id]
  
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  
  # Minimal backup
  snapshot_retention_limit = 1
  snapshot_window         = "03:00-05:00"
  
  tags = {
    Name = "${var.project_name}-minimal-redis"
  }
}

# ElastiCache subnet group
resource "aws_elasticache_subnet_group" "minimal_main" {
  name       = "${var.project_name}-minimal-cache-subnet"
  subnet_ids = [aws_subnet.minimal_public.id]
}

# Application Load Balancer (minimal)
resource "aws_lb" "minimal_main" {
  name               = "${var.project_name}-minimal-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.minimal_alb.id]
  subnets            = [aws_subnet.minimal_public.id]

  enable_deletion_protection = false

  tags = {
    Name = "${var.project_name}-minimal-alb"
  }
}

# ALB Target Group
resource "aws_lb_target_group" "minimal_main" {
  name     = "${var.project_name}-minimal-tg"
  port     = 8000
  protocol = "HTTP"
  vpc_id   = aws_vpc.minimal_main.id

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
    Name = "${var.project_name}-minimal-target-group"
  }
}

# ALB Listener
resource "aws_lb_listener" "minimal_main" {
  load_balancer_arn = aws_lb.minimal_main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.minimal_main.arn
  }
}

# Security Groups
resource "aws_security_group" "minimal_alb" {
  name_prefix = "${var.project_name}-minimal-alb-"
  vpc_id      = aws_vpc.minimal_main.id

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
    Name = "${var.project_name}-minimal-alb-sg"
  }
}

resource "aws_security_group" "minimal_ec2" {
  name_prefix = "${var.project_name}-minimal-ec2-"
  vpc_id      = aws_vpc.minimal_main.id

  ingress {
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.minimal_alb.id]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # For debugging - restrict in production
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-minimal-ec2-sg"
  }
}

resource "aws_security_group" "minimal_rds" {
  name_prefix = "${var.project_name}-minimal-rds-"
  vpc_id      = aws_vpc.minimal_main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.minimal_ec2.id]
  }

  tags = {
    Name = "${var.project_name}-minimal-rds-sg"
  }
}

resource "aws_security_group" "minimal_redis" {
  name_prefix = "${var.project_name}-minimal-redis-"
  vpc_id      = aws_vpc.minimal_main.id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.minimal_ec2.id]
  }

  tags = {
    Name = "${var.project_name}-minimal-redis-sg"
  }
}

# IAM Role for EC2 instances
resource "aws_iam_role" "minimal_ec2" {
  name = "${var.project_name}-minimal-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "minimal_ec2_ssm" {
  role       = aws_iam_role.minimal_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "minimal_ec2_ecr" {
  name = "${var.project_name}-minimal-ec2-ecr-policy"
  role = aws_iam_role.minimal_ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "minimal_ec2_bedrock" {
  name = "${var.project_name}-minimal-ec2-bedrock-policy"
  role = aws_iam_role.minimal_ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "minimal_app" {
  name = "${var.project_name}-minimal-app-profile"
  role = aws_iam_role.minimal_ec2.name
}

# Data source for Amazon Linux 2 ARM64 AMI
data "aws_ami" "amazon_linux_arm64" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-arm64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# CloudWatch Log Group (minimal retention)
resource "aws_cloudwatch_log_group" "minimal_main" {
  name              = "/aws/ec2/${var.project_name}-minimal"
  retention_in_days = 3  # Minimal retention for cost savings

  tags = {
    Name = "${var.project_name}-minimal-log-group"
  }
}

# Outputs
output "minimal_alb_dns_name" {
  description = "DNS name of the minimal load balancer"
  value       = aws_lb.minimal_main.dns_name
}

output "minimal_database_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.minimal_main.endpoint
  sensitive   = true
}

output "minimal_redis_endpoint" {
  description = "Redis cluster endpoint"
  value       = aws_elasticache_replication_group.minimal_main.primary_endpoint_address
  sensitive   = true
}

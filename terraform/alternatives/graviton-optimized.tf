# Graviton-optimized configuration for multi-tenant AI platform
# This configuration maximizes cost-performance for AI inference workloads

# Launch Template optimized for Graviton4
resource "aws_launch_template" "graviton_app" {
  name_prefix   = "${var.project_name}-graviton-"
  image_id      = data.aws_ami.amazon_linux_arm64.id
  instance_type = "c7g.2xlarge"  # Graviton4 - best for AI inference workloads
  
  vpc_security_group_ids = [aws_security_group.ec2.id]
  
  # Optimized user data for AI workloads
  user_data = base64encode(templatefile("${path.module}/graviton_user_data.sh", {
    ecr_repo_url = aws_ecr_repository.main.repository_url
    database_url = "postgresql://${var.database_username}:${var.database_password}@${aws_db_instance.main.endpoint}/${var.database_name}"
    redis_url    = "redis://${aws_elasticache_replication_group.main.primary_endpoint_address}:6379"
    aws_region   = var.aws_region
  }))
  
  iam_instance_profile {
    name = aws_iam_instance_profile.app.name
  }
  
  # Graviton-specific optimizations
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
    http_put_response_hop_limit = 2
  }
  
  # Enhanced monitoring for AI workloads
  monitoring {
    enabled = true
  }
  
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-graviton-app"
      Workload = "AI-Inference"
      Architecture = "ARM64"
    }
  }
}

# Auto Scaling Group with Graviton instances
resource "aws_autoscaling_group" "graviton_app" {
  name                = "${var.project_name}-graviton-asg"
  vpc_zone_identifier = aws_subnet.public[*].id
  target_group_arns   = [aws_lb_target_group.main.arn]
  health_check_type   = "ELB"
  health_check_grace_period = 300
  
  # Optimized scaling for AI workloads
  min_size         = 2  # Always have 2 instances for high availability
  max_size         = 10 # Scale up for high demand
  desired_capacity = 3  # Start with 3 instances
  
  launch_template {
    id      = aws_launch_template.graviton_app.id
    version = "$Latest"
  }
  
  # Mixed instance types for cost optimization
  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.graviton_app.id
        version           = "$Latest"
      }
      
      # Instance type preferences for AI workloads
      override {
        instance_type = "c7g.2xlarge"  # Primary: Compute optimized
      }
      override {
        instance_type = "m7g.2xlarge"  # Secondary: General purpose
      }
      override {
        instance_type = "c7g.xlarge"   # Tertiary: Smaller compute
      }
    }
    
    instances_distribution {
      on_demand_base_capacity                  = 2
      on_demand_percentage_above_base_capacity = 50
      spot_allocation_strategy                 = "price-capacity-optimized"
      spot_instance_pools                      = 4
    }
  }
  
  tag {
    key                 = "Name"
    value               = "${var.project_name}-graviton-asg"
    propagate_at_launch = false
  }
}

# Enhanced Auto Scaling Policies for AI workloads
resource "aws_autoscaling_policy" "graviton_scale_up_fast" {
  name                   = "${var.project_name}-graviton-scale-up-fast"
  scaling_adjustment     = 2
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 180  # Shorter cooldown for AI workloads
  autoscaling_group_name = aws_autoscaling_group.graviton_app.name
}

resource "aws_autoscaling_policy" "graviton_scale_up_slow" {
  name                   = "${var.project_name}-graviton-scale-up-slow"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.graviton_app.name
}

resource "aws_autoscaling_policy" "graviton_scale_down" {
  name                   = "${var.project_name}-graviton-scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 600  # Longer cooldown to prevent thrashing
  autoscaling_group_name = aws_autoscaling_group.graviton_app.name
}

# CloudWatch Alarms optimized for AI workloads
resource "aws_cloudwatch_metric_alarm" "graviton_cpu_high" {
  alarm_name          = "${var.project_name}-graviton-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"  # Shorter period for faster response
  statistic           = "Average"
  threshold           = "60"   # Lower threshold for AI workloads
  alarm_description   = "High CPU utilization for AI workloads"
  alarm_actions       = [aws_autoscaling_policy.graviton_scale_up_fast.arn]
  
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.graviton_app.name
  }
}

resource "aws_cloudwatch_metric_alarm" "graviton_cpu_medium" {
  alarm_name          = "${var.project_name}-graviton-cpu-medium"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "40"
  alarm_description   = "Medium CPU utilization for AI workloads"
  alarm_actions       = [aws_autoscaling_policy.graviton_scale_up_slow.arn]
  
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.graviton_app.name
  }
}

resource "aws_cloudwatch_metric_alarm" "graviton_cpu_low" {
  alarm_name          = "${var.project_name}-graviton-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "15"   # Lower threshold for scale-down
  alarm_description   = "Low CPU utilization for AI workloads"
  alarm_actions       = [aws_autoscaling_policy.graviton_scale_down.arn]
  
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.graviton_app.name
  }
}

# Custom metric for AI request latency
resource "aws_cloudwatch_metric_alarm" "graviton_latency_high" {
  alarm_name          = "${var.project_name}-graviton-latency-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ResponseTime"
  namespace           = "Custom/AI"
  period              = "60"
  statistic           = "Average"
  threshold           = "5000"  # 5 seconds
  alarm_description   = "High response time for AI requests"
  alarm_actions       = [aws_autoscaling_policy.graviton_scale_up_fast.arn]
  
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.graviton_app.name
  }
}

# Graviton-optimized RDS instance
resource "aws_db_instance" "graviton_main" {
  identifier = "${var.project_name}-graviton-db"

  engine         = "postgres"
  engine_version = "15.4"
  instance_class = "db.r6g.large"  # Graviton3 RDS instance

  allocated_storage     = 100
  max_allocated_storage = 1000
  storage_type          = "gp3"
  storage_encrypted     = true
  storage_throughput    = 3000  # Optimized for AI workloads

  db_name  = var.database_name
  username = var.database_username
  password = var.database_password

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name

  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"

  # Performance optimizations for AI workloads
  performance_insights_enabled = true
  performance_insights_retention_period = 7
  
  # Enhanced monitoring
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_enhanced_monitoring.arn

  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Name = "${var.project_name}-graviton-database"
    Workload = "AI-Inference"
    Architecture = "ARM64"
  }
}

# Graviton-optimized ElastiCache
resource "aws_elasticache_replication_group" "graviton_main" {
  replication_group_id       = "${var.project_name}-graviton-redis"
  description                = "Graviton Redis cluster for AI caching"
  
  node_type                  = "r7g.large"  # Graviton3 Redis instance
  port                       = 6379
  parameter_group_name       = "default.redis7"
  
  num_cache_clusters         = 3  # Increased for AI workloads
  
  subnet_group_name          = aws_elasticache_subnet_group.main.name
  security_group_ids         = [aws_security_group.redis.id]
  
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  
  # Performance optimizations
  snapshot_retention_limit = 5
  snapshot_window         = "03:00-05:00"
  
  tags = {
    Name = "${var.project_name}-graviton-redis"
    Workload = "AI-Inference"
    Architecture = "ARM64"
  }
}

# Enhanced monitoring IAM role for RDS
resource "aws_iam_role" "rds_enhanced_monitoring" {
  name = "${var.project_name}-rds-enhanced-monitoring"

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

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  role       = aws_iam_role.rds_enhanced_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

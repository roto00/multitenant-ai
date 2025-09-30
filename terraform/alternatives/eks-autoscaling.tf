# EKS Auto-Scaling Configuration for Multi-Tenant AI Platform
# Scales down to zero/minimal instances during low activity

# Note: Cluster Autoscaler will be deployed via Helm chart instead of EKS addon
# as aws-cluster-autoscaler addon is not supported in Kubernetes 1.28

# Node groups with aggressive scaling down
resource "aws_eks_node_group" "shared_general_autoscaling" {
  cluster_name    = aws_eks_cluster.poc_shared.name
  node_group_name = "shared-general-autoscaling"
  node_role_arn   = aws_iam_role.eks_node_group.arn
  subnet_ids      = aws_subnet.shared_private[*].id

  capacity_type  = "ON_DEMAND"
  instance_types = ["t4g.small", "t4g.micro"]

  # Aggressive scaling down configuration
  scaling_config {
    desired_size = 0  # Start with 0 nodes
    max_size     = 5
    min_size     = 0  # Can scale to 0
  }

  update_config {
    max_unavailable = 1
  }

  ami_type       = "AL2_ARM_64"
  disk_size      = 50

  labels = {
    workload-type = "shared-general"
    node-type     = "on-demand"
    autoscaling   = "enabled"
  }

  # Taints to prevent non-essential workloads
  taint {
    key    = "dedicated"
    value  = "shared"
    effect = "NO_SCHEDULE"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_container_registry_read_only,
  ]

  tags = {
    Name = "${var.project_name}-shared-general-autoscaling"
  }
}

# Spot instances for cost optimization
resource "aws_eks_node_group" "shared_spot_autoscaling" {
  cluster_name    = aws_eks_cluster.poc_shared.name
  node_group_name = "shared-spot-autoscaling"
  node_role_arn   = aws_iam_role.eks_node_group.arn
  subnet_ids      = aws_subnet.shared_private[*].id

  capacity_type  = "SPOT"
  instance_types = ["t4g.medium", "t4g.large", "t4g.xlarge"]

  # Aggressive scaling down configuration
  scaling_config {
    desired_size = 0  # Start with 0 nodes
    max_size     = 10
    min_size     = 0  # Can scale to 0
  }

  update_config {
    max_unavailable = 1
  }

  ami_type       = "AL2_ARM_64"
  disk_size      = 50

  labels = {
    workload-type = "shared-spot"
    node-type     = "spot"
    autoscaling   = "enabled"
  }

  # Taints for spot instances
  taint {
    key    = "spot"
    value  = "true"
    effect = "NO_SCHEDULE"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_container_registry_read_only,
  ]

  tags = {
    Name = "${var.project_name}-shared-spot-autoscaling"
  }
}

# GPU nodes with aggressive scaling down
resource "aws_eks_node_group" "shared_gpu_autoscaling" {
  cluster_name    = aws_eks_cluster.poc_shared.name
  node_group_name = "shared-gpu-autoscaling"
  node_role_arn   = aws_iam_role.eks_node_group.arn
  subnet_ids      = aws_subnet.shared_private[*].id

  capacity_type  = "ON_DEMAND"
  instance_types = ["g5.xlarge", "g5.2xlarge"]

  # Aggressive scaling down configuration
  scaling_config {
    desired_size = 0  # Start with 0 nodes
    max_size     = 3
    min_size     = 0  # Can scale to 0
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
    autoscaling   = "enabled"
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
    Name = "${var.project_name}-shared-gpu-autoscaling"
  }
}

# Dedicated node groups for each tenant with auto-scaling
resource "aws_eks_node_group" "tenant_dedicated_autoscaling" {
  count = 2

  cluster_name    = aws_eks_cluster.tenant_dedicated[count.index].name
  node_group_name = "tenant-${count.index + 1}-autoscaling"
  node_role_arn   = aws_iam_role.eks_node_group.arn
  subnet_ids      = [aws_subnet.tenant_dedicated[count.index].id]

  capacity_type  = "ON_DEMAND"
  instance_types = ["t4g.small", "t4g.micro"]

  # Aggressive scaling down configuration
  scaling_config {
    desired_size = 0  # Start with 0 nodes
    max_size     = 3
    min_size     = 0  # Can scale to 0
  }

  update_config {
    max_unavailable = 1
  }

  ami_type       = "AL2_ARM_64"
  disk_size      = 50

  labels = {
    workload-type = "tenant-dedicated"
    node-type     = "on-demand"
    tenant = "tenant-${count.index + 1}"
    autoscaling   = "enabled"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_container_registry_read_only,
  ]

  tags = {
    Name = "${var.project_name}-tenant-${count.index + 1}-autoscaling"
    Tenant = "tenant-${count.index + 1}"
  }
}

# IAM role for Cluster Autoscaler
resource "aws_iam_role" "cluster_autoscaler" {
  name = "${var.project_name}-cluster-autoscaler-role"

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

# IAM policy for Cluster Autoscaler
resource "aws_iam_policy" "cluster_autoscaler" {
  name        = "${var.project_name}-cluster-autoscaler-policy"
  description = "Policy for Cluster Autoscaler"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeScalingActivities",
          "autoscaling:DescribeTags",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplateVersions"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup",
          "ec2:DescribeImages",
          "ec2:GetInstanceTypesFromInstanceRequirements",
          "eks:DescribeNodegroup"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_autoscaler" {
  policy_arn = aws_iam_policy.cluster_autoscaler.arn
  role       = aws_iam_role.cluster_autoscaler.name
}

# Karpenter for advanced auto-scaling (alternative to Cluster Autoscaler)
resource "aws_iam_role" "karpenter_controller" {
  name = "${var.project_name}-karpenter-controller"

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

resource "aws_iam_policy" "karpenter_controller" {
  name        = "${var.project_name}-karpenter-controller-policy"
  description = "Policy for Karpenter controller"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateFleet",
          "ec2:CreateLaunchTemplate",
          "ec2:CreateTags",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeImages",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSpotPriceHistory",
          "ec2:DescribeSubnets",
          "ec2:DeleteLaunchTemplate",
          "ec2:RunInstances",
          "ec2:TerminateInstances",
          "iam:PassRole",
          "pricing:GetProducts",
          "ssm:GetParameter"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "karpenter_controller" {
  policy_arn = aws_iam_policy.karpenter_controller.arn
  role       = aws_iam_role.karpenter_controller.name
}

# Outputs for auto-scaling configuration
output "cluster_autoscaler_role_arn" {
  description = "ARN of the Cluster Autoscaler IAM role"
  value       = aws_iam_role.cluster_autoscaler.arn
}

output "karpenter_controller_role_arn" {
  description = "ARN of the Karpenter controller IAM role"
  value       = aws_iam_role.karpenter_controller.arn
}

output "node_group_scaling_configs" {
  description = "Scaling configurations for all node groups"
  value = {
    shared_general = aws_eks_node_group.shared_general_autoscaling.scaling_config
    shared_spot = aws_eks_node_group.shared_spot_autoscaling.scaling_config
    shared_gpu = aws_eks_node_group.shared_gpu_autoscaling.scaling_config
    tenant_1 = aws_eks_node_group.tenant_dedicated_autoscaling[0].scaling_config
    tenant_2 = aws_eks_node_group.tenant_dedicated_autoscaling[1].scaling_config
  }
}

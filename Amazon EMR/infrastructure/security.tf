# Security Groups and IAM Roles for EMR Cluster

# Security Group for EMR Master Node
resource "aws_security_group" "emr_master_sg" {
  name_prefix = "${local.name_prefix}-emr-master-"
  vpc_id      = aws_vpc.emr_vpc.id

  # SSH access for debugging and management
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "SSH access to EMR master"
  }

  # EMR internal communication
  ingress {
    from_port = 0
    to_port   = 65535
    protocol  = "tcp"
    self      = true
    description = "EMR internal communication"
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-emr-master-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Security Group for EMR Worker Nodes
resource "aws_security_group" "emr_worker_sg" {
  name_prefix = "${local.name_prefix}-emr-worker-"
  vpc_id      = aws_vpc.emr_vpc.id

  # EMR internal communication
  ingress {
    from_port = 0
    to_port   = 65535
    protocol  = "tcp"
    self      = true
    description = "EMR internal communication"
  }

  # Communication with master node
  ingress {
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.emr_master_sg.id]
    description     = "Communication with master node"
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-emr-worker-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# IAM Role for EMR Service
resource "aws_iam_role" "emr_service_role" {
  name = "${local.name_prefix}-emr-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "elasticmapreduce.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

# Attach EMR service role policy
resource "aws_iam_role_policy_attachment" "emr_service_role_policy" {
  role       = aws_iam_role.emr_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEMRServicePolicy_v2"
}

# IAM Role for EMR EC2 Instances
resource "aws_iam_role" "emr_instance_profile_role" {
  name = "${local.name_prefix}-emr-instance-profile-role"

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

  tags = local.common_tags
}

# Attach EMR instance profile policy
resource "aws_iam_role_policy_attachment" "emr_instance_profile_policy" {
  role       = aws_iam_role.emr_instance_profile_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEMRforEC2Role"
}

# Instance Profile for EMR EC2 Instances
resource "aws_iam_instance_profile" "emr_instance_profile" {
  name = "${local.name_prefix}-emr-instance-profile"
  role = aws_iam_role.emr_instance_profile_role.name

  tags = local.common_tags
}

# Custom IAM Policy for S3 Access
resource "aws_iam_role_policy" "emr_s3_policy" {
  name = "${local.name_prefix}-emr-s3-policy"
  role = aws_iam_role.emr_instance_profile_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.emr_data_lake.arn,
          "${aws_s3_bucket.emr_data_lake.arn}/*",
          aws_s3_bucket.emr_logs.arn,
          "${aws_s3_bucket.emr_logs.arn}/*"
        ]
      }
    ]
  })
}

# Custom IAM Policy for CloudWatch Logs
resource "aws_iam_role_policy" "emr_cloudwatch_policy" {
  name = "${local.name_prefix}-emr-cloudwatch-policy"
  role = aws_iam_role.emr_instance_profile_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/emr/*"
      }
    ]
  })
}

# IAM Role for EMR Auto Scaling
resource "aws_iam_role" "emr_autoscaling_role" {
  count = var.enable_auto_scaling ? 1 : 0
  name  = "${local.name_prefix}-emr-autoscaling-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "application-autoscaling.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

# Attach Auto Scaling policy
resource "aws_iam_role_policy_attachment" "emr_autoscaling_policy" {
  count      = var.enable_auto_scaling ? 1 : 0
  role       = aws_iam_role.emr_autoscaling_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEMRAutoScalingRole"
}

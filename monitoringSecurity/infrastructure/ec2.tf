# EC2 Instance to Monitor
resource "aws_instance" "monitored_instance" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public_subnet_1.id
  vpc_security_group_ids = [aws_security_group.monitored_ec2_sg.id]
  
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    log_group_name = aws_cloudwatch_log_group.application_logs.name
  }))

  tags = {
    Name = "monitored-instance"
    Project = "monitoring-security"
    Environment = "monitoring"
  }
}

# Data source for Amazon Linux AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# IAM Role for EC2 instance
resource "aws_iam_role" "ec2_monitoring_role" {
  name = "ec2-monitoring-role"

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

  tags = {
    Name = "ec2-monitoring-role"
    Project = "monitoring-security"
  }
}

# IAM Policy for EC2 monitoring
resource "aws_iam_policy" "ec2_monitoring_policy" {
  name = "ec2-monitoring-policy"

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
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:UpdateInstanceInformation",
          "ssm:SendCommand",
          "ssm:ListCommandInvocations"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach policies to EC2 role
resource "aws_iam_role_policy_attachment" "ec2_ssm_policy" {
  role       = aws_iam_role.ec2_monitoring_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ec2_monitoring_policy_attachment" {
  role       = aws_iam_role.ec2_monitoring_role.name
  policy_arn = aws_iam_policy.ec2_monitoring_policy.arn
}

# Instance Profile
resource "aws_iam_instance_profile" "ec2_monitoring_profile" {
  name = "ec2-monitoring-profile"
  role = aws_iam_role.ec2_monitoring_role.name

  tags = {
    Name = "ec2-monitoring-profile"
    Project = "monitoring-security"
  }
}

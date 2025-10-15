terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Variables
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# VPC Configuration
resource "aws_vpc" "repair_shop_vpc" {
  cidr_block           = "10.3.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "repair-shop-vpc"
    Project = "repair-shop-app"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "repair_shop_igw" {
  vpc_id = aws_vpc.repair_shop_vpc.id

  tags = {
    Name = "repair-shop-igw"
    Project = "repair-shop-app"
  }
}

# Public Subnets
resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.repair_shop_vpc.id
  cidr_block              = "10.3.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "repair-shop-public-subnet-1"
    Project = "repair-shop-app"
    Type = "public"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.repair_shop_vpc.id
  cidr_block              = "10.3.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "repair-shop-public-subnet-2"
    Project = "repair-shop-app"
    Type = "public"
  }
}

# Private Subnets
resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.repair_shop_vpc.id
  cidr_block        = "10.3.3.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "repair-shop-private-subnet-1"
    Project = "repair-shop-app"
    Type = "private"
  }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.repair_shop_vpc.id
  cidr_block        = "10.3.4.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "repair-shop-private-subnet-2"
    Project = "repair-shop-app"
    Type = "private"
  }
}

# Route Table for Public Subnets
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.repair_shop_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.repair_shop_igw.id
  }

  tags = {
    Name = "repair-shop-public-rt"
    Project = "repair-shop-app"
  }
}

# Route Table Associations for Public Subnets
resource "aws_route_table_association" "public_rt_assoc_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_rt_assoc_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# RDS Subnet Group
resource "aws_db_subnet_group" "repair_shop_db_subnet_group" {
  name       = "repair-shop-db-subnet-group"
  subnet_ids = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]

  tags = {
    Name = "repair-shop-db-subnet-group"
    Project = "repair-shop-app"
  }
}

# Security Group for RDS
resource "aws_security_group" "rds_sg" {
  name_prefix = "repair-shop-rds-sg"
  vpc_id      = aws_vpc.repair_shop_vpc.id

  ingress {
    description = "PostgreSQL from Elastic Beanstalk"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.repair_shop_vpc.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "repair-shop-rds-sg"
    Project = "repair-shop-app"
  }
}

# RDS Instance
resource "aws_db_instance" "repair_shop_db" {
  identifier = "repair-shop-db"
  
  engine         = "postgres"
  engine_version = "15.4"
  instance_class = "db.t3.micro"
  
  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp2"
  storage_encrypted     = true
  
  db_name  = "repairshop"
  username = "repairshop_admin"
  password = var.db_password
  
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.repair_shop_db_subnet_group.name
  
  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"
  
  skip_final_snapshot = true
  deletion_protection = false
  
  tags = {
    Name = "repair-shop-db"
    Project = "repair-shop-app"
  }
}

# S3 Bucket for file storage
resource "aws_s3_bucket" "repair_shop_files" {
  bucket = "repair-shop-files-${random_string.bucket_suffix.result}"

  tags = {
    Name = "repair-shop-files"
    Project = "repair-shop-app"
  }
}

resource "aws_s3_bucket_versioning" "repair_shop_files_versioning" {
  bucket = aws_s3_bucket.repair_shop_files.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "repair_shop_files_encryption" {
  bucket = aws_s3_bucket.repair_shop_files.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Random string for bucket suffix
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# IAM Role for Elastic Beanstalk
resource "aws_iam_role" "eb_service_role" {
  name = "repair-shop-eb-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "elasticbeanstalk.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "repair-shop-eb-service-role"
    Project = "repair-shop-app"
  }
}

# Attach Elastic Beanstalk service role policy
resource "aws_iam_role_policy_attachment" "eb_service_role_policy" {
  role       = aws_iam_role.eb_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSElasticBeanstalkService"
}

# IAM Role for EC2 instances
resource "aws_iam_role" "eb_ec2_role" {
  name = "repair-shop-eb-ec2-role"

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
    Name = "repair-shop-eb-ec2-role"
    Project = "repair-shop-app"
  }
}

# IAM Policy for EC2 instances
resource "aws_iam_policy" "eb_ec2_policy" {
  name = "repair-shop-eb-ec2-policy"

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
          aws_s3_bucket.repair_shop_files.arn,
          "${aws_s3_bucket.repair_shop_files.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Attach policies to EC2 role
resource "aws_iam_role_policy_attachment" "eb_ec2_web_tier" {
  role       = aws_iam_role.eb_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWebTier"
}

resource "aws_iam_role_policy_attachment" "eb_ec2_worker_tier" {
  role       = aws_iam_role.eb_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWorkerTier"
}

resource "aws_iam_role_policy_attachment" "eb_ec2_policy_attachment" {
  role       = aws_iam_role.eb_ec2_role.name
  policy_arn = aws_iam_policy.eb_ec2_policy.arn
}

# Instance Profile
resource "aws_iam_instance_profile" "eb_ec2_profile" {
  name = "repair-shop-eb-ec2-profile"
  role = aws_iam_role.eb_ec2_role.name

  tags = {
    Name = "repair-shop-eb-ec2-profile"
    Project = "repair-shop-app"
  }
}

# Elastic Beanstalk Application
resource "aws_elastic_beanstalk_application" "repair_shop_app" {
  name        = "repair-shop-application"
  description = "Repair Shop Management System"

  tags = {
    Name = "repair-shop-application"
    Project = "repair-shop-app"
  }
}

# Elastic Beanstalk Environment
resource "aws_elastic_beanstalk_environment" "repair_shop_env" {
  name                = "repair-shop-environment"
  application         = aws_elastic_beanstalk_application.repair_shop_app.name
  solution_stack_name = "64bit Amazon Linux 2023 v4.3.0 running Node.js 20"

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = aws_iam_instance_profile.eb_ec2_profile.name
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "InstanceType"
    value     = "t3.micro"
  }

  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MinSize"
    value     = "1"
  }

  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MaxSize"
    value     = "3"
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "EnvironmentType"
    value     = "LoadBalanced"
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "LoadBalancerType"
    value     = "application"
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment:process:default"
    name      = "HealthCheckPath"
    value     = "/health"
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment:process:default"
    name      = "Port"
    value     = "8080"
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment:process:default"
    name      = "Protocol"
    value     = "HTTP"
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "NODE_ENV"
    value     = "production"
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "DB_HOST"
    value     = aws_db_instance.repair_shop_db.endpoint
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "DB_NAME"
    value     = aws_db_instance.repair_shop_db.db_name
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "DB_USER"
    value     = aws_db_instance.repair_shop_db.username
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "DB_PASSWORD"
    value     = var.db_password
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "S3_BUCKET"
    value     = aws_s3_bucket.repair_shop_files.bucket
  }

  tags = {
    Name = "repair-shop-environment"
    Project = "repair-shop-app"
  }
}

# Variables
variable "db_password" {
  description = "Password for the RDS instance"
  type        = string
  sensitive   = true
  default     = "RepairShop2024!"
}

# Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.repair_shop_vpc.id
}

output "db_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.repair_shop_db.endpoint
  sensitive   = true
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for file storage"
  value       = aws_s3_bucket.repair_shop_files.bucket
}

output "elastic_beanstalk_url" {
  description = "URL of the Elastic Beanstalk environment"
  value       = aws_elastic_beanstalk_environment.repair_shop_env.endpoint_url
}

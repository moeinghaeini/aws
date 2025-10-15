terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
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

# Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.globalmart_vpc.id
}

output "alb_dns_name" {
  description = "DNS name of the load balancer"
  value       = aws_lb.globalmart_alb.dns_name
}

output "db_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.globalmart_db.endpoint
  sensitive   = true
}

output "codepipeline_name" {
  description = "Name of the CodePipeline"
  value       = aws_codepipeline.globalmart_pipeline.name
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for artifacts"
  value       = aws_s3_bucket.codedeploy_bucket.bucket
}

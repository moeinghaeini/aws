terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
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

provider "aws" {
  alias  = "secondary"
  region = var.secondary_region
}

# Variables
variable "aws_region" {
  description = "Primary AWS region"
  type        = string
  default     = "us-east-1"
}

variable "secondary_region" {
  description = "Secondary AWS region for disaster recovery"
  type        = string
  default     = "us-west-2"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "analytics"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "data-analytics-ml"
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# Local values
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Owner       = "data-team"
  }
  
  name_prefix = "${var.project_name}-${var.environment}"
}

# Outputs
output "vpc_id" {
  description = "ID of the primary VPC"
  value       = aws_vpc.analytics_vpc.id
}

output "kinesis_stream_arn" {
  description = "ARN of the Kinesis data stream"
  value       = aws_kinesis_stream.data_stream.arn
}

output "redshift_cluster_endpoint" {
  description = "Redshift cluster endpoint"
  value       = aws_redshift_cluster.analytics_cluster.endpoint
  sensitive   = true
}

output "sagemaker_endpoint_name" {
  description = "SageMaker endpoint name for ML inference"
  value       = aws_sagemaker_endpoint.ml_endpoint.name
}

output "quicksight_dashboard_url" {
  description = "QuickSight dashboard URL"
  value       = "https://${var.aws_region}.quicksight.aws.amazon.com/sn/dashboards/${aws_quicksight_dashboard.analytics_dashboard.dashboard_id}"
}

output "glue_catalog_database_name" {
  description = "Glue Data Catalog database name"
  value       = aws_glue_catalog_database.analytics_db.name
}

output "athena_workgroup_name" {
  description = "Athena workgroup name"
  value       = aws_athena_workgroup.analytics_workgroup.name
}

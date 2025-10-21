# Amazon EMR Big Data Processing Platform
# Infrastructure as Code using Terraform

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

# Local values for consistent naming
locals {
  name_prefix = "emr-bigdata"
  common_tags = {
    Project     = "Amazon EMR Big Data Platform"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = "Data Engineering Team"
  }
}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}

# Random string for unique resource naming
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

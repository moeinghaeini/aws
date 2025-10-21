# Variables for Amazon EMR Big Data Platform

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "emr_release_label" {
  description = "EMR release label"
  type        = string
  default     = "emr-6.15.0"
}

variable "emr_applications" {
  description = "List of applications to install on EMR cluster"
  type        = list(string)
  default     = ["Spark", "Hadoop", "Hive", "Pig", "Hue", "Livy", "JupyterHub"]
}

variable "master_instance_type" {
  description = "EC2 instance type for EMR master node"
  type        = string
  default     = "m5.xlarge"
}

variable "worker_instance_type" {
  description = "EC2 instance type for EMR worker nodes"
  type        = string
  default     = "m5.large"
}

variable "worker_instance_count" {
  description = "Number of worker instances"
  type        = number
  default     = 2
}

variable "enable_spot_instances" {
  description = "Enable spot instances for cost optimization"
  type        = bool
  default     = true
}

variable "spot_bid_price" {
  description = "Bid price for spot instances (as percentage of on-demand price)"
  type        = number
  default     = 0.5
}

variable "enable_auto_scaling" {
  description = "Enable EMR managed auto-scaling"
  type        = bool
  default     = true
}

variable "min_capacity" {
  description = "Minimum number of worker instances for auto-scaling"
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Maximum number of worker instances for auto-scaling"
  type        = number
  default     = 10
}

variable "enable_encryption" {
  description = "Enable encryption for S3 buckets and EMR logs"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Number of days to retain EMR logs in S3"
  type        = number
  default     = 30
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access EMR cluster"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Restrict this in production
}

variable "enable_monitoring" {
  description = "Enable detailed monitoring for EMR cluster"
  type        = bool
  default     = true
}

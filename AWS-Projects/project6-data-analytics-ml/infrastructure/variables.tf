# Variables for Data Analytics ML Platform

variable "aws_region" {
  description = "Primary AWS region for the analytics platform"
  type        = string
  default     = "us-east-1"
}

variable "secondary_region" {
  description = "Secondary AWS region for disaster recovery"
  type        = string
  default     = "us-west-2"
}

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
  default     = "analytics"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "data-analytics-ml"
}

variable "redshift_password" {
  description = "Password for Redshift cluster master user"
  type        = string
  sensitive   = true
  default     = "AnalyticsPassword123!"
}

variable "alert_email" {
  description = "Email address for CloudWatch alerts"
  type        = string
  default     = "admin@example.com"
}

variable "kinesis_shard_count" {
  description = "Number of shards for Kinesis data stream"
  type        = number
  default     = 2
}

variable "redshift_node_type" {
  description = "Redshift cluster node type"
  type        = string
  default     = "dc2.large"
}

variable "sagemaker_instance_type" {
  description = "SageMaker endpoint instance type"
  type        = string
  default     = "ml.t2.medium"
}

variable "lambda_timeout" {
  description = "Timeout for Lambda functions in seconds"
  type        = number
  default     = 300
}

variable "enable_xray_tracing" {
  description = "Enable X-Ray tracing for Lambda functions"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 14
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 7
}

variable "enable_encryption" {
  description = "Enable encryption for all resources"
  type        = bool
  default     = true
}

variable "enable_monitoring" {
  description = "Enable detailed monitoring and alerting"
  type        = bool
  default     = true
}

variable "enable_auto_scaling" {
  description = "Enable auto-scaling for compute resources"
  type        = bool
  default     = true
}

variable "data_retention_days" {
  description = "Number of days to retain data in S3"
  type        = number
  default     = 90
}

variable "ml_model_version" {
  description = "Version of the ML model to deploy"
  type        = string
  default     = "1.0"
}

variable "cost_budget_limit" {
  description = "Monthly cost budget limit in USD"
  type        = number
  default     = 1000
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

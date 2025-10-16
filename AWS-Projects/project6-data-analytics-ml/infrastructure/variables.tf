# Variables for Data Analytics ML Platform

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

variable "redshift_password" {
  description = "Password for Redshift cluster"
  type        = string
  sensitive   = true
  default     = "AnalyticsPassword123!"
}

variable "alert_email" {
  description = "Email address for alerts and notifications"
  type        = string
  default     = "admin@example.com"
}

variable "kinesis_shard_count" {
  description = "Number of shards for Kinesis stream"
  type        = number
  default     = 2
}

variable "redshift_node_type" {
  description = "Node type for Redshift cluster"
  type        = string
  default     = "dc2.large"
}

variable "sagemaker_instance_type" {
  description = "Instance type for SageMaker endpoint"
  type        = string
  default     = "ml.t2.medium"
}

variable "lambda_timeout" {
  description = "Timeout for Lambda functions in seconds"
  type        = number
  default     = 300
}

variable "enable_xray_tracing" {
  description = "Enable X-Ray tracing"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Log retention period in days"
  type        = number
  default     = 14
}

variable "backup_retention_days" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "enable_encryption" {
  description = "Enable encryption for all resources"
  type        = bool
  default     = true
}

variable "enable_monitoring" {
  description = "Enable comprehensive monitoring"
  type        = bool
  default     = true
}

variable "enable_auto_scaling" {
  description = "Enable auto-scaling for resources"
  type        = bool
  default     = true
}

variable "data_retention_days" {
  description = "Data retention period in days"
  type        = number
  default     = 90
}

variable "ml_model_version" {
  description = "Version of the ML model"
  type        = string
  default     = "1.0"
}

variable "cost_budget_limit" {
  description = "Monthly cost budget limit in USD"
  type        = number
  default     = 1000
}

variable "admin_ip_addresses" {
  description = "List of admin IP addresses for WAF"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_api_gateway" {
  description = "Enable API Gateway for ML inference"
  type        = bool
  default     = false
}

variable "enable_waf" {
  description = "Enable AWS WAF for enhanced security"
  type        = bool
  default     = true
}

variable "enable_data_lineage" {
  description = "Enable data lineage tracking"
  type        = bool
  default     = true
}

variable "enable_performance_monitoring" {
  description = "Enable advanced performance monitoring"
  type        = bool
  default     = true
}

variable "enable_cost_optimization" {
  description = "Enable automated cost optimization"
  type        = bool
  default     = true
}

variable "performance_sla_thresholds" {
  description = "Performance SLA thresholds"
  type = object({
    kinesis_iterator_age_ms = number
    lambda_duration_ms      = number
    redshift_cpu_percent    = number
    sagemaker_latency_ms    = number
  })
  default = {
    kinesis_iterator_age_ms = 1000
    lambda_duration_ms      = 5000
    redshift_cpu_percent    = 80
    sagemaker_latency_ms    = 200
  }
}

variable "cost_optimization_thresholds" {
  description = "Cost optimization thresholds"
  type = object({
    kinesis_utilization_percent = number
    redshift_cpu_percent        = number
    sagemaker_utilization_percent = number
    lambda_memory_mb            = number
  })
  default = {
    kinesis_utilization_percent = 30
    redshift_cpu_percent        = 30
    sagemaker_utilization_percent = 10
    lambda_memory_mb            = 512
  }
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "enable_multi_az" {
  description = "Enable multi-AZ deployment"
  type        = bool
  default     = true
}

variable "enable_cross_region_replication" {
  description = "Enable cross-region replication for disaster recovery"
  type        = bool
  default     = true
}

variable "enable_automated_backups" {
  description = "Enable automated backups"
  type        = bool
  default     = true
}

variable "backup_schedule" {
  description = "Backup schedule expression"
  type        = string
  default     = "cron(0 2 * * ? *)"  # Daily at 2 AM
}

variable "enable_encryption_at_rest" {
  description = "Enable encryption at rest"
  type        = bool
  default     = true
}

variable "enable_encryption_in_transit" {
  description = "Enable encryption in transit"
  type        = bool
  default     = true
}

variable "enable_audit_logging" {
  description = "Enable comprehensive audit logging"
  type        = bool
  default     = true
}

variable "enable_security_monitoring" {
  description = "Enable security monitoring and alerting"
  type        = bool
  default     = true
}

variable "enable_compliance_monitoring" {
  description = "Enable compliance monitoring"
  type        = bool
  default     = true
}

variable "enable_anomaly_detection" {
  description = "Enable anomaly detection"
  type        = bool
  default     = true
}

variable "enable_auto_remediation" {
  description = "Enable automated remediation"
  type        = bool
  default     = true
}

variable "enable_performance_testing" {
  description = "Enable automated performance testing"
  type        = bool
  default     = true
}

variable "enable_load_testing" {
  description = "Enable automated load testing"
  type        = bool
  default     = true
}

variable "enable_stress_testing" {
  description = "Enable automated stress testing"
  type        = bool
  default     = true
}

variable "enable_chaos_engineering" {
  description = "Enable chaos engineering tests"
  type        = bool
  default     = false
}

variable "enable_canary_deployments" {
  description = "Enable canary deployments"
  type        = bool
  default     = false
}

variable "enable_blue_green_deployments" {
  description = "Enable blue-green deployments"
  type        = bool
  default     = false
}

variable "enable_rolling_deployments" {
  description = "Enable rolling deployments"
  type        = bool
  default     = true
}

variable "deployment_strategy" {
  description = "Deployment strategy"
  type        = string
  default     = "rolling"
  validation {
    condition     = contains(["rolling", "blue_green", "canary"], var.deployment_strategy)
    error_message = "Deployment strategy must be one of: rolling, blue_green, canary."
  }
}

variable "enable_health_checks" {
  description = "Enable health checks"
  type        = bool
  default     = true
}

variable "health_check_interval" {
  description = "Health check interval in seconds"
  type        = number
  default     = 30
}

variable "health_check_timeout" {
  description = "Health check timeout in seconds"
  type        = number
  default     = 5
}

variable "health_check_healthy_threshold" {
  description = "Number of consecutive health checks to consider healthy"
  type        = number
  default     = 2
}

variable "health_check_unhealthy_threshold" {
  description = "Number of consecutive health checks to consider unhealthy"
  type        = number
  default     = 3
}

variable "enable_auto_healing" {
  description = "Enable auto-healing capabilities"
  type        = bool
  default     = true
}

variable "enable_circuit_breaker" {
  description = "Enable circuit breaker pattern"
  type        = bool
  default     = true
}

variable "enable_retry_logic" {
  description = "Enable retry logic with exponential backoff"
  type        = bool
  default     = true
}

variable "max_retry_attempts" {
  description = "Maximum number of retry attempts"
  type        = number
  default     = 3
}

variable "retry_delay_seconds" {
  description = "Initial retry delay in seconds"
  type        = number
  default     = 1
}

variable "enable_dead_letter_queues" {
  description = "Enable dead letter queues for failed messages"
  type        = bool
  default     = true
}

variable "enable_message_deduplication" {
  description = "Enable message deduplication"
  type        = bool
  default     = true
}

variable "enable_message_ordering" {
  description = "Enable message ordering"
  type        = bool
  default     = true
}

variable "enable_message_filtering" {
  description = "Enable message filtering"
  type        = bool
  default     = true
}

variable "enable_message_routing" {
  description = "Enable message routing"
  type        = bool
  default     = true
}

variable "enable_message_transformation" {
  description = "Enable message transformation"
  type        = bool
  default     = true
}

variable "enable_message_validation" {
  description = "Enable message validation"
  type        = bool
  default     = true
}

variable "enable_message_encryption" {
  description = "Enable message encryption"
  type        = bool
  default     = true
}

variable "enable_message_compression" {
  description = "Enable message compression"
  type        = bool
  default     = true
}

variable "enable_message_batching" {
  description = "Enable message batching"
  type        = bool
  default     = true
}

variable "batch_size" {
  description = "Batch size for message processing"
  type        = number
  default     = 10
}

variable "batch_timeout_seconds" {
  description = "Batch timeout in seconds"
  type        = number
  default     = 5
}

variable "enable_parallel_processing" {
  description = "Enable parallel processing"
  type        = bool
  default     = true
}

variable "max_concurrent_executions" {
  description = "Maximum number of concurrent executions"
  type        = number
  default     = 100
}

variable "enable_resource_pooling" {
  description = "Enable resource pooling"
  type        = bool
  default     = true
}

variable "enable_connection_pooling" {
  description = "Enable connection pooling"
  type        = bool
  default     = true
}

variable "enable_caching" {
  description = "Enable caching"
  type        = bool
  default     = true
}

variable "cache_ttl_seconds" {
  description = "Cache TTL in seconds"
  type        = number
  default     = 3600
}

variable "enable_distributed_caching" {
  description = "Enable distributed caching"
  type        = bool
  default     = true
}

variable "enable_cache_invalidation" {
  description = "Enable cache invalidation"
  type        = bool
  default     = true
}

variable "enable_cache_warming" {
  description = "Enable cache warming"
  type        = bool
  default     = true
}

variable "enable_cache_compression" {
  description = "Enable cache compression"
  type        = bool
  default     = true
}

variable "enable_cache_encryption" {
  description = "Enable cache encryption"
  type        = bool
  default     = true
}

variable "enable_cache_monitoring" {
  description = "Enable cache monitoring"
  type        = bool
  default     = true
}

variable "enable_cache_analytics" {
  description = "Enable cache analytics"
  type        = bool
  default     = true
}

variable "enable_cache_optimization" {
  description = "Enable cache optimization"
  type        = bool
  default     = true
}

variable "enable_cache_preloading" {
  description = "Enable cache preloading"
  type        = bool
  default     = true
}

variable "enable_cache_partitioning" {
  description = "Enable cache partitioning"
  type        = bool
  default     = true
}

variable "enable_cache_replication" {
  description = "Enable cache replication"
  type        = bool
  default     = true
}

variable "enable_cache_failover" {
  description = "Enable cache failover"
  type        = bool
  default     = true
}

variable "enable_cache_backup" {
  description = "Enable cache backup"
  type        = bool
  default     = true
}

variable "enable_cache_restore" {
  description = "Enable cache restore"
  type        = bool
  default     = true
}

variable "enable_cache_migration" {
  description = "Enable cache migration"
  type        = bool
  default     = true
}

variable "enable_cache_scaling" {
  description = "Enable cache scaling"
  type        = bool
  default     = true
}

variable "enable_cache_monitoring" {
  description = "Enable cache monitoring"
  type        = bool
  default     = true
}

variable "enable_cache_alerting" {
  description = "Enable cache alerting"
  type        = bool
  default     = true
}

variable "enable_cache_reporting" {
  description = "Enable cache reporting"
  type        = bool
  default     = true
}

variable "enable_cache_dashboard" {
  description = "Enable cache dashboard"
  type        = bool
  default     = true
}

variable "enable_cache_api" {
  description = "Enable cache API"
  type        = bool
  default     = true
}

variable "enable_cache_cli" {
  description = "Enable cache CLI"
  type        = bool
  default     = true
}

variable "enable_cache_sdk" {
  description = "Enable cache SDK"
  type        = bool
  default     = true
}

variable "enable_cache_webhook" {
  description = "Enable cache webhook"
  type        = bool
  default     = true
}

variable "enable_cache_event" {
  description = "Enable cache event"
  type        = bool
  default     = true
}

variable "enable_cache_stream" {
  description = "Enable cache stream"
  type        = bool
  default     = true
}

variable "enable_cache_queue" {
  description = "Enable cache queue"
  type        = bool
  default     = true
}

variable "enable_cache_topic" {
  description = "Enable cache topic"
  type        = bool
  default     = true
}

variable "enable_cache_subscription" {
  description = "Enable cache subscription"
  type        = bool
  default     = true
}

variable "enable_cache_notification" {
  description = "Enable cache notification"
  type        = bool
  default     = true
}

variable "enable_cache_trigger" {
  description = "Enable cache trigger"
  type        = bool
  default     = true
}

variable "enable_cache_schedule" {
  description = "Enable cache schedule"
  type        = bool
  default     = true
}

variable "enable_cache_cron" {
  description = "Enable cache cron"
  type        = bool
  default     = true
}

variable "enable_cache_interval" {
  description = "Enable cache interval"
  type        = bool
  default     = true
}

variable "enable_cache_delay" {
  description = "Enable cache delay"
  type        = bool
  default     = true
}

variable "enable_cache_timeout" {
  description = "Enable cache timeout"
  type        = bool
  default     = true
}

variable "enable_cache_retry" {
  description = "Enable cache retry"
  type        = bool
  default     = true
}

variable "enable_cache_fallback" {
  description = "Enable cache fallback"
  type        = bool
  default     = true
}

variable "enable_cache_circuit_breaker" {
  description = "Enable cache circuit breaker"
  type        = bool
  default     = true
}

variable "enable_cache_bulkhead" {
  description = "Enable cache bulkhead"
  type        = bool
  default     = true
}

variable "enable_cache_timeout" {
  description = "Enable cache timeout"
  type        = bool
  default     = true
}

variable "enable_cache_retry" {
  description = "Enable cache retry"
  type        = bool
  default     = true
}

variable "enable_cache_fallback" {
  description = "Enable cache fallback"
  type        = bool
  default     = true
}

variable "enable_cache_circuit_breaker" {
  description = "Enable cache circuit breaker"
  type        = bool
  default     = true
}

variable "enable_cache_bulkhead" {
  description = "Enable cache bulkhead"
  type        = bool
  default     = true
}
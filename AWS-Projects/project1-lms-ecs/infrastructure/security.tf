# Advanced Security Configuration for LMS ECS Project

# AWS WAF Web ACL for Application Load Balancer
resource "aws_wafv2_web_acl" "lms_waf" {
  name  = "lms-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  # Rate limiting rule
  rule {
    name     = "RateLimitRule"
    priority = 1

    override_action {
      none {}
    }

    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitRule"
      sampled_requests_enabled   = true
    }
  }

  # SQL injection protection
  rule {
    name     = "SQLInjectionRule"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "SQLInjectionRule"
      sampled_requests_enabled   = true
    }
  }

  # XSS protection
  rule {
    name     = "XSSRule"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "XSSRule"
      sampled_requests_enabled   = true
    }
  }

  # IP reputation list
  rule {
    name     = "IPReputationRule"
    priority = 4

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "IPReputationRule"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "LMSWAF"
    sampled_requests_enabled   = true
  }

  tags = {
    Name    = "lms-waf"
    Project = "lms-ecs"
  }
}

# Associate WAF with Application Load Balancer
resource "aws_wafv2_web_acl_association" "lms_waf_association" {
  resource_arn = aws_lb.lms_alb.arn
  web_acl_arn  = aws_wafv2_web_acl.lms_waf.arn
}

# AWS Secrets Manager for database credentials
resource "aws_secretsmanager_secret" "lms_db_credentials" {
  name                    = "lms/database/credentials"
  description             = "Database credentials for LMS application"
  recovery_window_in_days = 7

  tags = {
    Name    = "lms-db-credentials"
    Project = "lms-ecs"
  }
}

resource "aws_secretsmanager_secret_version" "lms_db_credentials" {
  secret_id = aws_secretsmanager_secret.lms_db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    host     = aws_db_instance.lms_db.endpoint
    port     = 5432
    database = var.db_name
  })
}

# AWS KMS Key for encryption
resource "aws_kms_key" "lms_encryption_key" {
  description             = "KMS key for LMS application encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name    = "lms-encryption-key"
    Project = "lms-ecs"
  }
}

resource "aws_kms_alias" "lms_encryption_key_alias" {
  name          = "alias/lms-encryption-key"
  target_key_id = aws_kms_key.lms_encryption_key.key_id
}

# Enhanced IAM Role for ECS Task with least privilege
resource "aws_iam_role" "lms_ecs_task_role" {
  name = "lms-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name    = "lms-ecs-task-role"
    Project = "lms-ecs"
  }
}

# IAM Policy for Secrets Manager access
resource "aws_iam_policy" "lms_secrets_policy" {
  name        = "lms-secrets-policy"
  description = "Policy for accessing Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.lms_db_credentials.arn
      }
    ]
  })
}

# IAM Policy for KMS access
resource "aws_iam_policy" "lms_kms_policy" {
  name        = "lms-kms-policy"
  description = "Policy for KMS encryption/decryption"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.lms_encryption_key.arn
      }
    ]
  })
}

# Attach policies to ECS task role
resource "aws_iam_role_policy_attachment" "lms_ecs_task_secrets" {
  role       = aws_iam_role.lms_ecs_task_role.name
  policy_arn = aws_iam_policy.lms_secrets_policy.arn
}

resource "aws_iam_role_policy_attachment" "lms_ecs_task_kms" {
  role       = aws_iam_role.lms_ecs_task_role.name
  policy_arn = aws_iam_policy.lms_kms_policy.arn
}

# CloudTrail for audit logging
resource "aws_cloudtrail" "lms_audit_trail" {
  name                          = "lms-audit-trail"
  s3_bucket_name                = aws_s3_bucket.lms_audit_logs.bucket
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_logging                = true

  event_selector {
    read_write_type                 = "All"
    include_management_events       = true
    data_resource {
      type   = "AWS::S3::Object"
      values = ["${aws_s3_bucket.lms_audit_logs.arn}/*"]
    }
  }

  tags = {
    Name    = "lms-audit-trail"
    Project = "lms-ecs"
  }
}

# S3 bucket for CloudTrail logs
resource "aws_s3_bucket" "lms_audit_logs" {
  bucket        = "lms-audit-logs-${random_string.bucket_suffix.result}"
  force_destroy = true

  tags = {
    Name    = "lms-audit-logs"
    Project = "lms-ecs"
  }
}

resource "aws_s3_bucket_versioning" "lms_audit_logs_versioning" {
  bucket = aws_s3_bucket.lms_audit_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "lms_audit_logs_encryption" {
  bucket = aws_s3_bucket.lms_audit_logs.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.lms_encryption_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "lms_audit_logs_pab" {
  bucket = aws_s3_bucket.lms_audit_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# AWS Config for compliance monitoring
resource "aws_config_configuration_recorder" "lms_config_recorder" {
  name     = "lms-config-recorder"
  role_arn = aws_iam_role.lms_config_role.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_iam_role" "lms_config_role" {
  name = "lms-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lms_config_policy" {
  role       = aws_iam_role.lms_config_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/ConfigRole"
}

# Security Hub for centralized security findings
resource "aws_securityhub_account" "lms_security_hub" {
  enable_default_standards = true
}

# GuardDuty for threat detection
resource "aws_guardduty_detector" "lms_guardduty" {
  enable = true

  datasources {
    s3_logs {
      enable = true
    }
    kubernetes {
      audit_logs {
        enable = true
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = true
        }
      }
    }
  }

  tags = {
    Name    = "lms-guardduty"
    Project = "lms-ecs"
  }
}

# Random string for bucket suffix
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}
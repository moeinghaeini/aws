# Disaster Recovery and Backup Configuration

# RDS Automated Backups and Point-in-Time Recovery
resource "aws_db_instance" "lms_db" {
  identifier = "lms-database"

  engine         = "postgres"
  engine_version = "15.4"
  instance_class = "db.t3.micro"

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id           = aws_kms_key.lms_encryption_key.arn

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.lms_db_subnet_group.name

  # Backup Configuration
  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"
  
  # Point-in-Time Recovery
  point_in_time_recovery_enabled = true
  
  # Multi-AZ for high availability
  multi_az = true
  
  # Deletion protection
  deletion_protection = true
  skip_final_snapshot = false
  final_snapshot_identifier = "lms-db-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  # Performance Insights
  performance_insights_enabled = true
  performance_insights_retention_period = 7

  tags = {
    Name    = "lms-database"
    Project = "lms-ecs"
  }
}

# RDS Read Replica for disaster recovery
resource "aws_db_instance" "lms_db_replica" {
  identifier = "lms-database-replica"

  # Source database
  replicate_source_db = aws_db_instance.lms_db.identifier

  instance_class = "db.t3.micro"
  
  # Different availability zone
  availability_zone = data.aws_availability_zones.available.names[1]

  # Backup configuration for replica
  backup_retention_period = 0
  skip_final_snapshot    = true

  tags = {
    Name    = "lms-database-replica"
    Project = "lms-ecs"
  }
}

# Cross-Region RDS Snapshot for disaster recovery
resource "aws_db_snapshot" "lms_db_snapshot" {
  db_instance_identifier = aws_db_instance.lms_db.id
  db_snapshot_identifier = "lms-db-snapshot-${formatdate("YYYY-MM-DD", timestamp())}"

  tags = {
    Name    = "lms-db-snapshot"
    Project = "lms-ecs"
  }
}

# Lambda function for automated cross-region backup
resource "aws_lambda_function" "cross_region_backup" {
  filename         = "lambda_functions/cross_region_backup.zip"
  function_name    = "lms-cross-region-backup"
  role            = aws_iam_role.lambda_backup_role.arn
  handler         = "cross_region_backup.lambda_handler"
  runtime         = "python3.11"
  timeout         = 300

  environment {
    variables = {
      SOURCE_REGION = var.aws_region
      TARGET_REGION = var.dr_region
      DB_INSTANCE_IDENTIFIER = aws_db_instance.lms_db.id
    }
  }

  tags = {
    Name    = "lms-cross-region-backup"
    Project = "lms-ecs"
  }
}

# IAM Role for Lambda backup function
resource "aws_iam_role" "lambda_backup_role" {
  name = "lms-lambda-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_backup_policy" {
  name        = "lms-lambda-backup-policy"
  description = "Policy for Lambda backup function"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rds:CreateDBSnapshot",
          "rds:DescribeDBSnapshots",
          "rds:CopyDBSnapshot",
          "rds:DescribeDBInstances",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_backup_policy_attachment" {
  role       = aws_iam_role.lambda_backup_role.name
  policy_arn = aws_iam_policy.lambda_backup_policy.arn
}

# EventBridge rule for scheduled backups
resource "aws_cloudwatch_event_rule" "daily_backup" {
  name                = "lms-daily-backup"
  description         = "Trigger daily cross-region backup"
  schedule_expression = "cron(0 2 * * ? *)"  # Daily at 2 AM UTC
}

resource "aws_cloudwatch_event_target" "lambda_backup_target" {
  rule      = aws_cloudwatch_event_rule.daily_backup.name
  target_id = "LambdaBackupTarget"
  arn       = aws_lambda_function.cross_region_backup.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cross_region_backup.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_backup.arn
}

# S3 Cross-Region Replication for application data
resource "aws_s3_bucket" "lms_app_data" {
  bucket = "lms-app-data-${random_string.bucket_suffix.result}"

  tags = {
    Name    = "lms-app-data"
    Project = "lms-ecs"
  }
}

resource "aws_s3_bucket_versioning" "lms_app_data_versioning" {
  bucket = aws_s3_bucket.lms_app_data.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_replication_configuration" "lms_app_data_replication" {
  bucket = aws_s3_bucket.lms_app_data.id
  role   = aws_iam_role.s3_replication_role.arn

  rule {
    id     = "lms-app-data-replication"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.lms_app_data_dr.arn
      storage_class = "STANDARD_IA"
    }
  }
}

# IAM Role for S3 replication
resource "aws_iam_role" "s3_replication_role" {
  name = "lms-s3-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "s3_replication_policy" {
  name        = "lms-s3-replication-policy"
  description = "Policy for S3 cross-region replication"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ]
        Resource = "${aws_s3_bucket.lms_app_data.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]
        Resource = "${aws_s3_bucket.lms_app_data_dr.arn}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "s3_replication_policy_attachment" {
  role       = aws_iam_role.s3_replication_role.name
  policy_arn = aws_iam_policy.s3_replication_policy.arn
}

# Disaster Recovery S3 bucket in different region
resource "aws_s3_bucket" "lms_app_data_dr" {
  provider = aws.dr_region
  bucket   = "lms-app-data-dr-${random_string.bucket_suffix.result}"

  tags = {
    Name    = "lms-app-data-dr"
    Project = "lms-ecs"
  }
}

# ECS Service Auto Scaling for high availability
resource "aws_appautoscaling_target" "lms_ecs_target" {
  max_capacity       = 10
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.lms_cluster.name}/${aws_ecs_service.lms_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "lms_ecs_scale_up" {
  name               = "lms-ecs-scale-up"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.lms_ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.lms_ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.lms_ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

resource "aws_appautoscaling_policy" "lms_ecs_scale_down" {
  name               = "lms-ecs-scale-down"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.lms_ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.lms_ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.lms_ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value = 80.0
  }
}

# Route 53 Health Checks for disaster recovery
resource "aws_route53_health_check" "lms_health_check" {
  fqdn                            = aws_lb.lms_alb.dns_name
  port                            = 80
  type                            = "HTTP"
  resource_path                   = "/health"
  failure_threshold               = "3"
  request_interval                = "30"
  cloudwatch_alarm_region         = var.aws_region
  cloudwatch_alarm_name           = aws_cloudwatch_metric_alarm.lms_5xx_errors.alarm_name
  insufficient_data_health_status = "LastKnownStatus"

  tags = {
    Name    = "lms-health-check"
    Project = "lms-ecs"
  }
}

# Variables
variable "dr_region" {
  description = "Disaster recovery region"
  type        = string
  default     = "us-west-2"
}

# Provider for disaster recovery region
provider "aws" {
  alias  = "dr_region"
  region = var.dr_region
}

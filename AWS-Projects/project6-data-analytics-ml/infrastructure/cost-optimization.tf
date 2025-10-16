# Advanced Cost Optimization Infrastructure
resource "aws_cloudwatch_dashboard" "cost_optimization_dashboard" {
  dashboard_name = "${local.name_prefix}-cost-optimization-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/Billing", "EstimatedCharges", "Currency", "USD"],
            [".", "EstimatedCharges", "ServiceName", "AmazonKinesis"],
            [".", "EstimatedCharges", "ServiceName", "AmazonRedshift"],
            [".", "EstimatedCharges", "ServiceName", "AmazonSageMaker"],
            [".", "EstimatedCharges", "ServiceName", "AWSLambda"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Service Cost Breakdown"
          period  = 86400
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/Kinesis", "IncomingRecords", "StreamName", aws_kinesis_stream.data_stream.name],
            [".", "WriteProvisionedThroughputExceeded", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Kinesis Cost Optimization Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/Redshift", "CPUUtilization", "ClusterIdentifier", aws_redshift_cluster.analytics_cluster.cluster_identifier],
            [".", "DatabaseConnections", ".", "."],
            [".", "FreeStorageSpace", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Redshift Cost Optimization Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 18
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/SageMaker", "ModelLatency", "EndpointName", aws_sagemaker_endpoint.ml_endpoint.name],
            [".", "InvocationsPerInstance", ".", "."],
            [".", "Invocation4XXErrors", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "SageMaker Cost Optimization Metrics"
          period  = 300
        }
      }
    ]
  })

  tags = local.common_tags
}

# Cost Optimization Lambda Function
resource "aws_lambda_function" "cost_optimizer" {
  filename         = "cost_optimizer.zip"
  function_name    = "${local.name_prefix}-cost-optimizer"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "cost_optimizer.lambda_handler"
  source_code_hash = data.archive_file.cost_optimizer_zip.output_base64sha256
  runtime         = "python3.11"
  timeout         = 900
  memory_size     = 512

  environment {
    variables = {
      KINESIS_STREAM = aws_kinesis_stream.data_stream.name
      REDSHIFT_CLUSTER = aws_redshift_cluster.analytics_cluster.cluster_identifier
      SAGEMAKER_ENDPOINT = aws_sagemaker_endpoint.ml_endpoint.name
      S3_BUCKET = aws_s3_bucket.data_lake.bucket
    }
  }

  tags = local.common_tags
}

# Cost Optimizer Source Code
data "archive_file" "cost_optimizer_zip" {
  type        = "zip"
  output_path = "cost_optimizer.zip"
  source {
    content = templatefile("${path.module}/lambda_functions/cost_optimizer.py", {
      kinesis_stream = aws_kinesis_stream.data_stream.name
    })
    filename = "cost_optimizer.py"
  }
}

# Scheduled Cost Optimization
resource "aws_cloudwatch_event_rule" "cost_optimization_schedule" {
  name                = "${local.name_prefix}-cost-optimization-schedule"
  description         = "Trigger cost optimization analysis on schedule"
  schedule_expression = "rate(1 day)"

  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "cost_optimizer_lambda" {
  rule      = aws_cloudwatch_event_rule.cost_optimization_schedule.name
  target_id = "CostOptimizerLambdaTarget"
  arn       = aws_lambda_function.cost_optimizer.arn
}

resource "aws_lambda_permission" "allow_eventbridge_cost_optimizer" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cost_optimizer.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.cost_optimization_schedule.arn
}

# Cost Anomaly Detection
resource "aws_ce_anomaly_detector" "cost_anomaly_detector" {
  name = "${local.name_prefix}-cost-anomaly-detector"

  specification = jsonencode({
    "AnomalyDetectorType" = "DIMENSIONAL"
    "Dimension"           = "SERVICE"
  })

  monitor_type = "DIMENSIONAL"

  tags = local.common_tags
}

# Cost Budget
resource "aws_budgets_budget" "analytics_budget" {
  name         = "${local.name_prefix}-analytics-budget"
  budget_type  = "COST"
  limit_amount = var.cost_budget_limit
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_filters = {
    Service = [
      "Amazon Kinesis",
      "Amazon Redshift",
      "Amazon SageMaker",
      "AWS Lambda",
      "Amazon S3"
    ]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                 = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                 = 100
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }

  tags = local.common_tags
}

# Cost Optimization Alarms
resource "aws_cloudwatch_metric_alarm" "cost_anomaly_alarm" {
  alarm_name          = "${local.name_prefix}-cost-anomaly"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "AnomalyScore"
  namespace           = "AWS/CostAnomalyDetection"
  period              = "86400"
  statistic           = "Average"
  threshold           = "0.8"
  alarm_description   = "Cost anomaly detected"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    AnomalyDetectorArn = aws_ce_anomaly_detector.cost_anomaly_detector.arn
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "kinesis_cost_alarm" {
  alarm_name          = "${local.name_prefix}-kinesis-cost"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = "86400"
  statistic           = "Average"
  threshold           = "50"
  alarm_description   = "Kinesis costs exceed threshold"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ServiceName = "AmazonKinesis"
    Currency    = "USD"
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "redshift_cost_alarm" {
  alarm_name          = "${local.name_prefix}-redshift-cost"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = "86400"
  statistic           = "Average"
  threshold           = "200"
  alarm_description   = "Redshift costs exceed threshold"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ServiceName = "AmazonRedshift"
    Currency    = "USD"
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "sagemaker_cost_alarm" {
  alarm_name          = "${local.name_prefix}-sagemaker-cost"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = "86400"
  statistic           = "Average"
  threshold           = "100"
  alarm_description   = "SageMaker costs exceed threshold"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ServiceName = "AmazonSageMaker"
    Currency    = "USD"
  }

  tags = local.common_tags
}

# Auto-scaling for Cost Optimization
resource "aws_applicationautoscaling_policy" "kinesis_cost_optimization" {
  name               = "${local.name_prefix}-kinesis-cost-optimization"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_applicationautoscaling_target.kinesis_autoscaling.resource_id
  scalable_dimension = aws_applicationautoscaling_target.kinesis_autoscaling.scalable_dimension
  service_namespace  = aws_applicationautoscaling_target.kinesis_autoscaling.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = 50.0

    predefined_metric_specification {
      predefined_metric_type = "KinesisStreamAverageRecordAge"
    }

    scale_in_cooldown  = 600
    scale_out_cooldown = 300
  }
}

# S3 Lifecycle Policies for Cost Optimization
resource "aws_s3_bucket_lifecycle_configuration" "data_lake_cost_optimization" {
  bucket = aws_s3_bucket.data_lake.id

  rule {
    id     = "cost_optimization_rule"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    transition {
      days          = 365
      storage_class = "DEEP_ARCHIVE"
    }

    expiration {
      days = 2555  # 7 years
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = 90
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = 2555
    }
  }
}

# Cost Optimization IAM Policy
resource "aws_iam_role_policy" "cost_optimization_policy" {
  name = "${local.name_prefix}-cost-optimization-policy"
  role = aws_iam_role.lambda_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ce:GetCostAndUsage",
          "ce:GetDimensionValues",
          "ce:GetReservationCoverage",
          "ce:GetReservationPurchaseRecommendation",
          "ce:GetReservationUtilization",
          "ce:GetRightsizingRecommendation",
          "ce:GetSavingsPlansUtilization",
          "ce:GetUsageReport"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "kinesis:DescribeStream",
          "kinesis:UpdateShardCount"
        ]
        Resource = aws_kinesis_stream.data_stream.arn
      },
      {
        Effect = "Allow"
        Action = [
          "redshift:DescribeClusters",
          "redshift:ModifyCluster"
        ]
        Resource = aws_redshift_cluster.analytics_cluster.arn
      },
      {
        Effect = "Allow"
        Action = [
          "sagemaker:DescribeEndpoint",
          "sagemaker:UpdateEndpoint"
        ]
        Resource = aws_sagemaker_endpoint.ml_endpoint.arn
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:GetFunction",
          "lambda:UpdateFunctionConfiguration"
        ]
        Resource = aws_lambda_function.data_processor.arn
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
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

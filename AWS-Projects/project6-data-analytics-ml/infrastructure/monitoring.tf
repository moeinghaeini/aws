# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${local.name_prefix}"
  retention_in_days = 14

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "kinesis_logs" {
  name              = "/aws/kinesis/${local.name_prefix}"
  retention_in_days = 7

  tags = local.common_tags
}

# CloudWatch Dashboards
resource "aws_cloudwatch_dashboard" "analytics_dashboard" {
  dashboard_name = "${local.name_prefix}-dashboard"

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
            ["AWS/Kinesis", "IncomingRecords", "StreamName", aws_kinesis_stream.data_stream.name],
            [".", "OutgoingRecords", ".", "."],
            [".", "WriteProvisionedThroughputExceeded", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Kinesis Stream Metrics"
          period  = 300
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
            ["AWS/Redshift", "DatabaseConnections", "ClusterIdentifier", aws_redshift_cluster.analytics_cluster.cluster_identifier],
            [".", "CPUUtilization", ".", "."],
            [".", "FreeStorageSpace", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Redshift Cluster Metrics"
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
            ["AWS/SageMaker", "ModelLatency", "EndpointName", aws_sagemaker_endpoint.ml_endpoint.name],
            [".", "Invocation4XXErrors", ".", "."],
            [".", "Invocation5XXErrors", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "SageMaker Endpoint Metrics"
          period  = 300
        }
      }
    ]
  })

  tags = local.common_tags
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "kinesis_throttle_alarm" {
  alarm_name          = "${local.name_prefix}-kinesis-throttle"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "WriteProvisionedThroughputExceeded"
  namespace           = "AWS/Kinesis"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "This metric monitors kinesis write throttles"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    StreamName = aws_kinesis_stream.data_stream.name
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "redshift_cpu_alarm" {
  alarm_name          = "${local.name_prefix}-redshift-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/Redshift"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors redshift cpu utilization"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ClusterIdentifier = aws_redshift_cluster.analytics_cluster.cluster_identifier
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "sagemaker_errors_alarm" {
  alarm_name          = "${local.name_prefix}-sagemaker-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Invocation5XXErrors"
  namespace           = "AWS/SageMaker"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "This metric monitors sagemaker 5xx errors"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    EndpointName = aws_sagemaker_endpoint.ml_endpoint.name
  }

  tags = local.common_tags
}

# SNS Topic for Alerts
resource "aws_sns_topic" "alerts" {
  name = "${local.name_prefix}-alerts"

  tags = local.common_tags
}

resource "aws_sns_topic_subscription" "email_alerts" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# EventBridge Rules
resource "aws_cloudwatch_event_rule" "data_quality_check" {
  name        = "${local.name_prefix}-data-quality-check"
  description = "Trigger data quality checks on schedule"

  schedule_expression = "rate(1 hour)"

  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "lambda_data_quality" {
  rule      = aws_cloudwatch_event_rule.data_quality_check.name
  target_id = "DataQualityLambdaTarget"
  arn       = aws_lambda_function.data_quality_checker.arn
}

# X-Ray Tracing
resource "aws_xray_sampling_rule" "analytics_sampling" {
  rule_name      = "${local.name_prefix}-sampling-rule"
  priority       = 10000
  version        = 1
  reservoir_size = 1
  fixed_rate     = 0.1
  url_path       = "*"
  host           = "*"
  http_method    = "*"
  service_type   = "*"
  service_name   = "*"
  resource_arn   = "*"

  tags = local.common_tags
}

# Advanced Performance Monitoring and SLAs
resource "aws_cloudwatch_dashboard" "performance_sla_dashboard" {
  dashboard_name = "${local.name_prefix}-performance-sla-dashboard"

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
            [".", "WriteProvisionedThroughputExceeded", ".", "."],
            [".", "GetRecords.IteratorAgeMilliseconds", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Kinesis Performance SLAs"
          period  = 300
          annotations = {
            horizontal = [
              {
                label = "SLA: < 1000ms Iterator Age"
                value = 1000
              }
            ]
          }
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
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.data_processor.function_name],
            [".", "Errors", ".", "."],
            [".", "Throttles", ".", "."],
            [".", "ConcurrentExecutions", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Lambda Performance SLAs"
          period  = 300
          annotations = {
            horizontal = [
              {
                label = "SLA: < 5s Duration"
                value = 5000
              }
            ]
          }
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
            [".", "QueryDuration", ".", "."],
            [".", "QueriesCompletedPerSecond", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Redshift Performance SLAs"
          period  = 300
          annotations = {
            horizontal = [
              {
                label = "SLA: < 80% CPU"
                value = 80
              }
            ]
          }
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
            [".", "Invocation4XXErrors", ".", "."],
            [".", "Invocation5XXErrors", ".", "."],
            [".", "InvocationsPerInstance", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "SageMaker Performance SLAs"
          period  = 300
          annotations = {
            horizontal = [
              {
                label = "SLA: < 200ms Latency"
                value = 200
              }
            ]
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

# Performance SLA Alarms
resource "aws_cloudwatch_metric_alarm" "kinesis_iterator_age_sla" {
  alarm_name          = "${local.name_prefix}-kinesis-iterator-age-sla"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "GetRecords.IteratorAgeMilliseconds"
  namespace           = "AWS/Kinesis"
  period              = "300"
  statistic           = "Average"
  threshold           = "1000"
  alarm_description   = "Kinesis iterator age exceeds SLA threshold (1000ms)"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    StreamName = aws_kinesis_stream.data_stream.name
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_duration_sla" {
  alarm_name          = "${local.name_prefix}-lambda-duration-sla"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Average"
  threshold           = "5000"
  alarm_description   = "Lambda duration exceeds SLA threshold (5000ms)"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    FunctionName = aws_lambda_function.data_processor.function_name
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "redshift_cpu_sla" {
  alarm_name          = "${local.name_prefix}-redshift-cpu-sla"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/Redshift"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Redshift CPU utilization exceeds SLA threshold (80%)"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    ClusterIdentifier = aws_redshift_cluster.analytics_cluster.cluster_identifier
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "sagemaker_latency_sla" {
  alarm_name          = "${local.name_prefix}-sagemaker-latency-sla"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ModelLatency"
  namespace           = "AWS/SageMaker"
  period              = "300"
  statistic           = "Average"
  threshold           = "200"
  alarm_description   = "SageMaker model latency exceeds SLA threshold (200ms)"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    EndpointName = aws_sagemaker_endpoint.ml_endpoint.name
  }

  tags = local.common_tags
}

# Custom Performance Metrics
resource "aws_cloudwatch_log_metric_filter" "data_processing_latency" {
  name           = "${local.name_prefix}-data-processing-latency"
  log_group_name = aws_cloudwatch_log_group.lambda_logs.name
  pattern        = "[timestamp, request_id, level, message=\"Processing\", duration]"

  metric_transformation {
    name      = "DataProcessingLatency"
    namespace = "DataAnalytics/Performance"
    value     = "$duration"
    unit      = "Milliseconds"
  }
}

resource "aws_cloudwatch_log_metric_filter" "ml_inference_latency" {
  name           = "${local.name_prefix}-ml-inference-latency"
  log_group_name = aws_cloudwatch_log_group.lambda_logs.name
  pattern        = "[timestamp, request_id, level, message=\"ML inference\", duration]"

  metric_transformation {
    name      = "MLInferenceLatency"
    namespace = "DataAnalytics/Performance"
    value     = "$duration"
    unit      = "Milliseconds"
  }
}

resource "aws_cloudwatch_log_metric_filter" "data_quality_score" {
  name           = "${local.name_prefix}-data-quality-score"
  log_group_name = aws_cloudwatch_log_group.lambda_logs.name
  pattern        = "[timestamp, request_id, level, message=\"Data quality\", score]"

  metric_transformation {
    name      = "DataQualityScore"
    namespace = "DataAnalytics/Quality"
    value     = "$score"
    unit      = "Percent"
  }
}

# Performance Baselines
resource "aws_cloudwatch_metric_alarm" "performance_baseline_deviation" {
  alarm_name          = "${local.name_prefix}-performance-baseline-deviation"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "DataProcessingLatency"
  namespace           = "DataAnalytics/Performance"
  period              = "300"
  statistic           = "Average"
  threshold           = "3000"  # 3 seconds baseline
  alarm_description   = "Data processing latency deviates from baseline"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  tags = local.common_tags
}

# Auto-scaling based on performance metrics
resource "aws_applicationautoscaling_target" "kinesis_autoscaling" {
  max_capacity       = 10
  min_capacity       = 2
  resource_id        = "stream/${aws_kinesis_stream.data_stream.name}"
  scalable_dimension = "kinesis:stream:shard-count"
  service_namespace  = "kinesis"
}

resource "aws_applicationautoscaling_policy" "kinesis_scaling_policy" {
  name               = "${local.name_prefix}-kinesis-scaling-policy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_applicationautoscaling_target.kinesis_autoscaling.resource_id
  scalable_dimension = aws_applicationautoscaling_target.kinesis_autoscaling.scalable_dimension
  service_namespace  = aws_applicationautoscaling_target.kinesis_autoscaling.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = 70.0

    predefined_metric_specification {
      predefined_metric_type = "KinesisStreamAverageRecordAge"
    }

    scale_in_cooldown  = 300
    scale_out_cooldown = 300
  }
}

# Performance Testing Lambda Function
resource "aws_lambda_function" "performance_tester" {
  filename         = "performance_tester.zip"
  function_name    = "${local.name_prefix}-performance-tester"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "performance_tester.lambda_handler"
  source_code_hash = data.archive_file.performance_tester_zip.output_base64sha256
  runtime         = "python3.11"
  timeout         = 900
  memory_size     = 512

  environment {
    variables = {
      KINESIS_STREAM = aws_kinesis_stream.data_stream.name
      SAGEMAKER_ENDPOINT = aws_sagemaker_endpoint.ml_endpoint.name
      REDSHIFT_CLUSTER = aws_redshift_cluster.analytics_cluster.cluster_identifier
    }
  }

  tags = local.common_tags
}

# Performance Tester Source Code
data "archive_file" "performance_tester_zip" {
  type        = "zip"
  output_path = "performance_tester.zip"
  source {
    content = templatefile("${path.module}/lambda_functions/performance_tester.py", {
      kinesis_stream = aws_kinesis_stream.data_stream.name
    })
    filename = "performance_tester.py"
  }
}

# Scheduled Performance Testing
resource "aws_cloudwatch_event_rule" "performance_testing_schedule" {
  name                = "${local.name_prefix}-performance-testing-schedule"
  description         = "Trigger performance testing on schedule"
  schedule_expression = "rate(1 hour)"

  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "performance_tester_lambda" {
  rule      = aws_cloudwatch_event_rule.performance_testing_schedule.name
  target_id = "PerformanceTesterLambdaTarget"
  arn       = aws_lambda_function.performance_tester.arn
}

resource "aws_lambda_permission" "allow_eventbridge_performance_tester" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.performance_tester.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.performance_testing_schedule.arn
}

# Performance Reporting
resource "aws_cloudwatch_log_group" "performance_reports" {
  name              = "/aws/lambda/${local.name_prefix}-performance-reports"
  retention_in_days = 30

  tags = local.common_tags
}

# Performance IAM Policy
resource "aws_iam_role_policy" "performance_monitoring_policy" {
  name = "${local.name_prefix}-performance-monitoring-policy"
  role = aws_iam_role.lambda_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kinesis:PutRecord",
          "kinesis:PutRecords",
          "kinesis:DescribeStream"
        ]
        Resource = aws_kinesis_stream.data_stream.arn
      },
      {
        Effect = "Allow"
        Action = [
          "sagemaker:InvokeEndpoint"
        ]
        Resource = aws_sagemaker_endpoint.ml_endpoint.arn
      },
      {
        Effect = "Allow"
        Action = [
          "redshift-data:ExecuteStatement",
          "redshift-data:GetStatementResult"
        ]
        Resource = "*"
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

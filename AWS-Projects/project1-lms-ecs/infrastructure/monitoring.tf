# Advanced Monitoring and Observability Configuration

# X-Ray Tracing
resource "aws_xray_sampling_rule" "lms_sampling_rule" {
  rule_name      = "lms-sampling-rule"
  priority       = 1000
  version        = 1
  reservoir_size = 1
  fixed_rate     = 0.1
  url_path       = "*"
  host           = "*"
  http_method    = "*"
  service_type   = "*"
  service_name   = "*"
  resource_arn   = "*"
}

# CloudWatch Log Groups with retention
resource "aws_cloudwatch_log_group" "lms_application_logs" {
  name              = "/ecs/lms-application"
  retention_in_days = 30

  tags = {
    Name    = "lms-application-logs"
    Project = "lms-ecs"
  }
}

resource "aws_cloudwatch_log_group" "lms_nginx_logs" {
  name              = "/ecs/lms-nginx"
  retention_in_days = 14

  tags = {
    Name    = "lms-nginx-logs"
    Project = "lms-ecs"
  }
}

# Custom CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "lms_dashboard" {
  dashboard_name = "LMS-Application-Dashboard"

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
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.lms_alb.arn_suffix],
            [".", "TargetResponseTime", ".", "."],
            [".", "HTTPCode_Target_2XX_Count", ".", "."],
            [".", "HTTPCode_Target_4XX_Count", ".", "."],
            [".", "HTTPCode_Target_5XX_Count", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Application Load Balancer Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ServiceName", "lms-service", "ClusterName", aws_ecs_cluster.lms_cluster.name],
            [".", "MemoryUtilization", ".", ".", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "ECS Service Metrics"
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
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", aws_db_instance.lms_db.id],
            [".", "DatabaseConnections", ".", "."],
            [".", "FreeableMemory", ".", "."],
            [".", "FreeStorageSpace", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "RDS Database Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/WAFV2", "AllowedRequests", "WebACL", aws_wafv2_web_acl.lms_waf.name, "Region", var.aws_region],
            [".", "BlockedRequests", ".", ".", ".", "."],
            [".", "CountedRequests", ".", ".", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "WAF Metrics"
          period  = 300
        }
      }
    ]
  })
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "lms_high_cpu" {
  alarm_name          = "lms-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ECS CPU utilization"
  alarm_actions       = [aws_sns_topic.lms_alerts.arn]

  dimensions = {
    ServiceName = "lms-service"
    ClusterName = aws_ecs_cluster.lms_cluster.name
  }

  tags = {
    Name    = "lms-high-cpu"
    Project = "lms-ecs"
  }
}

resource "aws_cloudwatch_metric_alarm" "lms_high_memory" {
  alarm_name          = "lms-high-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "85"
  alarm_description   = "This metric monitors ECS memory utilization"
  alarm_actions       = [aws_sns_topic.lms_alerts.arn]

  dimensions = {
    ServiceName = "lms-service"
    ClusterName = aws_ecs_cluster.lms_cluster.name
  }

  tags = {
    Name    = "lms-high-memory"
    Project = "lms-ecs"
  }
}

resource "aws_cloudwatch_metric_alarm" "lms_high_response_time" {
  alarm_name          = "lms-high-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = "2"
  alarm_description   = "This metric monitors ALB response time"
  alarm_actions       = [aws_sns_topic.lms_alerts.arn]

  dimensions = {
    LoadBalancer = aws_lb.lms_alb.arn_suffix
  }

  tags = {
    Name    = "lms-high-response-time"
    Project = "lms-ecs"
  }
}

resource "aws_cloudwatch_metric_alarm" "lms_5xx_errors" {
  alarm_name          = "lms-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "This metric monitors 5XX errors"
  alarm_actions       = [aws_sns_topic.lms_alerts.arn]

  dimensions = {
    LoadBalancer = aws_lb.lms_alb.arn_suffix
  }

  tags = {
    Name    = "lms-5xx-errors"
    Project = "lms-ecs"
  }
}

# SNS Topic for alerts
resource "aws_sns_topic" "lms_alerts" {
  name = "lms-alerts"

  tags = {
    Name    = "lms-alerts"
    Project = "lms-ecs"
  }
}

resource "aws_sns_topic_subscription" "lms_alerts_email" {
  topic_arn = aws_sns_topic.lms_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# Custom Metrics for Application Performance
resource "aws_cloudwatch_log_metric_filter" "lms_error_rate" {
  name           = "lms-error-rate"
  log_group_name = aws_cloudwatch_log_group.lms_application_logs.name
  pattern        = "[timestamp, request_id, level=\"ERROR\", ...]"

  metric_transformation {
    name      = "ErrorCount"
    namespace = "LMS/Application"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "lms_response_time" {
  name           = "lms-response-time"
  log_group_name = aws_cloudwatch_log_group.lms_application_logs.name
  pattern        = "[timestamp, request_id, level=\"INFO\", message=\"Request completed\", response_time=*]"

  metric_transformation {
    name      = "ResponseTime"
    namespace = "LMS/Application"
    value     = "$response_time"
  }
}

# CloudWatch Insights Queries
resource "aws_cloudwatch_query_definition" "lms_error_analysis" {
  name = "lms-error-analysis"

  log_group_names = [
    aws_cloudwatch_log_group.lms_application_logs.name
  ]

  query_string = <<EOF
fields @timestamp, @message, @logStream
| filter @message like /ERROR/
| sort @timestamp desc
| limit 100
EOF
}

resource "aws_cloudwatch_query_definition" "lms_performance_analysis" {
  name = "lms-performance-analysis"

  log_group_names = [
    aws_cloudwatch_log_group.lms_application_logs.name
  ]

  query_string = <<EOF
fields @timestamp, @message
| filter @message like /Request completed/
| parse @message "Request completed in *ms" as response_time
| stats avg(response_time), max(response_time), min(response_time) by bin(5m)
EOF
}

# EventBridge Rules for automated responses
resource "aws_cloudwatch_event_rule" "lms_high_error_rate" {
  name        = "lms-high-error-rate"
  description = "Trigger when error rate is high"

  event_pattern = jsonencode({
    source      = ["aws.cloudwatch"]
    detail-type = ["CloudWatch Alarm State Change"]
    detail = {
      state = {
        value = ["ALARM"]
      }
      alarmName = [aws_cloudwatch_metric_alarm.lms_5xx_errors.alarm_name]
    }
  })
}

resource "aws_cloudwatch_event_target" "lms_auto_scaling" {
  rule      = aws_cloudwatch_event_rule.lms_high_error_rate.name
  target_id = "AutoScalingTarget"
  arn       = aws_ecs_service.lms_service.id

  ecs_target {
    task_count          = 2
    task_definition_arn = aws_ecs_task_definition.lms_task.arn
    launch_type         = "FARGATE"
    platform_version    = "1.4.0"

    network_configuration {
      subnets          = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
      security_groups  = [aws_security_group.ecs_sg.id]
      assign_public_ip = false
    }
  }
}

# Variables
variable "alert_email" {
  description = "Email address for receiving alerts"
  type        = string
  default     = "admin@example.com"
}

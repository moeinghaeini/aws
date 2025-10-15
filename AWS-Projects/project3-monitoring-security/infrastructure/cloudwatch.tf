# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/monitoring-lambda"
  retention_in_days = 14

  tags = {
    Name = "monitoring-lambda-logs"
    Project = "monitoring-security"
  }
}

resource "aws_cloudwatch_log_group" "application_logs" {
  name              = "/aws/ec2/monitoring-application"
  retention_in_days = 30

  tags = {
    Name = "monitoring-application-logs"
    Project = "monitoring-security"
  }
}

# CloudWatch Alarms for EC2 Monitoring
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "monitoring-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ec2 cpu utilization"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    InstanceId = aws_instance.monitored_instance.id
  }

  tags = {
    Name = "monitoring-high-cpu"
    Project = "monitoring-security"
  }
}

resource "aws_cloudwatch_metric_alarm" "high_memory" {
  alarm_name          = "monitoring-high-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "System/Linux"
  period              = "300"
  statistic           = "Average"
  threshold           = "85"
  alarm_description   = "This metric monitors ec2 memory utilization"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    InstanceId = aws_instance.monitored_instance.id
  }

  tags = {
    Name = "monitoring-high-memory"
    Project = "monitoring-security"
  }
}

resource "aws_cloudwatch_metric_alarm" "disk_space" {
  alarm_name          = "monitoring-disk-space"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "DiskSpaceUtilization"
  namespace           = "System/Linux"
  period              = "300"
  statistic           = "Average"
  threshold           = "90"
  alarm_description   = "This metric monitors disk space utilization"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    InstanceId = aws_instance.monitored_instance.id
    MountPath  = "/"
    Filesystem = "/dev/xvda1"
  }

  tags = {
    Name = "monitoring-disk-space"
    Project = "monitoring-security"
  }
}

resource "aws_cloudwatch_metric_alarm" "instance_status" {
  alarm_name          = "monitoring-instance-status"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Maximum"
  threshold           = "0"
  alarm_description   = "This metric monitors instance status checks"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    InstanceId = aws_instance.monitored_instance.id
  }

  tags = {
    Name = "monitoring-instance-status"
    Project = "monitoring-security"
  }
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "monitoring_dashboard" {
  dashboard_name = "monitoring-security-dashboard"

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
            ["AWS/EC2", "CPUUtilization", "InstanceId", aws_instance.monitored_instance.id],
            [".", "NetworkIn", ".", "."],
            [".", "NetworkOut", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "EC2 Instance Metrics"
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
            ["System/Linux", "MemoryUtilization", "InstanceId", aws_instance.monitored_instance.id],
            [".", "DiskSpaceUtilization", ".", ".", "MountPath", "/", "Filesystem", "/dev/xvda1"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "System Metrics"
          period  = 300
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 12
        width  = 24
        height = 6

        properties = {
          query   = "SOURCE '/aws/ec2/monitoring-application' | fields @timestamp, @message | sort @timestamp desc | limit 100"
          region  = var.aws_region
          title   = "Application Logs"
        }
      }
    ]
  })
}

# Custom Metrics for Application Monitoring
resource "aws_cloudwatch_metric_alarm" "application_errors" {
  alarm_name          = "monitoring-application-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "ErrorCount"
  namespace           = "Custom/Application"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "This metric monitors application errors"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  tags = {
    Name = "monitoring-application-errors"
    Project = "monitoring-security"
  }
}

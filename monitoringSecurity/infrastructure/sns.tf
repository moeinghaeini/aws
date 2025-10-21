# SNS Topic for Alerts
resource "aws_sns_topic" "alerts" {
  name = "monitoring-security-alerts"

  tags = {
    Name = "monitoring-security-alerts"
    Project = "monitoring-security"
  }
}

# SNS Topic for Security Alerts
resource "aws_sns_topic" "security_alerts" {
  name = "monitoring-security-threats"

  tags = {
    Name = "monitoring-security-threats"
    Project = "monitoring-security"
  }
}

# SNS Topic for Compliance Alerts
resource "aws_sns_topic" "compliance_alerts" {
  name = "monitoring-compliance-alerts"

  tags = {
    Name = "monitoring-compliance-alerts"
    Project = "monitoring-security"
  }
}

# SNS Topic Subscriptions (Email)
resource "aws_sns_topic_subscription" "alerts_email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_sns_topic_subscription" "security_alerts_email" {
  topic_arn = aws_sns_topic.security_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_sns_topic_subscription" "compliance_alerts_email" {
  topic_arn = aws_sns_topic.compliance_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# SNS Topic Policy
resource "aws_sns_topic_policy" "alerts_policy" {
  arn = aws_sns_topic.alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = [
            "cloudwatch.amazonaws.com",
            "lambda.amazonaws.com",
            "guardduty.amazonaws.com",
            "securityhub.amazonaws.com"
          ]
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.alerts.arn
      }
    ]
  })
}

resource "aws_sns_topic_policy" "security_alerts_policy" {
  arn = aws_sns_topic.security_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = [
            "guardduty.amazonaws.com",
            "securityhub.amazonaws.com",
            "lambda.amazonaws.com"
          ]
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.security_alerts.arn
      }
    ]
  })
}

# Variables
variable "alert_email" {
  description = "Email address for receiving alerts"
  type        = string
  default     = "admin@example.com"
}

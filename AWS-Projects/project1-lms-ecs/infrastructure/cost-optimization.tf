# Cost Optimization and Monitoring Configuration

# AWS Cost and Usage Reports
resource "aws_cur_report_definition" "lms_cost_report" {
  report_name                = "lms-cost-report"
  time_unit                  = "DAILY"
  format                     = "textORcsv"
  compression                = "GZIP"
  additional_schema_elements = ["RESOURCES"]
  s3_bucket                  = aws_s3_bucket.lms_cost_reports.bucket
  s3_prefix                  = "cost-reports/"
  s3_region                  = var.aws_region
  additional_artifacts       = ["REDSHIFT", "QUICKSIGHT"]
  refresh_closed_reports     = true
  report_versioning          = "OVERWRITE_REPORT"
}

# S3 bucket for cost reports
resource "aws_s3_bucket" "lms_cost_reports" {
  bucket = "lms-cost-reports-${random_string.bucket_suffix.result}"

  tags = {
    Name    = "lms-cost-reports"
    Project = "lms-ecs"
  }
}

# Cost Anomaly Detection
resource "aws_ce_anomaly_detector" "lms_cost_anomaly" {
  name = "lms-cost-anomaly-detector"

  specification = "DAILY_COST_ANOMALY_DETECTION"

  monitor_arn_list = [
    aws_ce_cost_category.lms_cost_category.arn
  ]
}

# Cost Categories for better cost allocation
resource "aws_ce_cost_category" "lms_cost_category" {
  name = "lms-cost-category"
  rule {
    value = "LMS-ECS"
    rule {
      dimension {
        key           = "SERVICE"
        values        = ["Amazon Elastic Compute Cloud - Compute", "Amazon Relational Database Service"]
        match_options = ["EQUALS"]
      }
    }
  }
}

# Lambda function for cost optimization recommendations
resource "aws_lambda_function" "cost_optimizer" {
  filename         = "lambda_functions/cost_optimizer.zip"
  function_name    = "lms-cost-optimizer"
  role            = aws_iam_role.lambda_cost_role.arn
  handler         = "cost_optimizer.lambda_handler"
  runtime         = "python3.11"
  timeout         = 300

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.lms_cost_alerts.arn
    }
  }

  tags = {
    Name    = "lms-cost-optimizer"
    Project = "lms-ecs"
  }
}

# IAM Role for cost optimization Lambda
resource "aws_iam_role" "lambda_cost_role" {
  name = "lms-lambda-cost-role"

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

resource "aws_iam_policy" "lambda_cost_policy" {
  name        = "lms-lambda-cost-policy"
  description = "Policy for cost optimization Lambda"

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
          "sns:Publish",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_cost_policy_attachment" {
  role       = aws_iam_role.lambda_cost_role.name
  policy_arn = aws_iam_policy.lambda_cost_policy.arn
}

# SNS Topic for cost alerts
resource "aws_sns_topic" "lms_cost_alerts" {
  name = "lms-cost-alerts"

  tags = {
    Name    = "lms-cost-alerts"
    Project = "lms-ecs"
  }
}

# EventBridge rule for cost optimization
resource "aws_cloudwatch_event_rule" "cost_optimization" {
  name                = "lms-cost-optimization"
  description         = "Trigger cost optimization analysis"
  schedule_expression = "cron(0 9 * * ? *)"  # Daily at 9 AM UTC
}

resource "aws_cloudwatch_event_target" "lambda_cost_target" {
  rule      = aws_cloudwatch_event_rule.cost_optimization.name
  target_id = "LambdaCostTarget"
  arn       = aws_lambda_function.cost_optimizer.arn
}

resource "aws_lambda_permission" "allow_cost_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cost_optimizer.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.cost_optimization.arn
}

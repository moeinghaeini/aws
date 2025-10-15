# Lambda function for auto-remediation
resource "aws_lambda_function" "auto_remediation" {
  filename         = "lambda_functions/auto_remediation.zip"
  function_name    = "monitoring-auto-remediation"
  role            = aws_iam_role.lambda_role.arn
  handler         = "auto_remediation.handler"
  source_code_hash = data.archive_file.auto_remediation_zip.output_base64sha256
  runtime         = "python3.11"
  timeout         = 300

  vpc_config {
    subnet_ids         = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.alerts.arn
      SECURITY_SNS_TOPIC_ARN = aws_sns_topic.security_alerts.arn
    }
  }

  tags = {
    Name = "monitoring-auto-remediation"
    Project = "monitoring-security"
  }

  depends_on = [data.archive_file.auto_remediation_zip]
}

# Lambda function for security response
resource "aws_lambda_function" "security_response" {
  filename         = "lambda_functions/security_response.zip"
  function_name    = "monitoring-security-response"
  role            = aws_iam_role.lambda_role.arn
  handler         = "security_response.handler"
  source_code_hash = data.archive_file.security_response_zip.output_base64sha256
  runtime         = "python3.11"
  timeout         = 300

  vpc_config {
    subnet_ids         = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      SECURITY_SNS_TOPIC_ARN = aws_sns_topic.security_alerts.arn
    }
  }

  tags = {
    Name = "monitoring-security-response"
    Project = "monitoring-security"
  }

  depends_on = [data.archive_file.security_response_zip]
}

# Lambda function for compliance monitoring
resource "aws_lambda_function" "compliance_monitor" {
  filename         = "lambda_functions/compliance_monitor.zip"
  function_name    = "monitoring-compliance-monitor"
  role            = aws_iam_role.lambda_role.arn
  handler         = "compliance_monitor.handler"
  source_code_hash = data.archive_file.compliance_monitor_zip.output_base64sha256
  runtime         = "python3.11"
  timeout         = 300

  vpc_config {
    subnet_ids         = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      COMPLIANCE_SNS_TOPIC_ARN = aws_sns_topic.compliance_alerts.arn
    }
  }

  tags = {
    Name = "monitoring-compliance-monitor"
    Project = "monitoring-security"
  }

  depends_on = [data.archive_file.compliance_monitor_zip]
}

# Lambda function for cost optimization
resource "aws_lambda_function" "cost_optimizer" {
  filename         = "lambda_functions/cost_optimizer.zip"
  function_name    = "monitoring-cost-optimizer"
  role            = aws_iam_role.lambda_role.arn
  handler         = "cost_optimizer.handler"
  source_code_hash = data.archive_file.cost_optimizer_zip.output_base64sha256
  runtime         = "python3.11"
  timeout         = 300

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.alerts.arn
    }
  }

  tags = {
    Name = "monitoring-cost-optimizer"
    Project = "monitoring-security"
  }

  depends_on = [data.archive_file.cost_optimizer_zip]
}

# Archive files for Lambda functions
data "archive_file" "auto_remediation_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda_functions/auto_remediation"
  output_path = "${path.module}/lambda_functions/auto_remediation.zip"
}

data "archive_file" "security_response_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda_functions/security_response"
  output_path = "${path.module}/lambda_functions/security_response.zip"
}

data "archive_file" "compliance_monitor_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda_functions/compliance_monitor"
  output_path = "${path.module}/lambda_functions/compliance_monitor.zip"
}

data "archive_file" "cost_optimizer_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda_functions/cost_optimizer"
  output_path = "${path.module}/lambda_functions/cost_optimizer.zip"
}

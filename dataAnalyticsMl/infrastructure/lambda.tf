# Lambda Function for Data Processing
resource "aws_lambda_function" "data_processor" {
  filename         = data.archive_file.data_processor_zip.output_path
  function_name    = "${local.name_prefix}-data-processor"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "data_processor.lambda_handler"
  source_code_hash = data.archive_file.data_processor_zip.output_base64sha256
  runtime         = "python3.11"
  timeout         = 300

  vpc_config {
    subnet_ids         = aws_subnet.private_subnets[*].id
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      REDSHIFT_CLUSTER_ID = aws_redshift_cluster.analytics_cluster.cluster_identifier
      REDSHIFT_DATABASE   = aws_redshift_cluster.analytics_cluster.database_name
      S3_BUCKET          = aws_s3_bucket.data_lake.bucket
      SAGEMAKER_ENDPOINT = aws_sagemaker_endpoint.ml_endpoint.name
    }
  }

  tags = local.common_tags

  depends_on = [
    aws_cloudwatch_log_group.lambda_logs,
    aws_iam_role_policy_attachment.lambda_basic_execution,
  ]
}

data "archive_file" "data_processor_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda_functions/data_processor.py"
  output_path = "${path.module}/../lambda_functions/data_processor.zip"
}

# Lambda Function for ML Inference
resource "aws_lambda_function" "ml_inference" {
  filename         = data.archive_file.ml_inference_zip.output_path
  function_name    = "${local.name_prefix}-ml-inference"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "ml_inference.lambda_handler"
  source_code_hash = data.archive_file.ml_inference_zip.output_base64sha256
  runtime         = "python3.11"
  timeout         = 60

  vpc_config {
    subnet_ids         = aws_subnet.private_subnets[*].id
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      SAGEMAKER_ENDPOINT = aws_sagemaker_endpoint.ml_endpoint.name
      REDSHIFT_CLUSTER_ID = aws_redshift_cluster.analytics_cluster.cluster_identifier
    }
  }

  tags = local.common_tags

  depends_on = [
    aws_cloudwatch_log_group.lambda_logs,
    aws_iam_role_policy_attachment.lambda_basic_execution,
  ]
}

data "archive_file" "ml_inference_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda_functions/ml_inference.py"
  output_path = "${path.module}/../lambda_functions/ml_inference.zip"
}

# Lambda Function for Data Quality Checks
resource "aws_lambda_function" "data_quality_checker" {
  filename         = data.archive_file.data_quality_zip.output_path
  function_name    = "${local.name_prefix}-data-quality-checker"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "data_quality_checker.lambda_handler"
  source_code_hash = data.archive_file.data_quality_zip.output_base64sha256
  runtime         = "python3.11"
  timeout         = 300

  vpc_config {
    subnet_ids         = aws_subnet.private_subnets[*].id
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      REDSHIFT_CLUSTER_ID = aws_redshift_cluster.analytics_cluster.cluster_identifier
      SNS_TOPIC_ARN      = aws_sns_topic.alerts.arn
    }
  }

  tags = local.common_tags

  depends_on = [
    aws_cloudwatch_log_group.lambda_logs,
    aws_iam_role_policy_attachment.lambda_basic_execution,
  ]
}

data "archive_file" "data_quality_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda_functions/data_quality_checker.py"
  output_path = "${path.module}/../lambda_functions/data_quality_checker.zip"
}

# Kinesis Event Source Mapping
resource "aws_lambda_event_source_mapping" "kinesis_trigger" {
  event_source_arn  = aws_kinesis_stream.data_stream.arn
  function_name     = aws_lambda_function.data_processor.arn
  starting_position = "LATEST"
  batch_size        = 100
  maximum_batching_window_in_seconds = 5

  depends_on = [aws_lambda_function.data_processor]
}

# Lambda Permissions
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.data_quality_checker.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.data_quality_check.arn
}

# Lambda Layer for Dependencies
resource "aws_lambda_layer_version" "analytics_dependencies" {
  filename   = data.archive_file.dependencies_zip.output_path
  layer_name = "${local.name_prefix}-dependencies"

  compatible_runtimes = ["python3.11"]

  tags = local.common_tags
}

data "archive_file" "dependencies_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda_functions/dependencies"
  output_path = "${path.module}/../lambda_functions/dependencies.zip"
}

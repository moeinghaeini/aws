terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Variables
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "debugging"
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# S3 Bucket for hosting the contact form
resource "aws_s3_bucket" "contact_form_bucket" {
  bucket = "contact-form-${random_string.bucket_suffix.result}"

  tags = {
    Name = "contact-form-bucket"
    Project = "serverless-contact-debugging"
  }
}

resource "aws_s3_bucket_website_configuration" "contact_form_bucket" {
  bucket = aws_s3_bucket.contact_form_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

resource "aws_s3_bucket_public_access_block" "contact_form_bucket" {
  bucket = aws_s3_bucket.contact_form_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "contact_form_bucket" {
  bucket = aws_s3_bucket.contact_form_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.contact_form_bucket.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.contact_form_bucket]
}

# Random string for bucket suffix
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# DynamoDB table for contact submissions
resource "aws_dynamodb_table" "contact_submissions" {
  name           = "contact-submissions"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "submission_id"

  attribute {
    name = "submission_id"
    type = "S"
  }

  attribute {
    name = "email"
    type = "S"
  }

  attribute {
    name = "created_at"
    type = "S"
  }

  global_secondary_index {
    name     = "email-index"
    hash_key = "email"
  }

  global_secondary_index {
    name     = "created-at-index"
    hash_key = "created_at"
  }

  tags = {
    Name = "contact-submissions"
    Project = "serverless-contact-debugging"
  }
}

# SNS Topic for notifications
resource "aws_sns_topic" "contact_notifications" {
  name = "contact-notifications"

  tags = {
    Name = "contact-notifications"
    Project = "serverless-contact-debugging"
  }
}

# SNS Topic Subscription (Email)
resource "aws_sns_topic_subscription" "contact_notifications_email" {
  topic_arn = aws_sns_topic.contact_notifications.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# IAM Role for Lambda function
resource "aws_iam_role" "lambda_role" {
  name = "contact-form-lambda-role"

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

  tags = {
    Name = "contact-form-lambda-role"
    Project = "serverless-contact-debugging"
  }
}

# IAM Policy for Lambda function
resource "aws_iam_policy" "lambda_policy" {
  name = "contact-form-lambda-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = aws_dynamodb_table.contact_submissions.arn
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = "${aws_dynamodb_table.contact_submissions.arn}/index/*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.contact_notifications.arn
      }
    ]
  })
}

# Attach policy to Lambda role
resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# Lambda function for contact form processing
resource "aws_lambda_function" "contact_handler" {
  filename         = "lambda_functions/contact_handler.zip"
  function_name    = "contact-form-handler"
  role            = aws_iam_role.lambda_role.arn
  handler         = "contact_handler.lambda_handler"
  source_code_hash = data.archive_file.contact_handler_zip.output_base64sha256
  runtime         = "python3.9"
  timeout         = 30

  environment {
    variables = {
      CONTACT_TABLE = aws_dynamodb_table.contact_submissions.name
      SNS_TOPIC_ARN = aws_sns_topic.contact_notifications.arn
    }
  }

  tags = {
    Name = "contact-form-handler"
    Project = "serverless-contact-debugging"
  }

  depends_on = [data.archive_file.contact_handler_zip]
}

# Lambda function for broken contact form processing (for debugging)
resource "aws_lambda_function" "broken_contact_handler" {
  filename         = "lambda_functions/broken_contact_handler.zip"
  function_name    = "broken-contact-form-handler"
  role            = aws_iam_role.lambda_role.arn
  handler         = "broken_contact_handler.lambda_handler"
  source_code_hash = data.archive_file.broken_contact_handler_zip.output_base64sha256
  runtime         = "python3.9"
  timeout         = 30

  environment {
    variables = {
      CONTACT_TABLE = aws_dynamodb_table.contact_submissions.name
      SNS_TOPIC_ARN = aws_sns_topic.contact_notifications.arn
    }
  }

  tags = {
    Name = "broken-contact-form-handler"
    Project = "serverless-contact-debugging"
  }

  depends_on = [data.archive_file.broken_contact_handler_zip]
}

# Archive files for Lambda functions
data "archive_file" "contact_handler_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/contact_handler.py"
  output_path = "${path.module}/lambda_functions/contact_handler.zip"
}

data "archive_file" "broken_contact_handler_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/broken_contact_handler.py"
  output_path = "${path.module}/lambda_functions/broken_contact_handler.zip"
}

# API Gateway
resource "aws_api_gateway_rest_api" "contact_api" {
  name        = "contact-form-api"
  description = "API for contact form submissions"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Name = "contact-form-api"
    Project = "serverless-contact-debugging"
  }
}

# API Gateway Resource
resource "aws_api_gateway_resource" "contact_resource" {
  rest_api_id = aws_api_gateway_rest_api.contact_api.id
  parent_id   = aws_api_gateway_rest_api.contact_api.root_resource_id
  path_part   = "contact"
}

# API Gateway Method
resource "aws_api_gateway_method" "contact_method" {
  rest_api_id   = aws_api_gateway_rest_api.contact_api.id
  resource_id   = aws_api_gateway_resource.contact_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

# API Gateway Integration
resource "aws_api_gateway_integration" "contact_integration" {
  rest_api_id = aws_api_gateway_rest_api.contact_api.id
  resource_id = aws_api_gateway_resource.contact_resource.id
  http_method = aws_api_gateway_method.contact_method.http_method

  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.contact_handler.invoke_arn
}

# API Gateway Method for OPTIONS (CORS)
resource "aws_api_gateway_method" "contact_options" {
  rest_api_id   = aws_api_gateway_rest_api.contact_api.id
  resource_id   = aws_api_gateway_resource.contact_resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# API Gateway Integration for OPTIONS
resource "aws_api_gateway_integration" "contact_options_integration" {
  rest_api_id = aws_api_gateway_rest_api.contact_api.id
  resource_id = aws_api_gateway_resource.contact_resource.id
  http_method = aws_api_gateway_method.contact_options.http_method

  type = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

# API Gateway Method Response for OPTIONS
resource "aws_api_gateway_method_response" "contact_options_response" {
  rest_api_id = aws_api_gateway_rest_api.contact_api.id
  resource_id = aws_api_gateway_resource.contact_resource.id
  http_method = aws_api_gateway_method.contact_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

# API Gateway Integration Response for OPTIONS
resource "aws_api_gateway_integration_response" "contact_options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.contact_api.id
  resource_id = aws_api_gateway_resource.contact_resource.id
  http_method = aws_api_gateway_method.contact_options.http_method
  status_code = aws_api_gateway_method_response.contact_options_response.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

# Lambda Permission for API Gateway
resource "aws_lambda_permission" "api_gateway_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.contact_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.contact_api.execution_arn}/*/*"
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "contact_deployment" {
  depends_on = [
    aws_api_gateway_integration.contact_integration,
    aws_api_gateway_integration.contact_options_integration
  ]

  rest_api_id = aws_api_gateway_rest_api.contact_api.id
  stage_name  = "prod"

  lifecycle {
    create_before_destroy = true
  }
}

# Variables
variable "notification_email" {
  description = "Email address for receiving notifications"
  type        = string
  default     = "admin@example.com"
}

# Outputs
output "s3_bucket_name" {
  description = "Name of the S3 bucket hosting the contact form"
  value       = aws_s3_bucket.contact_form_bucket.bucket
}

output "s3_website_url" {
  description = "URL of the S3 website"
  value       = aws_s3_bucket_website_configuration.contact_form_bucket.website_endpoint
}

output "api_gateway_url" {
  description = "URL of the API Gateway"
  value       = "${aws_api_gateway_deployment.contact_deployment.invoke_url}/contact"
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  value       = aws_dynamodb_table.contact_submissions.name
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic"
  value       = aws_sns_topic.contact_notifications.arn
}

# Data Lineage Tracking Infrastructure
resource "aws_glue_crawler" "data_lineage_crawler" {
  name          = "${local.name_prefix}-data-lineage-crawler"
  role          = aws_iam_role.glue_service_role.arn
  database_name = aws_glue_catalog_database.analytics_db.name

  s3_target {
    path = "s3://${aws_s3_bucket.data_lake.bucket}/lineage/"
  }

  configuration = jsonencode({
    Version = 1.0
    Grouping = {
      TableGroupingPolicy = "CombineCompatibleSchemas"
    }
    CrawlerOutput = {
      Partitions = {
        AddOrUpdateBehavior = "InheritFromTable"
      }
    }
  })

  tags = local.common_tags
}

# Data Lineage Table
resource "aws_glue_catalog_table" "data_lineage" {
  name          = "data_lineage"
  database_name = aws_glue_catalog_database.analytics_db.name

  table_type = "EXTERNAL_TABLE"

  parameters = {
    EXTERNAL                        = "TRUE"
    "parquet.compression"           = "SNAPPY"
    "projection.enabled"            = "true"
    "projection.date.type"          = "date"
    "projection.date.range"         = "2024/01/01,NOW"
    "projection.date.format"        = "yyyy/MM/dd"
    "storage.location.template"     = "s3://${aws_s3_bucket.data_lake.bucket}/lineage/$${date}/"
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.data_lake.bucket}/lineage/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      name                  = "data_lineage"
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"

      parameters = {
        "serialization.format" = "1"
      }
    }

    columns {
      name = "lineage_id"
      type = "string"
    }

    columns {
      name = "source_system"
      type = "string"
    }

    columns {
      name = "source_table"
      type = "string"
    }

    columns {
      name = "source_column"
      type = "string"
    }

    columns {
      name = "target_system"
      type = "string"
    }

    columns {
      name = "target_table"
      type = "string"
    }

    columns {
      name = "target_column"
      type = "string"
    }

    columns {
      name = "transformation_type"
      type = "string"
    }

    columns {
      name = "transformation_logic"
      type = "string"
    }

    columns {
      name = "data_quality_rules"
      type = "string"
    }

    columns {
      name = "created_at"
      type = "timestamp"
    }

    columns {
      name = "updated_at"
      type = "timestamp"
    }

    columns {
      name = "created_by"
      type = "string"
    }

    columns {
      name = "business_owner"
      type = "string"
    }

    columns {
      name = "data_classification"
      type = "string"
    }

    columns {
      name = "retention_policy"
      type = "string"
    }
  }

  tags = local.common_tags
}

# Data Lineage Lambda Function
resource "aws_lambda_function" "data_lineage_tracker" {
  filename         = "data_lineage_tracker.zip"
  function_name    = "${local.name_prefix}-data-lineage-tracker"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "data_lineage_tracker.lambda_handler"
  source_code_hash = data.archive_file.data_lineage_tracker_zip.output_base64sha256
  runtime         = "python3.11"
  timeout         = 300
  memory_size     = 256

  vpc_config {
    subnet_ids         = aws_subnet.private_subnets[*].id
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      S3_BUCKET = aws_s3_bucket.data_lake.bucket
      GLUE_DATABASE = aws_glue_catalog_database.analytics_db.name
      GLUE_TABLE = aws_glue_catalog_table.data_lineage.name
    }
  }

  tags = local.common_tags
}

# Data Lineage Tracker Source Code
data "archive_file" "data_lineage_tracker_zip" {
  type        = "zip"
  output_path = "data_lineage_tracker.zip"
  source {
    content = templatefile("${path.module}/lambda_functions/data_lineage_tracker.py", {
      s3_bucket = aws_s3_bucket.data_lake.bucket
    })
    filename = "data_lineage_tracker.py"
  }
}

# EventBridge Rule for Data Lineage Tracking
resource "aws_cloudwatch_event_rule" "data_lineage_tracking" {
  name        = "${local.name_prefix}-data-lineage-tracking"
  description = "Trigger data lineage tracking on data processing events"

  event_pattern = jsonencode({
    source      = ["aws.kinesis", "aws.lambda", "aws.s3"]
    detail-type = ["Kinesis Stream Record", "Lambda Function Invocation", "S3 Object Created"]
    detail = {
      eventName = ["PutRecord", "PutRecords", "Invoke", "PutObject"]
    }
  })

  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "data_lineage_lambda" {
  rule      = aws_cloudwatch_event_rule.data_lineage_tracking.name
  target_id = "DataLineageLambdaTarget"
  arn       = aws_lambda_function.data_lineage_tracker.arn
}

resource "aws_lambda_permission" "allow_eventbridge_data_lineage" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.data_lineage_tracker.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.data_lineage_tracking.arn
}

# Data Lineage Dashboard
resource "aws_cloudwatch_dashboard" "data_lineage_dashboard" {
  dashboard_name = "${local.name_prefix}-data-lineage-dashboard"

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
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.data_lineage_tracker.function_name],
            [".", "Errors", ".", "."],
            [".", "Duration", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Data Lineage Tracker Metrics"
          period  = 300
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          query   = "SOURCE '/aws/lambda/${aws_lambda_function.data_lineage_tracker.function_name}' | fields @timestamp, @message | sort @timestamp desc | limit 100"
          region  = var.aws_region
          title   = "Data Lineage Tracker Logs"
          view    = "table"
        }
      }
    ]
  })

  tags = local.common_tags
}

# Data Lineage IAM Policy
resource "aws_iam_role_policy" "data_lineage_policy" {
  name = "${local.name_prefix}-data-lineage-policy"
  role = aws_iam_role.lambda_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "glue:GetTable",
          "glue:GetDatabase",
          "glue:GetPartitions",
          "glue:CreateTable",
          "glue:UpdateTable",
          "glue:BatchCreatePartition",
          "glue:BatchUpdatePartition"
        ]
        Resource = [
          aws_glue_catalog_database.analytics_db.arn,
          "${aws_glue_catalog_database.analytics_db.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.data_lake.arn,
          "${aws_s3_bucket.data_lake.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kinesis:DescribeStream",
          "kinesis:GetShardIterator",
          "kinesis:GetRecords",
          "kinesis:ListShards"
        ]
        Resource = aws_kinesis_stream.data_stream.arn
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

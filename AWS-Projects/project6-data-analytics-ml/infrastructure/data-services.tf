# S3 Data Lake
resource "aws_s3_bucket" "data_lake" {
  bucket = "${local.name_prefix}-data-lake-${random_string.bucket_suffix.result}"

  tags = local.common_tags
}

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket_versioning" "data_lake_versioning" {
  bucket = aws_s3_bucket.data_lake.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_encryption" "data_lake_encryption" {
  bucket = aws_s3_bucket.data_lake.id

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.analytics_key.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "data_lake_lifecycle" {
  bucket = aws_s3_bucket.data_lake.id

  rule {
    id     = "transition_to_ia"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }
  }
}

# Kinesis Data Stream
resource "aws_kinesis_stream" "data_stream" {
  name             = "${local.name_prefix}-data-stream"
  shard_count      = 2
  retention_period = 24

  shard_level_metrics = [
    "IncomingRecords",
    "OutgoingRecords",
  ]

  encryption_type = "KMS"
  kms_key_id      = aws_kinesis_key.stream_key.arn

  tags = local.common_tags
}

resource "aws_kms_key" "kinesis_key" {
  description             = "KMS key for Kinesis stream encryption"
  deletion_window_in_days = 7

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-kinesis-key"
  })
}

resource "aws_kinesis_key" "stream_key" {
  key_id = aws_kms_key.kinesis_key.key_id
}

# Kinesis Analytics Application
resource "aws_kinesis_analytics_application" "data_processor" {
  name = "${local.name_prefix}-data-processor"

  inputs {
    name_prefix = "SOURCE_SQL_STREAM"

    kinesis_stream {
      resource_arn = aws_kinesis_stream.data_stream.arn
      role_arn     = aws_iam_role.kinesis_analytics_role.arn
    }

    schema {
      record_columns {
        name     = "timestamp"
        sql_type = "TIMESTAMP"
        mapping  = "$.timestamp"
      }

      record_columns {
        name     = "user_id"
        sql_type = "VARCHAR(64)"
        mapping  = "$.user_id"
      }

      record_columns {
        name     = "event_type"
        sql_type = "VARCHAR(32)"
        mapping  = "$.event_type"
      }

      record_columns {
        name     = "value"
        sql_type = "DOUBLE"
        mapping  = "$.value"
      }

      record_format {
        record_format_type = "JSON"
      }
    }
  }

  outputs {
    name = "DESTINATION_SQL_STREAM"

    kinesis_stream {
      resource_arn = aws_kinesis_stream.processed_stream.arn
      role_arn     = aws_iam_role.kinesis_analytics_role.arn
    }

    schema {
      record_format_type = "JSON"
    }
  }

  tags = local.common_tags
}

resource "aws_kinesis_stream" "processed_stream" {
  name             = "${local.name_prefix}-processed-stream"
  shard_count      = 1
  retention_period = 24

  encryption_type = "KMS"
  kms_key_id      = aws_kinesis_key.stream_key.arn

  tags = local.common_tags
}

resource "aws_iam_role" "kinesis_analytics_role" {
  name = "${local.name_prefix}-kinesis-analytics-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "kinesisanalytics.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "kinesis_analytics_policy" {
  name = "${local.name_prefix}-kinesis-analytics-policy"
  role = aws_iam_role.kinesis_analytics_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kinesis:DescribeStream",
          "kinesis:GetShardIterator",
          "kinesis:GetRecords",
          "kinesis:ListShards"
        ]
        Resource = [
          aws_kinesis_stream.data_stream.arn,
          aws_kinesis_stream.processed_stream.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kinesis:PutRecord",
          "kinesis:PutRecords"
        ]
        Resource = aws_kinesis_stream.processed_stream.arn
      }
    ]
  })
}

# Redshift Cluster
resource "aws_redshift_cluster" "analytics_cluster" {
  cluster_identifier = "${local.name_prefix}-cluster"
  database_name      = "analytics"
  master_username    = "admin"
  master_password    = var.redshift_password
  node_type          = "dc2.large"
  cluster_type       = "single-node"

  vpc_security_group_ids = [aws_security_group.redshift_sg.id]
  cluster_subnet_group_name = aws_redshift_subnet_group.analytics_subnet_group.name

  skip_final_snapshot = true
  encrypted           = true
  kms_key_id          = aws_kms_key.analytics_key.arn

  iam_roles = [aws_iam_role.redshift_role.arn]

  tags = local.common_tags
}

resource "aws_redshift_subnet_group" "analytics_subnet_group" {
  name       = "${local.name_prefix}-redshift-subnet-group"
  subnet_ids = aws_subnet.database_subnets[*].id

  tags = local.common_tags
}

# Glue Data Catalog
resource "aws_glue_catalog_database" "analytics_db" {
  name = "${local.name_prefix}_database"

  tags = local.common_tags
}

resource "aws_glue_catalog_table" "events_table" {
  name          = "events"
  database_name = aws_glue_catalog_database.analytics_db.name

  table_type = "EXTERNAL_TABLE"

  parameters = {
    EXTERNAL                        = "TRUE"
    "parquet.compression"           = "SNAPPY"
    "projection.enabled"            = "true"
    "projection.date.type"          = "date"
    "projection.date.range"         = "2024/01/01,NOW"
    "projection.date.format"        = "yyyy/MM/dd"
    "storage.location.template"     = "s3://${aws_s3_bucket.data_lake.bucket}/events/$${date}/"
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.data_lake.bucket}/events/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      name                  = "events"
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"

      parameters = {
        "serialization.format" = "1"
      }
    }

    columns {
      name = "timestamp"
      type = "timestamp"
    }

    columns {
      name = "user_id"
      type = "string"
    }

    columns {
      name = "event_type"
      type = "string"
    }

    columns {
      name = "value"
      type = "double"
    }

    columns {
      name = "processed_at"
      type = "timestamp"
    }
  }

  tags = local.common_tags
}

# Athena Workgroup
resource "aws_athena_workgroup" "analytics_workgroup" {
  name = "${local.name_prefix}-workgroup"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${aws_s3_bucket.data_lake.bucket}/athena-results/"

      encryption_configuration {
        encryption_option = "SSE_KMS"
        kms_key          = aws_kms_key.analytics_key.arn
      }
    }
  }

  tags = local.common_tags
}

# S3 Buckets for EMR Data Lake and Logs

# S3 Bucket for EMR Data Lake
resource "aws_s3_bucket" "emr_data_lake" {
  bucket = "${local.name_prefix}-data-lake-${random_string.suffix.result}"

  tags = merge(local.common_tags, {
    Name        = "${local.name_prefix}-data-lake"
    Purpose     = "EMR Data Lake"
    DataType    = "Raw and Processed Data"
  })
}

# S3 Bucket Versioning for Data Lake
resource "aws_s3_bucket_versioning" "emr_data_lake_versioning" {
  bucket = aws_s3_bucket.emr_data_lake.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket Encryption for Data Lake
resource "aws_s3_bucket_server_side_encryption_configuration" "emr_data_lake_encryption" {
  count  = var.enable_encryption ? 1 : 0
  bucket = aws_s3_bucket.emr_data_lake.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# S3 Bucket for EMR Logs
resource "aws_s3_bucket" "emr_logs" {
  bucket = "${local.name_prefix}-logs-${random_string.suffix.result}"

  tags = merge(local.common_tags, {
    Name        = "${local.name_prefix}-logs"
    Purpose     = "EMR Cluster Logs"
    DataType    = "Log Files"
  })
}

# S3 Bucket Versioning for Logs
resource "aws_s3_bucket_versioning" "emr_logs_versioning" {
  bucket = aws_s3_bucket.emr_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket Encryption for Logs
resource "aws_s3_bucket_server_side_encryption_configuration" "emr_logs_encryption" {
  count  = var.enable_encryption ? 1 : 0
  bucket = aws_s3_bucket.emr_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# S3 Bucket for Spark Scripts
resource "aws_s3_bucket" "emr_scripts" {
  bucket = "${local.name_prefix}-scripts-${random_string.suffix.result}"

  tags = merge(local.common_tags, {
    Name        = "${local.name_prefix}-scripts"
    Purpose     = "Spark Scripts and JARs"
    DataType    = "Application Code"
  })
}

# S3 Bucket Versioning for Scripts
resource "aws_s3_bucket_versioning" "emr_scripts_versioning" {
  bucket = aws_s3_bucket.emr_scripts.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket Encryption for Scripts
resource "aws_s3_bucket_server_side_encryption_configuration" "emr_scripts_encryption" {
  count  = var.enable_encryption ? 1 : 0
  bucket = aws_s3_bucket.emr_scripts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# S3 Bucket Lifecycle Configuration for Logs
resource "aws_s3_bucket_lifecycle_configuration" "emr_logs_lifecycle" {
  bucket = aws_s3_bucket.emr_logs.id

  rule {
    id     = "log_retention"
    status = "Enabled"

    expiration {
      days = var.log_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}

# S3 Bucket Public Access Block
resource "aws_s3_bucket_public_access_block" "emr_data_lake_pab" {
  bucket = aws_s3_bucket.emr_data_lake.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "emr_logs_pab" {
  bucket = aws_s3_bucket.emr_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "emr_scripts_pab" {
  bucket = aws_s3_bucket.emr_scripts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

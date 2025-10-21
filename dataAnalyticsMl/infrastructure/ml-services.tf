# SageMaker Model
resource "aws_sagemaker_model" "ml_model" {
  name               = "${local.name_prefix}-model"
  execution_role_arn = aws_iam_role.sagemaker_role.arn

  primary_container {
    image = "683313688378.dkr.ecr.us-east-1.amazonaws.com/sagemaker-scikit-learn:1.0-1-cpu-py3"
    
    model_data_url = "s3://${aws_s3_bucket.ml_artifacts.bucket}/model/model.tar.gz"
    
    environment = {
      SAGEMAKER_PROGRAM = "inference.py"
      SAGEMAKER_SUBMIT_DIRECTORY = "s3://${aws_s3_bucket.ml_artifacts.bucket}/model/model.tar.gz"
    }
  }

  tags = local.common_tags
}

# SageMaker Endpoint Configuration
resource "aws_sagemaker_endpoint_configuration" "ml_endpoint_config" {
  name = "${local.name_prefix}-endpoint-config"

  production_variants {
    variant_name           = "primary"
    model_name            = aws_sagemaker_model.ml_model.name
    initial_instance_count = 1
    instance_type         = "ml.t2.medium"
    initial_variant_weight = 100
  }

  tags = local.common_tags
}

# SageMaker Endpoint
resource "aws_sagemaker_endpoint" "ml_endpoint" {
  name                 = "${local.name_prefix}-endpoint"
  endpoint_config_name = aws_sagemaker_endpoint_configuration.ml_endpoint_config.name

  tags = local.common_tags
}

# SageMaker IAM Role
resource "aws_iam_role" "sagemaker_role" {
  name = "${local.name_prefix}-sagemaker-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "sagemaker.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "sagemaker_execution_policy" {
  role       = aws_iam_role.sagemaker_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
}

resource "aws_iam_role_policy" "sagemaker_s3_policy" {
  name = "${local.name_prefix}-sagemaker-s3-policy"
  role = aws_iam_role.sagemaker_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.ml_artifacts.arn,
          "${aws_s3_bucket.ml_artifacts.arn}/*"
        ]
      }
    ]
  })
}

# S3 Bucket for ML Artifacts
resource "aws_s3_bucket" "ml_artifacts" {
  bucket = "${local.name_prefix}-ml-artifacts-${random_string.ml_bucket_suffix.result}"

  tags = local.common_tags
}

resource "random_string" "ml_bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket_versioning" "ml_artifacts_versioning" {
  bucket = aws_s3_bucket.ml_artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_encryption" "ml_artifacts_encryption" {
  bucket = aws_s3_bucket.ml_artifacts.id

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.analytics_key.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }
}

# SageMaker Processing Job
resource "aws_sagemaker_processing_job" "data_processing_job" {
  name         = "${local.name_prefix}-processing-job"
  role_arn     = aws_iam_role.sagemaker_role.arn
  processing_job_name = "${local.name_prefix}-processing-job"

  processing_resources {
    cluster_config {
      instance_count  = 1
      instance_type   = "ml.t3.medium"
      volume_size_in_gb = 30
    }
  }

  app_specification {
    image_uri = "683313688378.dkr.ecr.us-east-1.amazonaws.com/sagemaker-scikit-learn:1.0-1-cpu-py3"
  }

  tags = local.common_tags
}

# QuickSight Data Source
resource "aws_quicksight_data_source" "redshift_datasource" {
  data_source_id = "${local.name_prefix}-redshift-datasource"
  name           = "${local.name_prefix}-redshift-datasource"

  parameters {
    redshift {
      cluster_id = aws_redshift_cluster.analytics_cluster.cluster_identifier
      database   = aws_redshift_cluster.analytics_cluster.database_name
      host       = aws_redshift_cluster.analytics_cluster.endpoint
      port       = aws_redshift_cluster.analytics_cluster.port
    }
  }

  type = "REDSHIFT"

  tags = local.common_tags
}

# QuickSight Dataset
resource "aws_quicksight_data_set" "analytics_dataset" {
  data_set_id = "${local.name_prefix}-dataset"
  name        = "${local.name_prefix}-dataset"

  physical_table_map {
    physical_table_map_id = "events_table"
    
    redshift_physical_table {
      cluster_id = aws_redshift_cluster.analytics_cluster.cluster_identifier
      schema_name = "public"
      table_name  = "events"
    }
  }

  import_mode = "DIRECT_QUERY"

  tags = local.common_tags
}

# QuickSight Dashboard
resource "aws_quicksight_dashboard" "analytics_dashboard" {
  dashboard_id = "${local.name_prefix}-dashboard"
  name         = "${local.name_prefix}-dashboard"

  definition {
    data_set_identifier_declarations {
      data_set_arn = aws_quicksight_data_set.analytics_dataset.arn
      data_set_identifier = "events_dataset"
    }

    sheets {
      sheet_id = "events_sheet"
      name     = "Events Analysis"

      visuals {
        visual_id = "events_chart"
        line_chart_visual {
          visual_id = "events_chart"
          title {
            visibility = "VISIBLE"
            format_text {
              plain_text = "Events Over Time"
            }
          }
          chart_configuration {
            field_wells {
              line_chart_aggregated_field_wells {
                category {
                  categorical_dimension_field {
                    field_id = "timestamp"
                    column {
                      data_set_identifier = "events_dataset"
                      column_name = "timestamp"
                    }
                  }
                }
                values {
                  numerical_measure_field {
                    field_id = "value"
                    column {
                      data_set_identifier = "events_dataset"
                      column_name = "value"
                    }
                    aggregation_function {
                      simple_numerical_aggregation = "SUM"
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  tags = local.common_tags
}

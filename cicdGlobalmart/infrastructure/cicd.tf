# S3 Bucket for CodeDeploy artifacts
resource "aws_s3_bucket" "codedeploy_bucket" {
  bucket = "globalmart-codedeploy-${random_string.bucket_suffix.result}"

  tags = {
    Name = "globalmart-codedeploy-bucket"
    Project = "globalmart-cicd"
  }
}

resource "aws_s3_bucket_versioning" "codedeploy_bucket_versioning" {
  bucket = aws_s3_bucket.codedeploy_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "codedeploy_bucket_encryption" {
  bucket = aws_s3_bucket.codedeploy_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Random string for bucket suffix
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# CodeBuild Service Role
resource "aws_iam_role" "codebuild_role" {
  name = "globalmart-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "globalmart-codebuild-role"
    Project = "globalmart-cicd"
  }
}

# CodeBuild Policy
resource "aws_iam_role_policy" "codebuild_policy" {
  name = "globalmart-codebuild-policy"
  role = aws_iam_role.codebuild_role.id

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
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          aws_s3_bucket.codedeploy_bucket.arn,
          "${aws_s3_bucket.codedeploy_bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.codedeploy_bucket.arn
      }
    ]
  })
}

# CodeBuild Project
resource "aws_codebuild_project" "globalmart_build" {
  name          = "globalmart-build"
  description   = "Build project for GlobalMart application"
  service_role  = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                      = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type                       = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "NODE_ENV"
      value = "production"
    }
  }

  source {
    type = "CODEPIPELINE"
    buildspec = "buildspec.yml"
  }

  tags = {
    Name = "globalmart-build"
    Project = "globalmart-cicd"
  }
}

# CodeDeploy Application
resource "aws_codedeploy_app" "globalmart_app" {
  compute_platform = "Server"
  name             = "globalmart-app"

  tags = {
    Name = "globalmart-app"
    Project = "globalmart-cicd"
  }
}

# CodeDeploy Deployment Group
resource "aws_codedeploy_deployment_group" "globalmart_dg" {
  app_name              = aws_codedeploy_app.globalmart_app.name
  deployment_group_name = "globalmart-dg"
  service_role_arn      = aws_iam_role.codedeploy_role.arn

  autoscaling_groups = [aws_autoscaling_group.globalmart_asg.name]

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  load_balancer_info {
    target_group_info {
      name = aws_lb_target_group.globalmart_tg.name
    }
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  tags = {
    Name = "globalmart-dg"
    Project = "globalmart-cicd"
  }
}

# CodeDeploy Service Role
resource "aws_iam_role" "codedeploy_role" {
  name = "globalmart-codedeploy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codedeploy.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "globalmart-codedeploy-role"
    Project = "globalmart-cicd"
  }
}

# Attach CodeDeploy service role policy
resource "aws_iam_role_policy_attachment" "codedeploy_role_policy" {
  role       = aws_iam_role.codedeploy_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
}

# CodePipeline Service Role
resource "aws_iam_role" "codepipeline_role" {
  name = "globalmart-codepipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "globalmart-codepipeline-role"
    Project = "globalmart-cicd"
  }
}

# CodePipeline Policy
resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "globalmart-codepipeline-policy"
  role = aws_iam_role.codepipeline_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject"
        ]
        Resource = [
          aws_s3_bucket.codedeploy_bucket.arn,
          "${aws_s3_bucket.codedeploy_bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.codedeploy_bucket.arn
      },
      {
        Effect = "Allow"
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild"
        ]
        Resource = aws_codebuild_project.globalmart_build.arn
      },
      {
        Effect = "Allow"
        Action = [
          "codedeploy:CreateDeployment",
          "codedeploy:GetApplication",
          "codedeploy:GetApplicationRevision",
          "codedeploy:GetDeployment",
          "codedeploy:GetDeploymentConfig",
          "codedeploy:RegisterApplicationRevision"
        ]
        Resource = "*"
      }
    ]
  })
}

# CodePipeline
resource "aws_codepipeline" "globalmart_pipeline" {
  name     = "globalmart-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.codedeploy_bucket.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "S3"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        S3Bucket    = aws_s3_bucket.codedeploy_bucket.bucket
        S3ObjectKey = "source.zip"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.globalmart_build.name
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      input_artifacts = ["build_output"]
      version         = "1"

      configuration = {
        ApplicationName     = aws_codedeploy_app.globalmart_app.name
        DeploymentGroupName = aws_codedeploy_deployment_group.globalmart_dg.deployment_group_name
      }
    }
  }

  tags = {
    Name = "globalmart-pipeline"
    Project = "globalmart-cicd"
  }
}

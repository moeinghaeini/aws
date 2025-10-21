# ECR Repository for LMS Frontend
resource "aws_ecr_repository" "lms_frontend" {
  name                 = "lms-frontend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "lms-frontend-ecr"
    Project = "lms-ecs"
  }
}

# ECR Lifecycle Policy
resource "aws_ecr_lifecycle_policy" "lms_frontend_policy" {
  repository = aws_ecr_repository.lms_frontend.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Delete untagged images older than 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

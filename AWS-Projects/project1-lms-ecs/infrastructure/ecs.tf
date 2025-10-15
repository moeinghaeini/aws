# ECS Cluster
resource "aws_ecs_cluster" "lms_cluster" {
  name = "lms-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "lms-cluster"
    Project = "lms-ecs"
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "lms_task" {
  family                   = "lms-frontend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "lms-frontend"
      image = "${aws_ecr_repository.lms_frontend.repository_url}:latest"
      
      portMappings = [
        {
          containerPort = 80
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.lms_logs.name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "ecs"
        }
      }

      healthCheck = {
        command = [
          "CMD-SHELL",
          "curl -f http://localhost/health || exit 1"
        ]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }

      essential = true
    }
  ])

  tags = {
    Name = "lms-frontend-task"
    Project = "lms-ecs"
  }
}

# ECS Service
resource "aws_ecs_service" "lms_service" {
  name            = "lms-service"
  cluster         = aws_ecs_cluster.lms_cluster.id
  task_definition = aws_ecs_task_definition.lms_task.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.lms_tg.arn
    container_name   = "lms-frontend"
    container_port   = 80
  }

  depends_on = [aws_lb_listener.lms_listener]

  tags = {
    Name = "lms-service"
    Project = "lms-ecs"
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "lms_logs" {
  name              = "/ecs/lms-frontend"
  retention_in_days = 7

  tags = {
    Name = "lms-logs"
    Project = "lms-ecs"
  }
}

# Data source for current region
data "aws_region" "current" {}

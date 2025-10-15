# Application Load Balancer
resource "aws_lb" "lms_alb" {
  name               = "lms-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]

  enable_deletion_protection = false

  tags = {
    Name = "lms-alb"
    Project = "lms-ecs"
  }
}

# Target Group for ECS Tasks
resource "aws_lb_target_group" "lms_tg" {
  name        = "lms-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.lms_vpc.id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/health"
    matcher             = "200"
    port                = "traffic-port"
    protocol            = "HTTP"
  }

  tags = {
    Name = "lms-tg"
    Project = "lms-ecs"
  }
}

# ALB Listener
resource "aws_lb_listener" "lms_listener" {
  load_balancer_arn = aws_lb.lms_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lms_tg.arn
  }

  tags = {
    Name = "lms-listener"
    Project = "lms-ecs"
  }
}

# Output ALB DNS name
output "alb_dns_name" {
  description = "DNS name of the load balancer"
  value       = aws_lb.lms_alb.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the load balancer"
  value       = aws_lb.lms_alb.zone_id
}

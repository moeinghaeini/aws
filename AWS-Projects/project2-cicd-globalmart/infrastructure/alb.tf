# Application Load Balancer
resource "aws_lb" "globalmart_alb" {
  name               = "globalmart-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]

  enable_deletion_protection = false

  tags = {
    Name = "globalmart-alb"
    Project = "globalmart-cicd"
  }
}

# Target Group for EC2 Instances
resource "aws_lb_target_group" "globalmart_tg" {
  name        = "globalmart-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.globalmart_vpc.id
  target_type = "instance"

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
    Name = "globalmart-tg"
    Project = "globalmart-cicd"
  }
}

# ALB Listener
resource "aws_lb_listener" "globalmart_listener" {
  load_balancer_arn = aws_lb.globalmart_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.globalmart_tg.arn
  }

  tags = {
    Name = "globalmart-listener"
    Project = "globalmart-cicd"
  }
}

# Output ALB DNS name
output "alb_dns_name" {
  description = "DNS name of the load balancer"
  value       = aws_lb.globalmart_alb.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the load balancer"
  value       = aws_lb.globalmart_alb.zone_id
}

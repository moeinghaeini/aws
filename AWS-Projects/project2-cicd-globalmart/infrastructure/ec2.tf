# Launch Template
resource "aws_launch_template" "globalmart_lt" {
  name_prefix   = "globalmart-lt"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }
  
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    db_endpoint = aws_db_instance.globalmart_db.endpoint
    db_name     = aws_db_instance.globalmart_db.db_name
    db_username = aws_db_instance.globalmart_db.username
    db_password = var.db_password
  }))
  
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "globalmart-instance"
      Project = "globalmart-cicd"
    }
  }
  
  tags = {
    Name = "globalmart-launch-template"
    Project = "globalmart-cicd"
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "globalmart_asg" {
  name                = "globalmart-asg"
  vpc_zone_identifier = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
  target_group_arns   = [aws_lb_target_group.globalmart_tg.arn]
  health_check_type   = "ELB"
  health_check_grace_period = 300
  
  min_size         = 2
  max_size         = 4
  desired_capacity = 2
  
  launch_template {
    id      = aws_launch_template.globalmart_lt.id
    version = "$Latest"
  }
  
  tag {
    key                 = "Name"
    value               = "globalmart-asg-instance"
    propagate_at_launch = true
  }
  
  tag {
    key                 = "Project"
    value               = "globalmart-cicd"
    propagate_at_launch = true
  }
}

# Auto Scaling Policy - Scale Out
resource "aws_autoscaling_policy" "scale_out" {
  name                   = "globalmart-scale-out"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.globalmart_asg.name
}

# Auto Scaling Policy - Scale In
resource "aws_autoscaling_policy" "scale_in" {
  name                   = "globalmart-scale-in"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.globalmart_asg.name
}

# CloudWatch Alarm - High CPU
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "globalmart-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ec2 cpu utilization"
  alarm_actions       = [aws_autoscaling_policy.scale_out.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.globalmart_asg.name
  }
}

# CloudWatch Alarm - Low CPU
resource "aws_cloudwatch_metric_alarm" "low_cpu" {
  alarm_name          = "globalmart-low-cpu"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "20"
  alarm_description   = "This metric monitors ec2 cpu utilization"
  alarm_actions       = [aws_autoscaling_policy.scale_in.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.globalmart_asg.name
  }
}

# Data source for Amazon Linux AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

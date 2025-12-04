# Compute Module - Creates EC2 instances and Application Load Balancer

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Get latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
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

# Create Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = var.environment == "prod" ? true : false

  tags = {
    Name        = "${var.environment}-alb"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Create ALB Target Group
resource "aws_lb_target_group" "main" {
  name        = "${var.environment}-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 30
    path                = "/"
    matcher             = "200"
  }

  tags = {
    Name        = "${var.environment}-tg"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Create ALB Listener
resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

# Create HTTPS listener (if certificate ARN provided)
resource "aws_lb_listener" "https" {
  count             = var.certificate_arn != "" ? 1 : 0
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

# Create HTTP to HTTPS redirect (if certificate provided)
resource "aws_lb_listener" "http_redirect" {
  count             = var.certificate_arn != "" ? 1 : 0
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# Create Launch Template for EC2 instances
resource "aws_launch_template" "main" {
  name_prefix   = "${var.environment}-lt-"
  image_id      = data.aws_ami.amazon_linux_2.id
  instance_type = var.instance_type

  iam_instance_profile {
    name = var.ec2_instance_profile_name
  }

  vpc_security_group_ids = [var.ec2_security_group_id]

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    environment = var.environment
    s3_bucket   = var.s3_bucket_name
    region      = data.aws_region.current.name
  }))

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name        = "${var.environment}-instance"
      Environment = var.environment
      Project     = var.project_name
    }
  }

  tag_specifications {
    resource_type = "volume"

    tags = {
      Name        = "${var.environment}-volume"
      Environment = var.environment
      Project     = var.project_name
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Create Auto Scaling Group
resource "aws_autoscaling_group" "main" {
  name                = "${var.environment}-asg"
  vpc_zone_identifier = var.private_subnet_ids
  target_group_arns   = [aws_lb_target_group.main.arn]
  health_check_type   = "ELB"
  health_check_grace_period = 300

  min_size         = var.min_instances
  max_size         = var.max_instances
  desired_capacity = var.desired_instances

  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.environment}-asg-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = var.project_name
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Create CloudWatch Log Group for application logs
resource "aws_cloudwatch_log_group" "app" {
  name              = "/aws/ec2/${var.environment}/app"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.environment}-app-logs"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Create CloudWatch Alarms for ASG
resource "aws_cloudwatch_metric_alarm" "asg_cpu" {
  alarm_name          = "${var.environment}-asg-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 70
  alarm_description   = "Alert when ASG CPU exceeds 70%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.main.name
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy" {
  alarm_name          = "${var.environment}-alb-unhealthy-hosts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "Alert when ALB has unhealthy hosts"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer  = aws_lb.main.arn_suffix
    TargetGroup   = aws_lb_target_group.main.arn_suffix
  }
}

# Data source for current region
data "aws_region" "current" {}

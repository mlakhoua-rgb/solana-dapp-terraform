terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Configure for remote state storage
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "solana-dapp/prod/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-locks"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
      CreatedAt   = timestamp()
    }
  }
}

# VPC Module
module "vpc" {
  source = "../../modules/vpc"

  environment            = var.environment
  project_name           = var.project_name
  vpc_cidr               = var.vpc_cidr
  availability_zones     = var.availability_zones
  public_subnet_cidrs    = var.public_subnet_cidrs
  private_subnet_cidrs   = var.private_subnet_cidrs
  enable_flow_logs       = var.enable_vpc_flow_logs
}

# Security Module
module "security" {
  source = "../../modules/security"

  environment        = var.environment
  project_name       = var.project_name
  vpc_id             = module.vpc.vpc_id
  ssh_cidr_blocks    = var.ssh_cidr_blocks
  s3_bucket_name     = var.s3_bucket_name
}

# Compute Module (ALB + EC2 + ASG)
module "compute" {
  source = "../../modules/compute"

  environment                = var.environment
  project_name               = var.project_name
  vpc_id                     = module.vpc.vpc_id
  public_subnet_ids          = module.vpc.public_subnet_ids
  private_subnet_ids         = module.vpc.private_subnet_ids
  alb_security_group_id      = module.security.alb_security_group_id
  ec2_security_group_id      = module.security.ec2_security_group_id
  ec2_instance_profile_name  = module.security.ec2_instance_profile_name
  instance_type              = var.instance_type
  min_instances              = var.min_instances
  max_instances              = var.max_instances
  desired_instances          = var.desired_instances
  s3_bucket_name             = var.s3_bucket_name
  certificate_arn            = var.certificate_arn
  log_retention_days         = var.log_retention_days
}

# Storage Module (S3 + CloudFront)
module "storage" {
  source = "../../modules/storage"

  environment      = var.environment
  project_name     = var.project_name
  s3_bucket_name   = var.s3_bucket_name
  alb_dns_name     = module.compute.alb_dns_name
  certificate_arn  = var.certificate_arn
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.environment}-solana-dapp"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", { stat = "Average" }],
            [".", "RequestCount", { stat = "Sum" }],
            [".", "HealthyHostCount", { stat = "Average" }],
            [".", "UnHealthyHostCount", { stat = "Average" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "ALB Metrics"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", { stat = "Average" }],
            [".", "NetworkIn", { stat = "Sum" }],
            [".", "NetworkOut", { stat = "Sum" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "EC2 Metrics"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/CloudFront", "Requests", { stat = "Sum" }],
            [".", "BytesDownloaded", { stat = "Sum" }],
            [".", "4xxErrorRate", { stat = "Average" }],
            [".", "5xxErrorRate", { stat = "Average" }]
          ]
          period = 300
          stat   = "Average"
          region = "us-east-1"
          title  = "CloudFront Metrics"
        }
      }
    ]
  })
}

# SNS Topic for alerts
resource "aws_sns_topic" "alerts" {
  name = "${var.environment}-solana-dapp-alerts"

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_sns_topic_subscription" "alerts_email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# CloudWatch Alarms for production
resource "aws_cloudwatch_metric_alarm" "alb_response_time" {
  alarm_name          = "${var.environment}-alb-high-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Average"
  threshold           = 1.0
  alarm_description   = "Alert when ALB response time exceeds 1 second"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = module.compute.alb_arn
  }
}

resource "aws_cloudwatch_metric_alarm" "cloudfront_error_rate" {
  alarm_name          = "${var.environment}-cloudfront-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "5xxErrorRate"
  namespace           = "AWS/CloudFront"
  period              = 300
  statistic           = "Average"
  threshold           = 1.0
  alarm_description   = "Alert when CloudFront 5xx error rate exceeds 1%"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    DistributionId = module.storage.cloudfront_distribution_id
  }
}

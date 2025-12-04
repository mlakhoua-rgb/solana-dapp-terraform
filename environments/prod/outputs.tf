output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.compute.alb_dns_name
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = module.compute.alb_arn
}

output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = module.compute.asg_name
}

output "cloudfront_domain_name" {
  description = "Domain name of the CloudFront distribution"
  value       = module.storage.cloudfront_domain_name
}

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = module.storage.cloudfront_distribution_id
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket"
  value       = module.storage.s3_bucket_id
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group for application logs"
  value       = module.compute.cloudwatch_log_group_name
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  value       = aws_sns_topic.alerts.arn
}

output "application_url" {
  description = "URL to access the application"
  value       = "https://${module.compute.alb_dns_name}"
}

output "cdn_url" {
  description = "URL to access static assets via CloudFront"
  value       = "https://${module.storage.cloudfront_domain_name}"
}

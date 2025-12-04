output "alb_security_group_id" {
  description = "ID of ALB security group"
  value       = aws_security_group.alb.id
}

output "ec2_security_group_id" {
  description = "ID of EC2 security group"
  value       = aws_security_group.ec2.id
}

output "ec2_iam_role_arn" {
  description = "ARN of EC2 IAM role"
  value       = aws_iam_role.ec2_role.arn
}

output "ec2_instance_profile_name" {
  description = "Name of EC2 instance profile"
  value       = aws_iam_instance_profile.ec2_profile.name
}

output "cloudwatch_logs_role_arn" {
  description = "ARN of CloudWatch Logs role"
  value       = aws_iam_role.cloudwatch_logs_role.arn
}

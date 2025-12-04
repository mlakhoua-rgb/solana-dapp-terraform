variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "solana-dapp"
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket for assets"
  type        = string
  validation {
    condition     = length(var.s3_bucket_name) >= 3 && length(var.s3_bucket_name) <= 63
    error_message = "S3 bucket name must be between 3 and 63 characters."
  }
}

variable "alb_dns_name" {
  description = "DNS name of the ALB"
  type        = string
}

variable "certificate_arn" {
  description = "ARN of ACM certificate for HTTPS (optional)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "solana-dapp"
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "ssh_cidr_blocks" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/32"] # Should be restricted to your IP
}

variable "s3_bucket_name" {
  description = "S3 bucket name for EC2 access"
  type        = string
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}

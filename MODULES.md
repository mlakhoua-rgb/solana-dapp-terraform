# Terraform Modules Documentation

This document provides detailed documentation for each Terraform module used in the Solana dApp infrastructure.

---

## Module Architecture

The infrastructure is organized into four modular components, each handling a specific aspect of the AWS infrastructure:

```
Root Configuration (environments/{dev,prod})
├── VPC Module (networking)
├── Security Module (security groups & IAM)
├── Compute Module (ALB, EC2, ASG)
└── Storage Module (S3, CloudFront)
```

---

## VPC Module

**Location**: `modules/vpc/`

### Purpose

The VPC module creates the foundational networking infrastructure for the Solana dApp, including virtual private cloud, subnets across multiple availability zones, internet connectivity, and network monitoring.

### Resources Created

| Resource | Count | Purpose |
|----------|-------|---------|
| VPC | 1 | Main network container |
| Public Subnets | 2-3 | ALB and NAT Gateway placement |
| Private Subnets | 2-3 | EC2 instance placement |
| Internet Gateway | 1 | Public internet access |
| NAT Gateways | 2-3 | Secure outbound access from private subnets |
| Route Tables | 4-6 | Traffic routing rules |
| VPC Flow Logs | 1 | Network traffic monitoring |

### Variables

```hcl
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
}

variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs"
  type        = bool
  default     = true
}
```

### Outputs

```hcl
output "vpc_id"                    # VPC identifier
output "vpc_cidr"                  # VPC CIDR block
output "public_subnet_ids"         # List of public subnet IDs
output "private_subnet_ids"        # List of private subnet IDs
output "internet_gateway_id"       # IGW identifier
output "nat_gateway_ids"           # List of NAT Gateway IDs
output "public_route_table_id"     # Public route table ID
output "private_route_table_ids"   # List of private route table IDs
output "availability_zones"        # AZs used
```

### Usage Example

```hcl
module "vpc" {
  source = "../../modules/vpc"

  environment            = "dev"
  vpc_cidr               = "10.0.0.0/16"
  availability_zones     = ["us-east-1a", "us-east-1b"]
  public_subnet_cidrs    = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs   = ["10.0.11.0/24", "10.0.12.0/24"]
  enable_flow_logs       = true
}
```

### Network Topology

```
Internet
    |
    ↓
Internet Gateway
    |
    ├─→ Public Subnet (ALB)
    |      ↓
    |   NAT Gateway
    |      ↓
    └─→ Private Subnet (EC2)
```

---

## Security Module

**Location**: `modules/security/`

### Purpose

The Security module manages all security-related infrastructure including security groups for network access control, IAM roles for service permissions, and instance profiles for EC2 integration.

### Resources Created

| Resource | Count | Purpose |
|----------|-------|---------|
| ALB Security Group | 1 | Control ALB traffic |
| EC2 Security Group | 1 | Control EC2 traffic |
| EC2 IAM Role | 1 | EC2 service permissions |
| EC2 IAM Policy | 1 | S3 and CloudWatch access |
| EC2 Instance Profile | 1 | Attach role to instances |
| CloudWatch Logs Role | 1 | Log streaming permissions |
| SSM Policy Attachment | 1 | Systems Manager access |

### Security Group Rules

**ALB Security Group**:
- Inbound: HTTP (80) from 0.0.0.0/0
- Inbound: HTTPS (443) from 0.0.0.0/0
- Outbound: All traffic

**EC2 Security Group**:
- Inbound: Port 3000 from ALB
- Inbound: SSH (22) from specified CIDR blocks
- Outbound: All traffic

### IAM Permissions

**EC2 Role Permissions**:
- S3: GetObject, ListBucket on application bucket
- CloudWatch: PutMetricData, CreateLogGroup, CreateLogStream, PutLogEvents
- SSM: GetParameter, GetParameters, GetParametersByPath
- Systems Manager: Full access for Session Manager

### Variables

```hcl
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "ssh_cidr_blocks" {
  description = "CIDR blocks allowed for SSH"
  type        = list(string)
  default     = ["0.0.0.0/32"]
}

variable "s3_bucket_name" {
  description = "S3 bucket name for EC2 access"
  type        = string
}
```

### Outputs

```hcl
output "alb_security_group_id"      # ALB SG identifier
output "ec2_security_group_id"      # EC2 SG identifier
output "ec2_iam_role_arn"           # EC2 role ARN
output "ec2_instance_profile_name"  # Instance profile name
output "cloudwatch_logs_role_arn"   # CloudWatch role ARN
```

### Usage Example

```hcl
module "security" {
  source = "../../modules/security"

  environment     = "dev"
  vpc_id          = module.vpc.vpc_id
  ssh_cidr_blocks = ["203.0.113.0/32"]
  s3_bucket_name  = "solana-dapp-dev-assets"
}
```

---

## Compute Module

**Location**: `modules/compute/`

### Purpose

The Compute module manages all compute resources including the Application Load Balancer, Auto Scaling Group, EC2 instances, and monitoring infrastructure.

### Resources Created

| Resource | Count | Purpose |
|----------|-------|---------|
| ALB | 1 | Load balancing |
| Target Group | 1 | ALB routing |
| ALB Listeners | 1-2 | HTTP/HTTPS listeners |
| Launch Template | 1 | EC2 configuration |
| Auto Scaling Group | 1 | Dynamic scaling |
| CloudWatch Log Group | 1 | Application logs |
| CloudWatch Alarms | 2-4 | Monitoring |

### Auto Scaling Configuration

The Auto Scaling Group automatically manages instance count based on CPU utilization:

- **Scale Up**: When average CPU > 70% for 2 consecutive 5-minute periods
- **Scale Down**: When average CPU < 30% for 2 consecutive 5-minute periods
- **Cooldown**: 300 seconds between scaling actions

### Health Checks

- **Type**: ELB (Elastic Load Balancing)
- **Grace Period**: 300 seconds
- **Healthy Threshold**: 2 successful checks
- **Unhealthy Threshold**: 2 failed checks
- **Interval**: 30 seconds
- **Timeout**: 3 seconds

### User Data Script

The launch template includes a user_data script that:
1. Updates system packages
2. Installs Node.js and pnpm
3. Clones the Solana dApp repository
4. Installs dependencies with pnpm
5. Builds the application
6. Creates a systemd service for auto-start
7. Configures CloudWatch agent

### Variables

```hcl
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for ALB"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for EC2"
  type        = list(string)
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "min_instances" {
  description = "Minimum instances"
  type        = number
  default     = 2
}

variable "max_instances" {
  description = "Maximum instances"
  type        = number
  default     = 6
}

variable "desired_instances" {
  description = "Desired instances"
  type        = number
  default     = 2
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS"
  type        = string
  default     = ""
}

variable "log_retention_days" {
  description = "CloudWatch log retention"
  type        = number
  default     = 30
}
```

### Outputs

```hcl
output "alb_dns_name"           # ALB DNS name
output "alb_arn"                # ALB ARN
output "target_group_arn"       # Target group ARN
output "asg_name"               # ASG name
output "asg_arn"                # ASG ARN
output "launch_template_id"     # Launch template ID
output "cloudwatch_log_group_name"  # Log group name
```

### Usage Example

```hcl
module "compute" {
  source = "../../modules/compute"

  environment               = "dev"
  vpc_id                    = module.vpc.vpc_id
  public_subnet_ids         = module.vpc.public_subnet_ids
  private_subnet_ids        = module.vpc.private_subnet_ids
  alb_security_group_id     = module.security.alb_security_group_id
  ec2_security_group_id     = module.security.ec2_security_group_id
  ec2_instance_profile_name = module.security.ec2_instance_profile_name
  instance_type             = "t3.medium"
  min_instances             = 1
  max_instances             = 2
  desired_instances         = 1
  s3_bucket_name            = "solana-dapp-dev-assets"
}
```

---

## Storage Module

**Location**: `modules/storage/`

### Purpose

The Storage module manages static asset storage and content delivery including S3 buckets, CloudFront distribution, and lifecycle policies.

### Resources Created

| Resource | Count | Purpose |
|----------|-------|---------|
| S3 Assets Bucket | 1 | Static asset storage |
| S3 Logs Bucket | 1 | Access log storage |
| S3 Versioning | 2 | Asset version management |
| S3 Encryption | 2 | Data encryption |
| S3 Lifecycle Policies | 2 | Automatic cleanup |
| CloudFront OAI | 1 | Secure S3 access |
| CloudFront Distribution | 1 | Global content delivery |
| Bucket Policies | 2 | Access control |

### S3 Lifecycle Policies

**Assets Bucket**:
- Delete old versions after 90 days
- Delete incomplete multipart uploads after 7 days

**Logs Bucket**:
- Delete logs after 90 days

### CloudFront Configuration

**Origins**:
1. S3 bucket for static assets
2. ALB for dynamic content

**Cache Behaviors**:
- `/assets/*`: 1 year cache (static assets)
- `*.{js,css,png,jpg,etc}`: 1 year cache (build artifacts)
- `/`: No cache (dynamic content from ALB)

**Compression**: Enabled for text-based content

### Variables

```hcl
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "s3_bucket_name" {
  description = "S3 bucket name"
  type        = string
}

variable "alb_dns_name" {
  description = "ALB DNS name"
  type        = string
}

variable "certificate_arn" {
  description = "ACM certificate ARN"
  type        = string
  default     = ""
}
```

### Outputs

```hcl
output "s3_bucket_id"                  # S3 bucket name
output "s3_bucket_arn"                 # S3 bucket ARN
output "s3_bucket_regional_domain_name" # S3 regional domain
output "cloudfront_distribution_id"    # CloudFront distribution ID
output "cloudfront_domain_name"        # CloudFront domain
output "cloudfront_distribution_arn"   # CloudFront ARN
output "logs_bucket_id"                # Logs bucket name
```

### Usage Example

```hcl
module "storage" {
  source = "../../modules/storage"

  environment     = "dev"
  s3_bucket_name  = "solana-dapp-dev-assets"
  alb_dns_name    = module.compute.alb_dns_name
  certificate_arn = var.certificate_arn
}
```

---

## Module Composition

The modules are composed in the root configuration files (`environments/{dev,prod}/main.tf`) to create the complete infrastructure:

```hcl
# 1. Create networking
module "vpc" { ... }

# 2. Create security infrastructure
module "security" {
  depends_on = [module.vpc]
}

# 3. Create compute resources
module "compute" {
  depends_on = [module.vpc, module.security]
}

# 4. Create storage and CDN
module "storage" {
  depends_on = [module.compute]
}
```

---

## Module Customization

### Extending Modules

To add new resources to a module:

1. Add resource definition to `main.tf`
2. Add variables to `variables.tf` if needed
3. Add outputs to `outputs.tf`
4. Update documentation

### Creating New Modules

To create a new module:

```bash
mkdir -p modules/new-module
touch modules/new-module/{main.tf,variables.tf,outputs.tf}
```

Then reference in root configuration:

```hcl
module "new_module" {
  source = "../../modules/new-module"
  # ... variables
}
```

---

## Module Dependencies

```
VPC Module
├── Security Module
│   └── Compute Module
│       └── Storage Module
```

All modules depend on the VPC module for networking infrastructure. The Security module provides IAM and security groups for Compute. The Storage module depends on Compute for the ALB DNS name.

---

## Best Practices

1. **Keep modules focused**: Each module should have a single responsibility
2. **Use descriptive names**: Variable and output names should clearly indicate purpose
3. **Validate inputs**: Use variable validation blocks for constraints
4. **Document thoroughly**: Include comments and usage examples
5. **Version modules**: Tag releases for reproducibility
6. **Test modules**: Validate with `terraform validate` and `terraform plan`

---

**Last Updated**: December 2025

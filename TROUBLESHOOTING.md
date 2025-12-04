# Troubleshooting Guide

This guide provides solutions for common issues encountered during Terraform deployment and infrastructure management.

---

## Terraform Initialization Issues

### Error: "Error: error configuring S3 Backend"

**Symptoms**: Terraform init fails with S3 backend configuration error

**Causes**:
- Invalid AWS credentials
- Insufficient IAM permissions
- S3 bucket doesn't exist

**Solutions**:

```bash
# Verify AWS credentials
aws sts get-caller-identity

# Check IAM permissions
aws iam get-user

# For local state (development)
# Remove backend configuration from main.tf temporarily
terraform init -backend=false
```

---

### Error: "Error: Incompatible Terraform Version"

**Symptoms**: "Error: Unsupported Terraform Core version"

**Causes**:
- Terraform version is older than required
- Version constraint in terraform block is too strict

**Solutions**:

```bash
# Check current Terraform version
terraform version

# Upgrade Terraform
# On macOS with Homebrew
brew upgrade terraform

# On Linux
wget https://releases.hashicorp.com/terraform/1.5.0/terraform_1.5.0_linux_amd64.zip
unzip terraform_1.5.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/
```

---

### Error: "Error: Failed to download module"

**Symptoms**: "Error downloading module from registry.terraform.io"

**Causes**:
- Network connectivity issues
- Registry is temporarily unavailable
- Invalid module source

**Solutions**:

```bash
# Clear Terraform cache
rm -rf .terraform/

# Retry initialization
terraform init

# Use local modules instead
# In main.tf, change:
# source = "hashicorp/aws/aws"
# to:
# source = "./modules/vpc"
```

---

## AWS Credential Issues

### Error: "Error: error configuring Terraform AWS Provider"

**Symptoms**: "The AWS Access Key Id you provided does not exist in our records"

**Causes**:
- Invalid AWS credentials
- Credentials are expired
- Wrong AWS region

**Solutions**:

```bash
# Configure credentials using AWS CLI
aws configure

# Or set environment variables
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"

# Verify configuration
aws sts get-caller-identity
```

---

### Error: "UnauthorizedOperation: You are not authorized to perform"

**Symptoms**: Terraform apply fails with authorization error

**Causes**:
- IAM user lacks required permissions
- Resource-based policy denies access
- Service quota exceeded

**Solutions**:

```bash
# Check IAM permissions
aws iam get-user-policy --user-name your-user --policy-name your-policy

# Attach required policy
aws iam attach-user-policy \
  --user-name your-user \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

# Check service quotas
aws service-quotas list-service-quotas \
  --service-code ec2 \
  --query 'ServiceQuotas[?ServiceQuotaName==`Running On-Demand t3 instances`]'
```

---

## VPC and Networking Issues

### Error: "Error: InvalidParameterValue: Invalid CIDR"

**Symptoms**: VPC creation fails with invalid CIDR error

**Causes**:
- CIDR block is malformed
- CIDR block overlaps with existing VPCs
- CIDR block is too small

**Solutions**:

```hcl
# Ensure valid CIDR format
vpc_cidr = "10.0.0.0/16"  # Valid
# vpc_cidr = "10.0.0.0/33"  # Invalid (too small)
# vpc_cidr = "10.0.0.0"     # Invalid (missing prefix)

# Check for overlapping VPCs
aws ec2 describe-vpcs --query 'Vpcs[].CidrBlock'
```

---

### Error: "Error: InvalidSubnetConflict.Mismatch"

**Symptoms**: Subnet creation fails with conflict error

**Causes**:
- Subnet CIDR overlaps with another subnet
- Subnet CIDR is not within VPC CIDR
- Multiple subnets in same AZ with same CIDR

**Solutions**:

```bash
# Check existing subnets
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=vpc-12345678" \
  --query 'Subnets[].{CIDR:CidrBlock,AZ:AvailabilityZone}'

# Verify subnet CIDR is within VPC CIDR
# VPC: 10.0.0.0/16
# Subnet: 10.0.1.0/24  # Valid
# Subnet: 10.1.0.0/24  # Invalid (outside VPC CIDR)
```

---

## Security Group Issues

### Error: "Error: InvalidGroupId.NotFound"

**Symptoms**: Security group reference fails with not found error

**Causes**:
- Security group doesn't exist
- Security group is in different VPC
- Typo in security group ID

**Solutions**:

```bash
# List security groups
aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=vpc-12345678" \
  --query 'SecurityGroups[].{ID:GroupId,Name:GroupName}'

# Verify security group exists
aws ec2 describe-security-groups --group-ids sg-12345678
```

---

### Error: "Error: InvalidPermission.Duplicate"

**Symptoms**: Adding security group rule fails with duplicate error

**Causes**:
- Rule already exists
- Similar rule with different CIDR
- Terraform state is out of sync

**Solutions**:

```bash
# Check existing rules
aws ec2 describe-security-groups \
  --group-ids sg-12345678 \
  --query 'SecurityGroups[].IpPermissions'

# Refresh Terraform state
terraform refresh

# Remove and re-add rule
terraform destroy -target aws_security_group_rule.example
terraform apply
```

---

## EC2 and Auto Scaling Issues

### Error: "Error: InvalidAMIID.NotFound"

**Symptoms**: EC2 instance launch fails with AMI not found

**Causes**:
- AMI doesn't exist in region
- AMI ID is incorrect
- AMI is deprecated

**Solutions**:

```bash
# Find latest Amazon Linux 2 AMI
aws ec2 describe-images \
  --owners amazon \
  --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" \
  --query 'Images | sort_by(@, &CreationDate) | [-1]'

# Update launch template with correct AMI ID
# In compute/main.tf, update data source
```

---

### Error: "Error: InvalidInstanceType.NotFound"

**Symptoms**: Instance type not available in region

**Causes**:
- Instance type not available in selected region
- Instance type is deprecated
- Insufficient capacity

**Solutions**:

```bash
# List available instance types
aws ec2 describe-instance-types \
  --region us-east-1 \
  --query 'InstanceTypes[].InstanceType' | grep t3

# Use different instance type
instance_type = "t3.large"  # Change from t3.medium

# Or change region
aws_region = "us-west-2"
```

---

### Error: "Error: EC2 Instance Unhealthy"

**Symptoms**: ALB shows unhealthy targets

**Causes**:
- Application not running
- Health check port not accessible
- Security group blocks health checks
- Application crashes on startup

**Solutions**:

```bash
# Check ALB target health
aws elbv2 describe-target-health \
  --target-group-arn arn:aws:elasticloadbalancing:...

# SSH into instance and check application
aws ssm start-session --target i-0123456789abcdef0

# Inside instance:
sudo systemctl status solana-dapp
sudo systemctl logs solana-dapp -n 50

# Check security group allows port 3000
aws ec2 describe-security-groups --group-ids sg-12345678
```

---

### Error: "Error: Desired capacity is less than minimum capacity"

**Symptoms**: ASG creation fails with capacity mismatch

**Causes**:
- desired_instances < min_instances
- desired_instances > max_instances

**Solutions**:

```hcl
# Ensure proper ordering
min_instances     = 1
desired_instances = 2  # Must be >= min_instances
max_instances     = 4  # Must be >= desired_instances
```

---

## S3 and Storage Issues

### Error: "Error: BucketAlreadyOwnedByYou"

**Symptoms**: S3 bucket creation fails with already owned error

**Causes**:
- Bucket already exists in your account
- Bucket name is globally unique (taken by someone else)

**Solutions**:

```bash
# Check if bucket exists
aws s3api head-bucket --bucket solana-dapp-dev-assets

# Use unique bucket name
s3_bucket_name = "solana-dapp-dev-assets-$(date +%s)"

# Or destroy and recreate
terraform destroy -target aws_s3_bucket.assets
terraform apply
```

---

### Error: "Error: AccessDenied: User is not authorized"

**Symptoms**: S3 operations fail with access denied

**Causes**:
- IAM policy missing S3 permissions
- Bucket policy denies access
- Public access block enabled

**Solutions**:

```bash
# Check bucket policy
aws s3api get-bucket-policy --bucket solana-dapp-dev-assets

# Check public access block
aws s3api get-public-access-block --bucket solana-dapp-dev-assets

# Update IAM policy
aws iam attach-user-policy \
  --user-name your-user \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess
```

---

### Error: "Error: InvalidBucketName"

**Symptoms**: Bucket name validation fails

**Causes**:
- Bucket name contains invalid characters
- Bucket name is too long (>63 characters)
- Bucket name is too short (<3 characters)

**Solutions**:

```hcl
# Valid bucket name format
s3_bucket_name = "solana-dapp-dev-assets"  # Valid
# s3_bucket_name = "Solana-Dapp"  # Invalid (uppercase)
# s3_bucket_name = "solana_dapp"  # Invalid (underscore)
# s3_bucket_name = "solana-dapp-dev-assets-very-long-name-that-exceeds-63-characters"  # Invalid
```

---

## CloudFront Issues

### Error: "Error: InvalidArgument: The parameter OriginPath cannot be empty"

**Symptoms**: CloudFront distribution creation fails

**Causes**:
- Origin configuration is incomplete
- Origin domain name is empty

**Solutions**:

```bash
# Verify S3 bucket exists
aws s3api head-bucket --bucket solana-dapp-dev-assets

# Check bucket regional domain name
aws s3api get-bucket-location --bucket solana-dapp-dev-assets

# Update Terraform with correct domain
alb_dns_name = module.compute.alb_dns_name
```

---

### Error: "Error: CloudFront distribution is not deployed"

**Symptoms**: CloudFront distribution takes a long time to deploy

**Causes**:
- Distribution is still deploying (normal, takes 10-15 minutes)
- Configuration error preventing deployment

**Solutions**:

```bash
# Check distribution status
aws cloudfront get-distribution \
  --id E1234ABCD5678 \
  --query 'Distribution.DistributionConfig.Status'

# Wait for deployment to complete
# This is normal and can take 10-15 minutes

# If stuck, check for errors
aws cloudfront list-distributions \
  --query 'DistributionList.Items[].{ID:Id,Status:Status,Enabled:Enabled}'
```

---

## CloudWatch and Monitoring Issues

### Error: "Error: Invalid log group name"

**Symptoms**: CloudWatch log group creation fails

**Causes**:
- Log group name contains invalid characters
- Log group already exists

**Solutions**:

```bash
# Valid log group names
/aws/ec2/dev/app      # Valid
/aws/ec2/dev_app      # Valid
/aws-ec2-dev-app      # Invalid (hyphens at start)

# Check existing log groups
aws logs describe-log-groups --query 'logGroups[].logGroupName'

# Delete and recreate
aws logs delete-log-group --log-group-name /aws/ec2/dev/app
terraform apply
```

---

### Error: "Error: Alarm already exists"

**Symptoms**: CloudWatch alarm creation fails

**Causes**:
- Alarm with same name already exists
- Terraform state is out of sync

**Solutions**:

```bash
# List existing alarms
aws cloudwatch describe-alarms \
  --query 'MetricAlarms[].AlarmName'

# Delete conflicting alarm
aws cloudwatch delete-alarms --alarm-names dev-asg-cpu-high

# Refresh Terraform state
terraform refresh
terraform apply
```

---

## State Management Issues

### Error: "Error: Error reading state file"

**Symptoms**: Terraform fails to read state file

**Causes**:
- State file is corrupted
- State file permissions are incorrect
- Remote state backend is unavailable

**Solutions**:

```bash
# Backup current state
cp terraform.tfstate terraform.tfstate.backup

# Validate state file
terraform validate

# Refresh state
terraform refresh

# If state is corrupted, restore from backup
cp terraform.tfstate.backup terraform.tfstate
```

---

### Error: "Error: resource already exists"

**Symptoms**: Terraform apply fails because resource already exists

**Causes**:
- Resource was created outside Terraform
- Terraform state is out of sync
- Duplicate resource definition

**Solutions**:

```bash
# Import existing resource into state
terraform import aws_instance.example i-0123456789abcdef0

# Or remove from state and recreate
terraform state rm aws_instance.example
terraform apply

# Refresh state to sync with AWS
terraform refresh
```

---

## Deployment Timeouts

### Error: "Error: timeout while waiting for state to become 'available'"

**Symptoms**: Terraform apply times out waiting for resource

**Causes**:
- Resource is taking longer than expected to create
- Network connectivity issues
- AWS service is slow

**Solutions**:

```bash
# Increase timeout (in resource definition)
timeouts {
  create = "20m"
  delete = "20m"
}

# Retry the apply
terraform apply

# Check AWS service status
# Visit https://status.aws.amazon.com/
```

---

## Cleanup and Destruction

### Error: "Error: error deleting S3 Bucket"

**Symptoms**: Terraform destroy fails to delete S3 bucket

**Causes**:
- Bucket is not empty
- Bucket versioning is enabled
- Bucket has lifecycle policies

**Solutions**:

```bash
# Empty bucket before deletion
aws s3 rm s3://solana-dapp-dev-assets --recursive

# Remove all versions
aws s3api list-object-versions \
  --bucket solana-dapp-dev-assets \
  --query 'Versions[].{Key:Key,VersionId:VersionId}' \
  --output json | jq -r '.[] | "\(.Key) \(.VersionId)"' | \
  while read key version; do
    aws s3api delete-object \
      --bucket solana-dapp-dev-assets \
      --key "$key" \
      --version-id "$version"
  done

# Then destroy
terraform destroy
```

---

## Getting Help

If you encounter issues not listed here:

1. **Check logs**: Review CloudWatch logs and system logs
2. **Validate configuration**: Run `terraform validate`
3. **Check state**: Run `terraform state list` and `terraform state show`
4. **Review AWS Console**: Check resource status in AWS Management Console
5. **Search documentation**: Check Terraform and AWS documentation
6. **Open an issue**: Create a GitHub issue with error details and logs

---

**Last Updated**: December 2025

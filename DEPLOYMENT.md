# Terraform Deployment Guide

This guide provides step-by-step instructions for deploying the Solana dApp infrastructure on AWS using Terraform.

---

## Pre-Deployment Checklist

Before starting the deployment, ensure you have:

- [ ] AWS account created and active
- [ ] IAM user with programmatic access
- [ ] AWS CLI installed and configured
- [ ] Terraform installed (version 1.0+)
- [ ] Git installed
- [ ] Repository cloned locally
- [ ] SSH key pair created for EC2 access
- [ ] Email address for CloudWatch alerts

---

## Step 1: Set Up AWS Credentials

### Option A: Using AWS CLI

```bash
aws configure
```

You'll be prompted for:
- AWS Access Key ID
- AWS Secret Access Key
- Default region (us-east-1)
- Default output format (json)

### Option B: Using Environment Variables

```bash
export AWS_ACCESS_KEY_ID="your-access-key-id"
export AWS_SECRET_ACCESS_KEY="your-secret-access-key"
export AWS_DEFAULT_REGION="us-east-1"
```

### Verify Configuration

```bash
aws sts get-caller-identity
```

Should output your AWS account ID and ARN.

---

## Step 2: Prepare Terraform Variables

### Clone and Navigate

```bash
git clone https://github.com/mlakhoua-rgb/solana-dapp-terraform.git
cd solana-dapp-terraform
```

### Create Development Environment Variables

```bash
cp environments/dev/terraform.tfvars.example environments/dev/terraform.tfvars
```

### Edit Configuration

```bash
nano environments/dev/terraform.tfvars
```

**Required updates**:

```hcl
# Your public IP address (get it from https://whatismyipaddress.com/)
ssh_cidr_blocks = ["203.0.113.0/32"]

# Globally unique S3 bucket name (add random suffix)
s3_bucket_name = "solana-dapp-dev-assets-$(date +%s)"

# Your email for alerts
alert_email = "your-email@example.com"
```

---

## Step 3: Initialize Terraform

```bash
cd environments/dev
terraform init
```

This will:
- Download required provider plugins
- Initialize the Terraform working directory
- Create `.terraform` directory

**Expected output**:
```
Terraform has been successfully configured!
```

---

## Step 4: Review the Plan

```bash
terraform plan -var-file=terraform.tfvars -out=tfplan
```

This will:
- Analyze the configuration
- Display all resources to be created
- Show estimated costs (if Infracost is installed)

**Review carefully**:
- Number of resources to be created
- Resource names and configurations
- Security group rules
- IAM permissions

---

## Step 5: Apply the Configuration

```bash
terraform apply tfplan
```

**Note**: Using the saved plan file ensures you apply exactly what you reviewed.

**Expected duration**: 10-15 minutes

**What's happening**:
1. VPC and subnets are created
2. Security groups and IAM roles are configured
3. ALB is provisioned
4. EC2 instances are launched
5. Auto Scaling Group is configured
6. S3 bucket and CloudFront distribution are created
7. CloudWatch dashboards and alarms are set up

---

## Step 6: Verify Deployment

### Get Outputs

```bash
terraform output
```

**Important outputs**:
- `application_url`: URL to access your dApp
- `cloudfront_domain_name`: CDN domain for static assets
- `s3_bucket_name`: S3 bucket for assets
- `cloudwatch_log_group`: CloudWatch logs location

### Test Application Access

```bash
curl http://$(terraform output -raw alb_dns_name)
```

Should return the dApp home page.

### Check CloudWatch Logs

```bash
aws logs tail /aws/ec2/dev/app --follow
```

View real-time application logs.

### Verify EC2 Instances

```bash
aws ec2 describe-instances \
  --filters "Name=tag:Environment,Values=dev" \
  --query 'Reservations[].Instances[].{ID:InstanceId,State:State.Name,Type:InstanceType}'
```

---

## Step 7: Configure DNS (Optional)

### Using Route 53

1. Create a hosted zone in Route 53
2. Create an A record pointing to ALB DNS name
3. Update your domain registrar with Route 53 nameservers

### Using CloudFront Custom Domain

1. Request ACM certificate for your domain
2. Update `certificate_arn` in terraform.tfvars
3. Add CNAME record in your DNS provider pointing to CloudFront domain

---

## Step 8: Set Up HTTPS (Production)

### Request ACM Certificate

```bash
aws acm request-certificate \
  --domain-name yourdomain.com \
  --subject-alternative-names "*.yourdomain.com" \
  --validation-method DNS \
  --region us-east-1
```

### Validate Certificate

1. Check your email for validation link
2. Click the link to validate
3. Wait for certificate status to change to "Issued"

### Update Terraform

```bash
# In environments/prod/terraform.tfvars
certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"
```

### Redeploy

```bash
cd environments/prod
terraform apply -var-file=terraform.tfvars
```

---

## Deploying to Production

### Create Production Environment

```bash
cp environments/prod/terraform.tfvars.example environments/prod/terraform.tfvars
nano environments/prod/terraform.tfvars
```

**Key differences from dev**:
- Larger instance type (t3.large)
- More instances (3 minimum, 6 maximum)
- HTTPS required (certificate_arn)
- Longer log retention (30 days)
- Enhanced monitoring

### Deploy Production

```bash
cd environments/prod
terraform init
terraform plan -var-file=terraform.tfvars -out=tfplan
terraform apply tfplan
```

---

## Post-Deployment Tasks

### 1. Confirm SNS Subscription

Check your email for SNS subscription confirmation and click the link.

### 2. Update Application Configuration

SSH into an EC2 instance and update application settings:

```bash
# Using Systems Manager Session Manager (recommended)
aws ssm start-session --target i-0123456789abcdef0

# Or using SSH (if you configured key pair)
ssh -i your-key.pem ec2-user@<instance-ip>
```

### 3. Deploy Application Code

The user_data script clones and builds the application. To update:

```bash
cd /opt/solana-dapp
git pull origin main
pnpm install
pnpm build
sudo systemctl restart solana-dapp
```

### 4. Monitor Deployment

```bash
# Watch logs
aws logs tail /aws/ec2/dev/app --follow

# Check ALB health
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arn)
```

### 5. Set Up CloudWatch Dashboards

1. Go to AWS CloudWatch Console
2. Navigate to Dashboards
3. View the auto-created dashboard for your environment
4. Customize as needed

---

## Updating Infrastructure

### Making Changes

```bash
# Edit configuration
nano environments/dev/terraform.tfvars

# Plan changes
terraform plan -var-file=terraform.tfvars

# Review and apply
terraform apply -var-file=terraform.tfvars
```

### Common Updates

**Scaling up instances**:
```hcl
desired_instances = 3
max_instances = 8
```

**Changing instance type**:
```hcl
instance_type = "t3.large"
```

**Updating log retention**:
```hcl
log_retention_days = 60
```

---

## Destroying Infrastructure

### Development Environment

```bash
cd environments/dev
terraform destroy -var-file=terraform.tfvars
```

### Production Environment

```bash
cd environments/prod
terraform destroy -var-file=terraform.tfvars
```

**Warning**: This will delete all resources including data. Use with caution!

---

## Backup and Recovery

### Backup State File

```bash
# Local backup
cp environments/dev/terraform.tfstate terraform.tfstate.backup

# Or use remote state (recommended for production)
# Configure S3 backend in main.tf
```

### Recover from State File

```bash
# If state is corrupted
cp terraform.tfstate.backup environments/dev/terraform.tfstate
terraform refresh
```

---

## Troubleshooting

### Terraform Init Fails

**Error**: "Error: error configuring S3 Backend"

**Solution**: Check AWS credentials
```bash
aws sts get-caller-identity
```

### Apply Fails with Timeout

**Error**: "Error: timeout while waiting for state to become 'available'"

**Solution**: Wait and retry
```bash
terraform apply -var-file=terraform.tfvars
```

### S3 Bucket Name Taken

**Error**: "Error: Error creating S3 bucket: BucketAlreadyOwnedByYou"

**Solution**: Use unique bucket name
```hcl
s3_bucket_name = "solana-dapp-dev-assets-$(date +%s)"
```

### EC2 Instances Not Starting

**Error**: Instances in "running" state but failing health checks

**Solution**: Check logs
```bash
aws logs tail /aws/ec2/dev/app --follow
```

---

## Cost Management

### Estimate Costs

```bash
# Using Infracost (if installed)
infracost breakdown --path environments/dev

# Or manually calculate based on resource types
```

### Reduce Costs

1. Use t3.micro for development
2. Reduce desired_instances to 1
3. Disable NAT Gateway for dev (use NAT Instance)
4. Use Spot Instances for non-critical workloads
5. Implement S3 lifecycle policies

---

## Next Steps

1. **Configure CI/CD**: Set up GitHub Actions for automated deployments
2. **Add Monitoring**: Configure additional CloudWatch alarms
3. **Implement Logging**: Set up centralized logging with CloudWatch Insights
4. **Security Hardening**: Review and implement additional security measures
5. **Disaster Recovery**: Set up backups and recovery procedures

---

## Additional Resources

- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Best Practices](https://aws.amazon.com/architecture/best-practices/)
- [Terraform Best Practices](https://www.terraform.io/cloud-docs/recommended-practices)

---

**Last Updated**: December 2025

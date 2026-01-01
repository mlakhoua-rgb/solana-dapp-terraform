# Changelog

All notable changes to this Terraform infrastructure project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- GitHub Actions CI/CD workflow for automated validation, security scanning, and deployment
- Pre-commit hooks configuration for Terraform formatting and validation
- TFLint configuration for Terraform best practices
- Architecture diagram (Mermaid and PNG formats)
- Terraform version constraints (>= 1.6.0, < 2.0.0)
- Security scanning with Checkov and tfsec
- Cost estimation with Infracost integration
- Comprehensive CloudWatch dashboard
- SNS topic for alert notifications
- VPC Flow Logs for network monitoring

### Changed
- Updated Terraform version constraint from ">= 1.0" to ">= 1.6.0, < 2.0.0"
- Enhanced AWS provider configuration with default tags

### Security
- Added security scanning in CI/CD pipeline
- Implemented least-privilege IAM policies
- Enabled VPC Flow Logs for network traffic analysis

## [1.0.0] - 2025-01-01

### Added
- Initial Terraform infrastructure for Solana dApp on AWS
- Modular architecture with VPC, Security, Compute, and Storage modules
- Multi-environment support (dev and prod)
- Application Load Balancer with Auto Scaling Group
- S3 bucket for static assets with CloudFront CDN
- CloudWatch logging and monitoring
- Comprehensive documentation (README, DEPLOYMENT, MODULES, TROUBLESHOOTING)

### Infrastructure Components
- **VPC Module**: VPC, subnets, route tables, NAT gateways, internet gateway
- **Security Module**: Security groups, IAM roles and policies
- **Compute Module**: ALB, EC2 instances, Auto Scaling Group, launch template
- **Storage Module**: S3 bucket with versioning, lifecycle policies, CloudFront distribution

### Documentation
- README.md with quick start guide
- DEPLOYMENT.md with detailed deployment instructions
- MODULES.md with module-specific documentation
- TROUBLESHOOTING.md with common issues and solutions

[Unreleased]: https://github.com/mlakhoua-rgb/solana-dapp-terraform/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/mlakhoua-rgb/solana-dapp-terraform/releases/tag/v1.0.0

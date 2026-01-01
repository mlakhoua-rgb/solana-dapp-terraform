# Contributing to Solana dApp Terraform Infrastructure

Thank you for your interest in contributing to this AI-augmented Infrastructure as Code project! This repository demonstrates how experienced infrastructure leaders orchestrate AI agents for IaC development while maintaining human governance.

## How to Contribute

### Reporting Issues

If you find a bug, security vulnerability, or have a feature request:

1. Check if the issue already exists in the [Issues](https://github.com/mlakhoua-rgb/solana-dapp-terraform/issues) section
2. If not, create a new issue with a clear title and description
3. Include relevant details: Terraform version, AWS region, error messages, etc.
4. For security vulnerabilities, please email directly rather than creating a public issue

### Suggesting Enhancements

We welcome suggestions for improving this AI-augmented IaC demonstration:

- New Terraform modules or AWS services
- Enhanced security configurations
- Cost optimization strategies
- Improved CI/CD workflows
- Better documentation or examples

Please open an issue with the `enhancement` label to discuss your ideas.

### Pull Requests

We appreciate pull requests that improve the infrastructure code, documentation, or AI-augmented development practices.

**Before submitting a PR:**

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-improvement`)
3. Make your changes following our coding standards
4. Test your changes thoroughly in a dev environment
5. Run Terraform formatting: `terraform fmt -recursive`
6. Run Terraform validation: `terraform validate`
7. Run security scanning: `checkov -d .` or `tfsec .`
8. Update documentation if needed
9. Commit with clear, descriptive messages
10. Push to your fork and submit a pull request

**PR Guidelines:**

- Keep changes focused and atomic
- Include a clear description of what and why
- Reference related issues if applicable
- Ensure all CI/CD checks pass
- Be responsive to review feedback

### Coding Standards

**Terraform Code:**

- Use consistent naming conventions (lowercase with underscores)
- Add comments for complex logic
- Use variables for configurable values
- Follow Terraform best practices and style guide
- Ensure idempotency and immutability
- Use data sources when appropriate
- Implement proper resource dependencies

**Documentation:**

- Update README.md for significant changes
- Document new variables and outputs
- Include usage examples
- Maintain architecture diagrams if structure changes

**Security:**

- Never commit sensitive data (credentials, keys, secrets)
- Use AWS Secrets Manager or Parameter Store for secrets
- Follow least-privilege access principles
- Enable encryption for data at rest and in transit
- Implement proper security group rules

### AI-Augmented Development

This repository demonstrates AI-augmented IaC development. When contributing:

- **Human Oversight Required:** All AI-generated code must be reviewed and validated by humans
- **Production Governance:** Maintain human ownership of production deployment decisions
- **Security Validation:** AI-assisted security scanning must be human-reviewed
- **Documentation:** Clearly document AI-assisted vs. human-authored sections if relevant

### Testing

Before submitting changes:

1. Test in a dev environment first
2. Verify Terraform plan output
3. Check for unintended resource changes
4. Validate security configurations
5. Test rollback procedures if applicable

### Code Review Process

1. Maintainers will review PRs within 5 business days
2. Feedback will be provided for improvements
3. Once approved, changes will be merged
4. Contributors will be acknowledged in release notes

### Community Guidelines

- Be respectful and constructive
- Focus on the code and ideas, not individuals
- Welcome newcomers and help them learn
- Follow the [Code of Conduct](CODE_OF_CONDUCT.md) (if applicable)

### Questions?

If you have questions about contributing:

- Open a discussion in the [Discussions](https://github.com/mlakhoua-rgb/solana-dapp-terraform/discussions) section
- Check existing documentation
- Review closed issues for similar questions

## License

By contributing, you agree that your contributions will be licensed under the same MIT License that covers this project.

---

**Thank you for contributing to AI-augmented Infrastructure as Code!**

This project demonstrates how experienced infrastructure leaders can leverage AI agents as collaborators while maintaining human ownership of production environments.

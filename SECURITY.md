# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in this Letta skill, please report it privately.

**Do not open a public issue for security vulnerabilities.**

### How to Report

Please email security-related issues to the maintainers or use the private vulnerability reporting feature if available. Include:

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Any relevant details or proof-of-concept

We will acknowledge receipt within 48 hours and aim to provide a fix or mitigation timeline within 7 days.

## Supported Versions

Security fixes are applied to the latest version of this skill only. Users are encouraged to keep their skill updated to the latest version.

## Security Best Practices

### Environment Variables

- Never commit `.env` files to version control
- Use `.env.example` as a template only
- Rotate API keys regularly
- Use different API keys for development and production
- Store secrets in environment variables or secret management systems

### API Keys

- Letta API keys should be treated as secrets
- OpenRouter, OpenAI, and Anthropic API keys must be kept secure
- Never expose API keys in logs, error messages, or client-side code
- Use environment variables or secret stores for all sensitive credentials

### PostgreSQL Security

- Use strong passwords for PostgreSQL
- Enable SSL/TLS for database connections in production
- Restrict database access to necessary IPs only
- Regularly update PostgreSQL to the latest version
- Use database roles with minimal required permissions

### Docker Security

- Run containers with non-root users when possible
- Keep Docker images updated
- Scan images for vulnerabilities
- Use resource limits to prevent resource exhaustion
- Network isolation for sensitive services

### Secret Management

For production deployments, consider using:
- AWS Secrets Manager
- HashiCorp Vault
- Azure Key Vault
- Environment-specific secret stores

## Data Privacy

This skill interacts with Letta servers which may process AI conversations. Be aware of:

- Data retention policies of your Letta provider
- Privacy implications of storing conversations in memory blocks
- Compliance requirements for your use case (GDPR, HIPAA, etc.)

## Dependencies

This skill depends on:
- Letta server (self-hosted or cloud)
- PostgreSQL database
- LLM provider APIs (OpenRouter, OpenAI, Anthropic, etc.)

Keep these dependencies updated and monitor their security advisories.

## License

This skill is provided as-is without warranty. Users are responsible for ensuring their deployment meets their security requirements.

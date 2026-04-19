# Contributing to Letta Skill

Thank you for your interest in contributing to the Letta Infrastructure Management Skill! This document provides guidelines and instructions for contributing.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Pull Request Process](#pull-request-process)
- [Coding Standards](#coding-standards)
- [Documentation](#documentation)
- [Testing](#testing)
- [Reporting Issues](#reporting-issues)

## Code of Conduct

This project adheres to a code of conduct. By participating, you are expected to uphold this code. Please report unacceptable behavior to the project maintainers.

**Be respectful**: Treat all contributors with respect and consideration.

**Be inclusive**: Welcome contributors from diverse backgrounds and experience levels.

**Be constructive**: Provide feedback in a constructive and helpful manner.

**Be collaborative**: Work together to improve the project for everyone.

## Getting Started

### Prerequisites

- Bash shell scripting knowledge
- Understanding of REST APIs
- Familiarity with Docker and Docker Compose
- Basic knowledge of PostgreSQL
- Git and GitHub workflow understanding

### Fork the Repository

1. Fork the repository on GitHub
2. Clone your fork locally:

```bash
git clone https://github.com/your-username/letta-skill.git
cd letta-skill
```

3. Add the upstream repository:

```bash
git remote add upstream https://github.com/original-owner/letta-skill.git
```

### Set Up Development Environment

1. Copy the example environment file:

```bash
cp .env.example .env
```

2. Edit `.env` with your local development values

3. Source the helper scripts:

```bash
source scripts/letta_client.sh
source scripts/letta_secrets.sh
```

## Development Workflow

### Create a Branch

Create a new branch for your work:

```bash
git checkout -b feature/your-feature-name
```

Or for bug fixes:

```bash
git checkout -b fix/your-bug-fix
```

### Make Your Changes

- Follow the coding standards outlined below
- Add tests for new functionality
- Update documentation as needed
- Keep changes focused and atomic

### Test Your Changes

Test your changes locally:

```bash
# Test helper scripts
letta_secrets_validate_all

# Test API calls (ensure Letta server is running)
curl -s http://localhost:8283/v1/health | jq .
```

### Commit Your Changes

Write clear, descriptive commit messages:

```bash
git add .
git commit -m "Add feature: description of what you did"
```

Commit message format:
- Use imperative mood ("Add" not "Added")
- Be concise but descriptive
- Reference related issues if applicable

### Sync with Upstream

Before creating a pull request, sync with upstream:

```bash
git fetch upstream
git rebase upstream/main
```

## Pull Request Process

### Before Submitting

1. Ensure your code follows the coding standards
2. Update documentation for any user-facing changes
3. Add tests for new functionality
4. Ensure all existing tests pass
5. Update CHANGELOG.md if appropriate

### Submitting a Pull Request

1. Push your branch to your fork:

```bash
git push origin feature/your-feature-name
```

2. Create a pull request on GitHub
3. Fill in the PR template with:
   - Description of changes
   - Related issues
   - Testing performed
   - Screenshots if applicable

### PR Review Process

- Maintainers will review your PR
- Address feedback in a timely manner
- Keep the PR focused and small if possible
- Be responsive to review comments

### After Merge

Delete your branch after merge:

```bash
git branch -d feature/your-feature-name
git push origin --delete feature/your-feature-name
```

## Coding Standards

### Bash Scripting

- Use 4-space indentation (no tabs)
- Use `set -e` for error handling in scripts
- Quote variables: `"$VAR"` not `$VAR`
- Use `#!/bin/bash` shebang
- Add comments for complex logic
- Functions should be named with `letta_` prefix

### Documentation

- Use Markdown for all documentation
- Include code examples with proper syntax highlighting
- Update CHANGELOG.md for significant changes
- Keep documentation clear and concise
- Use consistent heading levels

### Environment Variables

- Use uppercase names for environment variables
- Document new variables in `.env.example`
- Never hardcode secrets or API keys
- Use defaults where appropriate: `${VAR:-default}`

### API Calls

- Use the helper scripts when possible
- Follow the Letta API documentation
- Include proper error handling
- Use jq for JSON parsing
- Always include the `/v1/` API prefix

## Documentation

### Reference Documentation

Reference documentation in `reference/` should:
- Be comprehensive and accurate
- Include code examples
- Cover all available options
- Be kept in sync with code changes
- Follow the existing format

### README Updates

Update README.md when:
- Adding new features
- Changing configuration requirements
- Updating deployment instructions
- Adding new dependencies

### Inline Documentation

Add comments in scripts for:
- Complex logic
- Non-obvious operations
- Workarounds or special cases
- External dependencies

## Testing

### Manual Testing

Test changes manually by:
- Running helper scripts
- Testing API endpoints
- Verifying documentation examples
- Testing with different configurations

### Test Checklist

Before submitting a PR, verify:
- [ ] Code follows coding standards
- [ ] Documentation is updated
- [ ] Examples work as documented
- [ ] Environment variables are documented
- [ ] No hardcoded secrets
- [ ] CHANGELOG.md is updated (if applicable)

## Reporting Issues

### Bug Reports

When reporting bugs, include:
- Clear description of the problem
- Steps to reproduce
- Expected behavior
- Actual behavior
- Environment details (OS, Letta version, etc.)
- Relevant logs or error messages
- Example code if applicable

### Feature Requests

When requesting features, include:
- Clear description of the feature
- Use case or problem it solves
- Potential implementation approach
- Examples of similar features in other tools
- Impact assessment (priority, complexity)

### Documentation Issues

When reporting documentation issues, include:
- Section or file reference
- What's wrong or unclear
- Suggested improvement
- Example if applicable

## Questions and Support

- Check existing documentation first
- Search existing issues
- Use the appropriate issue template
- Be patient with responses
- Help others if you can

## Recognition

Contributors will be recognized in:
- CONTRIBUTORS.md file
- Release notes
- Project documentation

Thank you for contributing to the Letta Infrastructure Management Skill!

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial release of Letta Infrastructure Management Skill
- Agent lifecycle management (create, list, update, retrieve, delete)
- Memory block management (core memory and archival memory)
- Identity management for multi-user applications
- Folder and file management (MemFS)
- Health check functionality for server and database
- OpenRouter model selection and testing
- Secrets management with environment variable support
- Custom tool building capabilities
- Helper scripts for common operations
- Comprehensive documentation in reference/ directory
- Environment variable configuration via .env.example
- Support for multiple LLM providers (OpenRouter, OpenAI, Anthropic, Ollama, vLLM)
- Docker deployment examples
- PostgreSQL configuration for self-hosted deployments

### Changed
- Aligned environment variable names with Letta conventions
  - `LETTA_PG_URI` → `LETTA_POSTGRES_URI`
  - `PG_*` → `POSTGRES_*` for PostgreSQL variables
- Generalized skill to be provider-agnostic
- Removed hardcoded model defaults
- Made Docker container name configurable via `LETTA_CONTAINER_NAME`

### Security
- All secrets externalized to environment variables
- `.env` added to `.gitignore`
- Security policy documentation added

### Documentation
- Added SKILL.md as main entry point
- Added detailed reference documentation for all modules
- Added README.md with quick start guide
- Added deployment guide
- Added security policy
- Added Apache 2.0 license

## [1.0.0] - 2026-04-19

### Added
- Initial public release
- Complete Letta infrastructure management skill
- Support for self-hosted and cloud Letta deployments
- Multi-provider LLM support
- Comprehensive API coverage through REST endpoints
- Bash helper scripts for automation

# Letta Skill

Complete Letta infrastructure management skill for AI agents. Provides comprehensive capabilities for managing self-hosted Letta servers including agent lifecycle, memory blocks, identities, folders/files (MemFS), health checks, model selection, secrets management, and custom tool building.

## Install

### Using Git Clone (Recommended for All Agents)

```bash
# Clone the repository
git clone https://github.com/cbwinslow/letta-skill.git ~/skills/letta

# Or add as a submodule in your dotfiles
git submodule add https://github.com/cbwinslow/letta-skill.git path/to/skills/letta
```

### Using `skr` CLI

```bash
# Install from OCI registry
skr install ghcr.io/cbwinslow/letta-skill:latest

# Or from git
skr install git+https://github.com/cbwinslow/letta-skill
```

### Using `gh` CLI

```bash
# Install for Claude Code
gh skill install cbwinslow/letta-skill letta --agent claude-code --scope user

# Install for Codex
gh skill install cbwinslow/letta-skill letta --agent codex --scope user
```

### Manual Installation

1. Download or clone this repository
2. Copy the `letta-skill/` directory to your agent's skills folder
3. Copy `.env.example` to `.env` and configure

## Features

- **Agent Manager**: Create, list, update, retrieve, and delete Letta agents
- **Memory Manager**: Manage core memory blocks and archival memory (long-term searchable storage)
- **Identity Manager**: Handle multi-user applications with user-to-agent mappings
- **Folder & Archive Manager**: Manage Letta folders and files (MemFS) for file organization
- **Health Check**: Monitor Letta server health, PostgreSQL connectivity, and LLM provider availability
- **Model Picker**: Select and configure models from various providers (OpenRouter, OpenAI, Anthropic, Ollama, etc.)
- **Secrets Manager**: Securely manage secrets using environment variables and external secret stores
- **Tool Builder**: Create, list, attach, detach, update, and delete custom tools

## Quick Start

### 1. Setup Environment

```bash
# Copy the example environment file
cp .env.example .env

# Edit .env with your actual values
# Required: LETTA_API_KEY
# Optional: OPENROUTER_API_KEY, OPENAI_API_KEY, ANTHROPIC_API_KEY, LETTA_POSTGRES_URI, etc.
```

### 2. Source Helper Scripts

```bash
# Source all helper functions
source scripts/letta_client.sh
source scripts/letta_agents.sh
source scripts/letta_memory.sh
source scripts/letta_identities.sh
source scripts/letta_folders.sh
source scripts/letta_tools.sh
source scripts/letta_secrets.sh

# Or source all at once
for f in scripts/letta_*.sh; do source "$f"; done
```

### 3. Common Operations

```bash
# List all agents
letta_agents_list | jq .

# Create agent with memory blocks
AGENT_ID=$(letta_agents_create "my-agent" "Description" "$LETTA_MODEL")

# Send message to agent
letta_agents_message "$AGENT_ID" "Hello"

# Health check
letta_secrets_validate_all
```

## Supported LLM Providers

- **OpenRouter**: Free and paid models via OpenRouter API
- **OpenAI**: GPT models via OpenAI API
- **Anthropic**: Claude models via Anthropic API
- **Ollama**: Local models via Ollama
- **Custom**: Any OpenAI-compatible API endpoint

## Self-Hosting Letta

This skill works with both Letta Cloud and self-hosted Letta deployments. For self-hosting:

### Docker Deployment

```bash
docker run -d \
  --name letta-server \
  -v ~/.letta/.persist/pgdata:/var/lib/postgresql/data \
  -p 8283:8283 \
  -e LETTA_POSTGRES_URI=postgresql://${POSTGRES_USER:-letta}:${POSTGRES_PASSWORD}@host.docker.internal:5432/${POSTGRES_DB:-letta} \
  -e OPENROUTER_API_KEY=${OPENROUTER_API_KEY} \
  letta/letta:latest
```

### Using Docker Compose

```yaml
version: '3.8'
services:
  postgres:
    image: pgvector/pgvector:pg16
    environment:
      POSTGRES_USER: letta
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: letta
    volumes:
      - pgdata:/var/lib/postgresql/data
  letta:
    image: lettaai/letta:latest
    ports:
      - "8283:8283"
    environment:
      LETTA_PG_URI: postgresql://${POSTGRES_USER:-letta}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB:-letta}
      OPENAI_API_BASE: ${OPENROUTER_BASE_URL:-https://openrouter.ai/api/v1}
      OPENAI_API_KEY: ${OPENROUTER_API_KEY}
    depends_on:
      - postgres
volumes:
  pgdata:
```

## Documentation

- **SKILL.md**: Main skill file with quick start and module overview
- **references/agents.md**: Agent management detailed API
- **references/memory.md**: Memory blocks and archival memory
- **references/identities.md**: Identity management
- **references/folders.md**: Folder/file and MemFS operations
- **references/healthcheck.md**: Health checks and troubleshooting
- **references/openrouter.md**: Model selection and configuration
- **references/secrets.md**: Secret management best practices
- **references/tools.md**: Custom tool creation and management
- **references/scripts-guide.md**: Helper scripts documentation
- **templates/**: Starter templates for agents and memory blocks

## Security

- Never commit `.env` file to version control
- Use environment variables for all secrets
- Rotate API keys regularly
- Use external secret stores for production deployments

See [SECURITY.md](SECURITY.md) for detailed security guidelines.

## Getting Help

- **Documentation**: Start with [SKILL.md](SKILL.md) and [AGENTS.md](AGENTS.md)
- **Deployment Guide**: See [DEPLOYMENT.md](DEPLOYMENT.md) for deployment instructions
- **Letta Documentation**: [docs.letta.com](https://docs.letta.com)
- **Letta GitHub**: [github.com/letta-ai/letta](https://github.com/letta-ai/letta)
- **Letta Discord**: [discord.gg/letta](https://discord.gg/letta)

## Requirements

- Letta server (self-hosted or Letta Cloud)
- `curl` for API requests
- `jq` for JSON parsing (optional but recommended)
- Bash shell

## License

This skill is provided under the Apache-2.0 license for use with Letta infrastructure management.

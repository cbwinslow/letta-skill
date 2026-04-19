# Letta Skill

Complete Letta infrastructure management skill for AI agents. This skill provides comprehensive capabilities for managing self-hosted Letta servers including agent lifecycle, memory blocks, identities, folders/files (MemFS), health checks, model selection, secrets management, and custom tool building.

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
    image: postgres:15
    environment:
      POSTGRES_USER: letta
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: letta
    volumes:
      - pgdata:/var/lib/postgresql/data

  letta:
    image: letta/letta:latest
    ports:
      - "8283:8283"
    environment:
      LETTA_POSTGRES_URI: postgresql://${POSTGRES_USER:-letta}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB:-letta}
      OPENROUTER_API_KEY: ${OPENROUTER_API_KEY}
    depends_on:
      - postgres

volumes:
  pgdata:
```

## Documentation

- **SKILL.md**: Main skill file with quick start and module overview
- **reference/agents.md**: Agent management detailed API
- **reference/memory.md**: Memory blocks and archival memory
- **reference/identities.md**: Identity management
- **reference/folders.md**: Folder/file and MemFS operations
- **reference/healthcheck.md**: Health checks and troubleshooting
- **reference/openrouter.md**: Model selection and configuration
- **reference/secrets.md**: Secret management best practices
- **reference/tools.md**: Custom tool creation and management
- **reference/scripts-guide.md**: Helper scripts documentation

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

This skill is provided as-is for use with Letta infrastructure management.

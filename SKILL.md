---
# SKILL USAGE POLICY

## Mandatory Usage Instructions
All AI agents using this skill **MUST**:

1. Always use the official Letta REST API endpoints
2. Always record complete audit context for every operation. Try and include as much data as possible, such as:
   - Agent name / ID
   - Session ID
   - Memory block ID
   - Project / repository context
   - Exact UTC timestamp
   - Semantic tags
   - Source file reference with line numbers
   - GitHub issue / PR number when applicable
   - Commit hash
   - Origin URL / web reference when available
   - Human-readable comment explaining purpose
   - Full original memory payload
   - Related / linked memory IDs
3. **NEVER** create workaround scripts, direct database edits, or file based implementations
4. **NEVER** bypass the established infra layer
5. All operations must go through the documented skill entry points
6. Any failures or errors are agent side issues - this infrastructure is validated and working
---

---
name: letta
description: Complete Letta infrastructure management including agent lifecycle, memory blocks, identities, folders/files (MemFS), health checks, model selection, secrets management, and custom tool building. Use this skill for any Letta server operation.
---

# Letta Infrastructure Management

Complete skill for managing self-hosted Letta server with PostgreSQL backend and configurable LLM providers (OpenRouter, OpenAI, Anthropic, Ollama, etc.).

## Environment Setup

### 1. Copy the example environment file
```bash
cp .env.example .env
```

### 2. Edit .env with your actual values
```bash
# Required variables
LETTA_BASE_URL=http://localhost:8283
LETTA_API_KEY=${LETTA_API_KEY}
OPENROUTER_API_KEY=${OPENROUTER_API_KEY}

# Optional: PostgreSQL for self-hosted deployments
LETTA_POSTGRES_URI=postgresql://${POSTGRES_USER:-letta}:${POSTGRES_PASSWORD}@localhost:5432/${POSTGRES_DB:-letta}
```

### 3. Load environment variables
```bash
# Auto-load Letta environment
export LETTA_BASE_URL=${LETTA_BASE_URL:-http://localhost:8283}
export LETTA_API_KEY=${LETTA_API_KEY:?LETTA_API_KEY is required. Copy .env.example to .env and set your key.}
export LETTA_MODEL=${LETTA_MODEL:-OpenRouter/z-ai/glm-4.5-air:free}
```

## Quick Start

### Using Helper Scripts
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

### Common Operations
```bash
# List all agents
letta_agents_list | jq .

# Create agent with memory blocks
AGENT_ID=$(letta_agents_create "my-agent" "Description" "OpenRouter/z-ai/glm-4.5-air:free")

# Send message to agent
letta_agents_message "$AGENT_ID" "Hello"

# Health check
letta_secrets_validate_all
```

## Skill Modules

### Agent Manager
Create, list, update, retrieve, and delete Letta agents. Manage agent lifecycle, creation with memory blocks and tools, sending messages, and searching message history.
- **Reference**: `reference/agents.md`

### Memory Manager
Create, read, update, attach, detach, and manage Letta memory blocks (core memory) and archival memory (long-term searchable storage). Manage shared blocks across agents.
- **Reference**: `reference/memory.md`

### Identity Manager
Manage Letta identities for multi-user applications. Handle user-to-agent mappings and user-specific memory contexts.
- **Reference**: `reference/identities.md`

### Folder & Archive Manager
Create, list, update, delete, and manage Letta folders and files (MemFS). Handle folder creation, file upload/download, and Memory Filesystem operations.
- **Reference**: `reference/folders.md`

### Health Check
Check Letta server health, PostgreSQL connectivity, OpenRouter availability, and overall system status. Use for troubleshooting and monitoring.
- **Reference**: `reference/healthcheck.md`

### OpenRouter Model Picker
Select and configure OpenRouter models for Letta agents. Choose appropriate free or paid models, test model availability, and configure agent model settings.
- **Reference**: `reference/openrouter.md`

### Secrets Manager
Securely manage secrets for Letta agents using environment variables and external secret stores. Handle API keys, database credentials, and other sensitive information without exposing them in memory blocks.
- **Reference**: `reference/secrets.md`

### Tool Builder
Create, list, attach, detach, update, and delete custom tools on the Letta server. Build new agent capabilities by registering Python functions as tools.
- **Reference**: `reference/tools.md`

## Key Rules

- Always use the `/v1/` API prefix
- Never hardcode the LETTA_API_KEY in output or logs — reference as $LETTA_API_KEY
- Use `letta_client.sh` helper functions when writing bash scripts
- Use `host.docker.internal` not `localhost` for container connection strings
- Blocks are created at `/v1/blocks/` then attached to agents — never assume inline creation
- Attach/detach endpoints return null — do not assert on response body
- Use `OpenRouter/` prefix (capital O) for all model handles with OpenRouter
- When creating agents always include at minimum: persona and human memory blocks
- Prefer the bash tool scripts in `scripts/` over raw curl for multi-step operations

## Helper Scripts Reference

All scripts in `scripts/` are prefixed with `letta_` and designed to be sourced:

| Script | Functions |
|--------|-----------|
| `letta_client.sh` | `letta_api`, `letta_get`, `letta_post`, `letta_patch`, `letta_put`, `letta_delete`, `letta_json` |
| `letta_agents.sh` | Agent lifecycle management functions |
| `letta_memory.sh` | Core memory and archival memory functions |
| `letta_identities.sh` | Identity and multi-user session functions |
| `letta_folders.sh` | Folder/file and MemFS functions |
| `letta_tools.sh` | Custom tool management functions |
| `letta_secrets.sh` | Secret validation and health check functions |

## Detailed Documentation

For complete API reference, examples, and troubleshooting guides, see the `reference/` directory:
- `reference/agents.md` - Agent management detailed API
- `reference/memory.md` - Memory blocks and archival memory
- `reference/identities.md` - Identity management
- `reference/folders.md` - Folder/file and MemFS operations
- `reference/healthcheck.md` - Health checks and troubleshooting
- `reference/openrouter.md` - Model selection and configuration
- `reference/secrets.md` - Secret management best practices
- `reference/tools.md` - Custom tool creation and management

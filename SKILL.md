---
name: letta-skill
description: Complete Letta infrastructure management including agent lifecycle, memory blocks, identities, folders/files (MemFS), health checks, model selection, and custom tool building. Uses the official letta-client Python SDK via a unified CLI and provides high-level workflow scripts for common operations.
license: Apache-2.0
compatibility: Requires Python 3.12+, letta-client>=1.10.1, and a Letta server (http://localhost:8283)
metadata:
  version: "1.0.0"
  author: "cbwinslow"
  tags: ["letta", "agent-management", "memory", "infrastructure", "sdk"]
---

# Letta Infrastructure Management Skill

This skill provides a complete toolkit for managing a self-hosted Letta server. It wraps the official `letta-client` Python SDK in a convenient CLI (`letta`) and offers high-level workflow scripts for complex operations.

## Prerequisites

- Python 3.12 or newer with `letta-client` installed (`pip install letta-client`)
- Letta server running (default: http://localhost:8283)
- API key with appropriate permissions

## Setup

1. Copy `.env.example` to `.env` and configure:
   ```
   LETTA_BASE_URL=http://localhost:8283
   LETTA_API_KEY=your_api_key
   LETTA_MODEL=OpenRouter/z-ai/glm-4.5-air:free
   ```
2. The `letta` CLI auto-loads this `.env` file.
3. Verify with `./letta health`.

## Quick Examples

```bash
# List agents
./letta agents list | jq .

# Create an agent with custom memory blocks
BLOCKS='[{"label":"persona","value":"You are a helpful assistant.","limit":2000},{"label":"human","value":"User context.","limit":2000}]'
echo "$BLOCKS" | ./letta agents create "my-agent" "My description"

# Send a message
./letta agents message <agent_id> "Hello!"

# Search archival memory
./letta archival search <agent_id> "query"

# Workflow: full agent setup (blocks + tools + optional folder)
./workflows/agent/setup.sh --name "support-agent" --description "Customer support" --template support
```

## CLI Reference

The `letta` binary provides these commands:

- `agents` – list, get, create, delete, message, attach-tool, detach-tool, attach-folder, detach-folder
- `messages` – list, search
- `blocks` – list, get, create, update
- `archival` – search, insert, list, delete
- `tools` – list, list-agent, create, update, delete
- `folders` – list (per agent)
- `conversations` – start, continue
- `identities` – create, link
- `health` – server health check

Run `./letta --help` for details.

## Workflows

Higher-level orchestration scripts live in `workflows/`:

| Workflow | Purpose | Usage |
|----------|---------|-------|
| `agent/setup.sh` | Create agent with memory blocks and attach essential tools | `--name`, `--description`, `--template [minimal\|homelab\|research\|support\|data]`, `--folder` |
| `agent/info.sh` | Display agent status (blocks, tools, messages) | `--agent-id`, `--format [json\|summary\|full]` |
| `agent/clone.sh` | Clone an agent (blocks, tools, folders) | `--source-agent-id`, `--new-name` |
| `agent/delete.sh` | Delete an agent with optional backup | `--agent-id`, `--confirm yes/`, `--backup true/false` |
| `memory/save.sh` | Save a fact to archival memory | `--agent-id`, `--text`, `--tags`, `--autotag` |
| `memory/recall.sh` | Unified search across archival and conversation | `--agent-id`, `--query`, `--limit`, `--source [archival\|conversation\|both]` |
| `conversation/start.sh` | Start a new conversation thread | `--agent-id`, `--name`, `--first-message` |
| `conversation/continue.sh` | Continue a conversation | `--conversation-id`, `--message` |
| `system/health.sh` | Full health check (Letta, PostgreSQL, LLM) | `--detailed` |
| `system/usage.sh` | Generate usage report (single or all agents) | `--agent-id`, `--days` |
| `identity/onboard.sh` | Create identity and optionally an agent | `--identifier`, `--name`, `--create-agent true/false`, `--agent-template` |
| `backup/agent.sh` | Backup all agent data to JSON | `--agent-id`, `--output` |
| `backup/restore.sh` | Restore agent from backup | `--backup-file`, `--new-agent-id`, `--merge` |

All workflows auto-source `.env` from the skill root and call the `letta` CLI.

## Architecture Notes

- **SDK-based**: All API interactions go through the official `letta-client` Python package.
- **Single entry point**: The `letta` CLI provides a consistent interface; workflows call it.
- **Progressive disclosure**: Agents load this `SKILL.md` when needed; full instructions are concise.
- **Resources**: Additional reference documentation is in `references/` and code in `lib/`.

## Troubleshooting

- `Error: Illegal header value 'Bearer '` – The `.env` file is missing or `LETTA_API_KEY` not set.
- `404 Not Found` – Check `LETTA_BASE_URL` is correct and Letta server is running.
- `422 Validation error` – Verify required fields; for agent creation, at least `persona` and `human` blocks are needed.
- Tool not found – Use tool ID (UUID) or name as appropriate. CLI resolves names to IDs.
- Streaming timeouts – Long conversations automatically include pings; the SDK handles it. Increase timeout if needed.

---

For more detailed API documentation, see the `reference/` directory.

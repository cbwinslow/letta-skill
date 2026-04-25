# Letta Skill Workflows Documentation

Complete guide to the high-level workflow scripts included in the Letta skill.

## Overview

Workflows are composite scripts that combine multiple skill functions into complete, parameterized operations. They handle common patterns like agent creation, memory search, backups, and system monitoring.

## Installation

Workflows are included with the skill. No separate installation needed. Ensure:

```bash
# Environment is configured
source .env

# Helper scripts are available
source scripts/letta_client.sh
source scripts/letta_agents.sh
source scripts/tta_memory.sh
```

All workflows auto-source these dependencies from the skill directory.

## Workflow Categories

### Agent Lifecycle

#### `workflows/agent/setup.sh`
Create a fully configured agent with memory blocks, tools, and optional folder attachment.

```bash
workflows/agent/setup.sh \
  --name "support-bot" \
  --description "Customer support assistant" \
  --template support \
  --folder "support-docs"
```

**Parameters:**
- `--name` (required) — Agent name
- `--description` (required) — Agent purpose
- `--model` (optional) — LLM model (default: `$LETTA_MODEL`)
- `--template` (optional) — Block template: `minimal`, `homelab`, `research`, `support`, `data` (default: `minimal`)
- `--folder` (optional) — Attach folder by name
- `--tools` (optional) — Comma-separated tool list (default includes essential memory tools)

**Returns:** `{agent_id, name, description, model, template, tools_attached[], folder, created_at}`

---

#### `workflows/agent/info.sh`
Display comprehensive agent status report.

```bash
# JSON output (default)
workflows/agent/info.sh --agent-id AGENT_ID | jq .

# Human-readable summary
workflows/agent/info.sh --agent-id AGENT_ID --format summary

# Full details
workflows/agent/info.sh --agent-id AGENT_ID --format full
```

**Includes:**
- Agent metadata (name, model, created)
- Memory block details (label, size, read-only status, description)
- Tool list (name, type, description)
- Folder attachments
- Message count and recent messages

---

#### `workflows/agent/clone.sh`
Duplicate an agent (copies memory blocks, tools, folders; NOT messages).

```bash
workflows/agent/clone.sh \
  --source-agent-id agent-abc123 \
  --new-name "agent-copy" \
  --copy-messages false
```

**Parameters:**
- `--source-agent-id` (required) — Agent to clone
- `--new-name` (required) — Name for clone
- `--copy-messages` (optional) — Whether to copy message history (default: false; generally not recommended)

**Returns:** `{source_agent_id, source_name, new_agent_id, new_name, tools_copied, folders_copied, cloned_at}`

---

#### `workflows/agent/delete.sh`
Safely delete an agent with confirmation prompts and optional backup.

```bash
# Show what would be deleted (no action)
workflows/agent/delete.sh --agent-id AGENT_ID

# Confirm and delete
workflows/agent/delete.sh --agent-id AGENT_ID --confirm yes

# Delete with backup
workflows/agent/delete.sh --agent-id AGENT_ID --confirm yes --backup true
```

**Safety:** Requires explicit `--confirm yes` for deletion. With `--backup true`, creates a JSON backup first.

---

### Memory Operations

#### `workflows/memory/save.sh`
Store a fact to archival memory with auto-tagging.

```bash
workflows/memory/save.sh \
  --agent-id AGENT_ID \
  --text "User prefers Python for data analysis" \
  --tags "type:preference,category:language" \
  --autotag
```

**Parameters:**
- `--agent-id` (required) — Target agent
- `--text` (required) — Fact to store (max ~10KB recommended)
- `--tags` (optional) — Comma-separated tags (e.g., `project:retrosheet,type:decision`)
- `--autotag` (optional) — Auto-add `project:agent-name`, `date:YYYY-MM-DD`, `type:memory`

**Auto-tagging:** When `--autotag` is set, automatically adds:
- `project:{agent_name}` — from agent's name
- `date:{YYYY-MM-DD}` — current date
- `type:memory` — memory type

---

#### `workflows/memory/recall.sh`
Unified memory recall — search both archival memory and conversation history.

```bash
# Search both sources (default)
workflows/memory/recall.sh --agent-id AGENT_ID --query "network configuration"

# Search archival only
workflows/memory/recall.sh --agent-id AGENT_ID --query "deployment steps" --source archival

# Search conversation only
workflows/memory/recall.sh --agent-id AGENT_ID --query "previous discussion" --source conversation

# Get up to 10 results per source
workflows/memory/recall.sh --agent-id AGENT_ID --query "setup" --limit 10
```

**Parameters:**
- `--agent-id` (required) — Agent to search
- `--query` (required) — Search query (semantic for archival, hybrid for conversation)
- `--limit` (optional) — Max results per source (default: 5)
- `--source` (optional) — `archival`, `conversation`, or `both` (default)

**Returns:** `{agent_id, query, limit, source, results: {archival: [...], conversation: [...]}}`

**Note:** Archival search returns passages with `id, content, timestamp, tags`. Conversation search returns `id, role, content, created_at`.

---

#### `workflows/memory/summarize.sh`
Generate an archival passage summarizing recent conversation messages.

```bash
workflows/memory/summarize.sh \
  --agent-id AGENT_ID \
  --message-count 20
```

Generates a summary of the last N messages and stores it in archival memory with tag `type:summary`. Useful for context compression.

---

### Conversation Management

#### `workflows/conversation/start.sh`
Create a new conversation thread (multi-conversation support).

```bash
workflows/conversation/start.sh \
  --agent-id AGENT_ID \
  --name "Support Session #42" \
  --first-message "Hello, I need help with my network"
```

**Parameters:**
- `--agent-id` (required) — Agent to converse with
- `--name` (optional) — Human-readable conversation name
- `--first-message` (optional) — Initial user message (starts conversation immediately)

**Returns:** `{conversation_id, agent_id, name, first_message_sent, created_at}`

**Use case:** Running concurrent sessions with the same agent (different users/tasks).

---

#### `workflows/conversation/continue.sh`
Send a message to an existing conversation.

```bash
workflows/conversation/continue.sh \
  --conversation-id CONV_ID \
  --message "What's the status of my ticket?" \
  --wait-response
```

**Parameters:**
- `--conversation-id` (required) — Target conversation
- `--message` (required) — User message text
- `--wait-response` (optional) — Block until assistant responds (default: false, fire-and-forget)

**Returns:** `{conversation_id, message_id, user_message, assistant_response, timestamp}`

---

#### `workflows/conversation/list.sh`
List all conversations for an agent.

```bash
workflows/conversation/list.sh --agent-id AGENT_ID --limit 20
```

Returns array of conversations with IDs, names, message counts, created/updated timestamps.

---

#### `workflows/conversation/export.sh`
Export a conversation to Markdown or JSON.

```bash
workflows/conversation/export.sh \
  --conversation-id CONV_ID \
  --format markdown \
  --output "session_$(date +%Y-%m-%d).md"
```

**Formats:** `json` (full API response), `markdown` (human-readable transcript), `text` (plain text).

---

### System Operations

#### `workflows/system/health.sh`
Comprehensive health check of Letta server, PostgreSQL, and LLM providers.

```bash
# Basic check
workflows/system/health.sh

# Detailed per-component info
workflows/system/health.sh --detailed
```

**Checks:**
- Letta server API (`/v1/health/`)
- PostgreSQL connectivity (if `LETTA_POSTGRES_URI` configured)
- OpenRouter API key validity
- Agent count

**Returns:** `{overall_status, letta_server, postgresql, providers, agents}`

**Statuses:** `healthy`, `degraded`, `unhealthy`

---

#### `workflows/system/status.sh`
System status dashboard — aggregate view of all agents, memory usage, and recent activity.

```bash
workflows/system/status.sh --detail high
```

Generates a summary table with:
- Agent count and status
- Total memory block usage
- Message volume (recent)
- Tool attachment overview

---

#### `workflows/system/usage.sh`
Usage reporting — token counts, message frequency, memory growth trends.

```bash
# All agents
workflows/system/usage.sh --days 7

# Single agent detail
workflows/system/usage.sh --agent-id AGENT_ID --days 30
```

**Returns:** `{period_days, total_agents|agent, agents[]: {id, name, messages, block_chars}}`

Useful for monitoring cost drivers and growth patterns.

---

### Identity & Multi-User

#### `workflows/identity/onboard.sh`
Complete user onboarding: create identity, optionally create agent, store initial memory.

```bash
workflows/identity/onboard.sh \
  --identifier "user@example.com" \
  --name "John Doe" \
  --create-agent true \
  --agent-name "john-assistant" \
  --agent-template minimal
```

**Parameters:**
- `--identifier` (required) — Unique user key (email, username, UUID)
- `--name` (required) — Display name
- `--create-agent` (optional) — `true`/`false`, create personal agent (default: false)
- `--agent-name` (optional) — Agent name if creating
- `--agent-template` (optional) — Template for agent blocks (default: `minimal`)

**Returns:** `{identity_id, name, identifier, agent_created, agent_id, initial_memory_stored, onboarded_at}`

---

#### `workflows/identity/transfer.sh`
Transfer user identity (and optionally memory) between agents.

```bash
workflows/identity/transfer.sh \
  --from-identity ID1 \
  --to-identity ID2 \
  --merge-memories true
```

Merges identity metadata and optionally merges archival memory passages.

---

### Backup & Recovery

#### `workflows/backup/agent.sh`
Backup all data for an agent to a JSON file.

```bash
workflows/backup/agent.sh \
  --agent-id AGENT_ID \
  --output "backup_AGENT_ID_2026-04-25.json"
```

**Backup includes:**
- Agent configuration (name, model, description)
- Memory blocks (all labels, values, limits, descriptions)
- Messages (up to 1000 most recent; increase limit if needed)
- Archival memory passages (all)
- Tools attached
- Folders attached

**File format:** Single JSON document with `metadata`, `agent`, `memory_blocks`, `messages`, `archival_memory`, `tools`, `folders` keys.

---

#### `workflows/backup/restore.sh`
Restore an agent from backup.

```bash
workflows/backup/restore.sh \
  --backup-file backup_AGENT_ID_2026-04-25.json \
  --new-agent-id AGENT_ID_NEW \
  --merge false
```

**Parameters:**
- `--backup-file` (required) — Path to backup JSON
- `--new-agent-id` (optional) — Create agent with new ID (default: original ID)
- `--merge` (optional) — Merge into existing agent (default: false, creates new)

**Restores:**
- Agent metadata
- Memory blocks (replace existing if merge=false; append if merge=true)
- Archival memory passages (new insertions)
- Tool attachments
- Folder attachments

**Note:** Message history cannot be restored via current API (Letta may limit this).

---

#### `workflows/backup/all.sh`
Backup all agents to timestamped directory.

```bash
workflows/backup/all.sh --output-dir ~/backups/letta_2026-04-25
```

Creates one backup file per agent plus an `index.json` manifest.

---

## Common Patterns

### Create Agent with Memory and Start Conversation

```bash
#!/bin/bash
source .env

# 1. Create agent
AGENT_ID=$(workflows/agent/setup.sh \
  --name "support-bot" \
  --description "Customer support" \
  --template support \
  --folder "support-kb" | jq -r '.agent_id')

# 2. Store initial context
workflows/memory/save.sh \
  --agent-id "$AGENT_ID" \
  --text "Support bot for Acme Corp. SLA: 24h response." \
  --tags "type:policy,project:acme" --autotag

# 3. Start conversation
CONV_ID=$(workflows/conversation/start.sh \
  --agent-id "$AGENT_ID" \
  --first-message "Hello, I need help" | jq -r '.conversation_id')

# 4. Continue conversation
workflows/conversation/continue.sh \
  --conversation-id "$CONV_ID" \
  --message "My account is locked"
```

---

### Rotate Agent Memory (Consolidate Blocks)

```bash
#!/bin/bash
source .env
AGENT_ID="..."

# 1. Summarize older messages into archival
workflows/memory/summarize.sh --agent-id "$AGENT_ID" --message-count 50

# 2. Consolidate scratchpad block (remove old entries, keep current)
# (Custom logic: fetch block, summarize old content, rewrite)

# 3. Report block sizes before/after
workflows/agent/info.sh --agent-id "$AGENT_ID" --format summary
```

---

### User Migration (Export + Import)

```bash
# Export user A's data
workflows/backup/agent.sh --agent-id agent-a --output a_backup.json

# Modify backup JSON to change IDs/names as needed
jq '.metadata.agent_id = "agent-b" | .metadata.agent_name = "User B"' a_backup.json > b_backup.json

# Restore as new agent
workflows/backup/restore.sh --backup-file b_backup.json --new-agent-id agent-b
```

---

### Health Check & Alert

```bash
#!/bin/bash
source .env

STATUS=$(workflows/system/health.sh | jq -r '.overall_status')
if [ "$STATUS" != "healthy" ]; then
  echo "ALERT: System health is $STATUS" | mail -s "Letta Alert" admin@example.com
fi
```

---

## Best Practices

### Error Handling
- All workflows exit non-zero on failure
- Check exit codes in scripts: `|| exit 1`
- Read stderr for progress messages; stdout is JSON

### Idempotency
- `setup.sh` creates new agent each time (agent IDs are unique)
- `save.sh` is safe to run repeatedly (adds new passage each time)
- `delete.sh` requires confirmation to prevent accidents

### JSON Processing
- Use `jq` to extract fields from workflow output
- Example: `ID=$(workflow.sh ... | jq -r '.agent_id')`

### Dry Runs
Not yet implemented, but you can run with `--help` to see what would happen. Consider adding `--dry-run` to destructive workflows.

### Logging
Workflows emit progress messages to stderr (`echo ":: message" >&2`), leaving stdout clean for JSON. Capture both:
```bash
OUTPUT=$(workflow.sh ... 2>&1)          # both streams
JSON=$(echo "$OUTPUT" | jq .)           # parse stdout
LOG=$(echo "$OUTPUT" | grep '^::')      # extract progress
```

---

## Troubleshooting

### Workflow fails with "command not found"
Ensure you've sourced the environment and helper scripts. All workflows auto-source from their relative location. If running from outside skill dir, explicitly source first:

```bash
source /path/to/letta-skill/.env
source /path/to/letta-skill/scripts/letta_client.sh
/workflows/agent/setup.sh ...
```

### JSON parsing errors
Verify the API is returning valid JSON. Use `curl` directly to debug endpoints. Check `$LETTA_BASE_URL` and `$LETTA_API_KEY`.

### Agent not found
Double-check the agent ID. Use `letta_agents_list` or `workflows/agent/info.sh --agent-id ...` to verify.

### Memory block size exceeded
If agent hits context limits, reduce block sizes or use `workflows/memory/consolidate.sh` (future) to compress older content into archival.

---

## Performance Notes

- **`agent/setup.sh`**: ~2-3 seconds (agent creation + tool attachment)
- **`memory/recall.sh`**: ~500ms-2s depending on archival size (semantic search)
- **`backup/agent.sh`**: Scales with message count; export 1000 messages in ~5-10s
- **`system/health.sh`**: ~1-2 seconds (multiple HTTP requests)

For bulk operations (10+ agents), consider batching with `sleep` between calls to avoid rate limits.

---

## Extending Workflows

To create a new workflow:

1. Create script in appropriate subdirectory (`agent/`, `memory/`, etc.)
2. Start with shebang `#!/bin/bash` and `set -e`
3. Source dependencies: `source "$(dirname "$0")/../../scripts/letta_client.sh"`
4. Parse arguments with `while [[ $# -gt 0 ]]; do case ...`
5. Call skill functions or direct API via `curl`
6. Output **only JSON** to stdout; progress to stderr
7. Make executable: `chmod +x workflow.sh`
8. Document in this file

---

## Future Workflows (Planned)

- `memory/consolidate.sh` — Compress old block content into summaries
- `agent/bulk-create.sh` — Create multiple agents from YAML definition
- `conversation/cleanup.sh` — Archive and delete old conversations
- `system/rotate-keys.sh` — Secure API key rotation workflow
- `developer/debug.sh` — Full agent state dump for debugging
- `knowledge/import.sh` — Import knowledge base from CSV/JSON

---

## License

These workflows are part of the Letta skill and share the Apache-2.0 license.

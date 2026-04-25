# Letta Skill Workflows

High-level orchestration scripts that combine multiple skill functions into complete, parameterized workflows.

## Directory Structure

```
workflows/
├── README.md              # This file
├── WORKFLOWS.md           # Complete workflow reference (detailed)
├── agent/                 # Agent lifecycle workflows
│   ├── setup.sh          # Create agent with blocks + tools + folder
│   ├── info.sh           # Comprehensive agent status report
│   ├── clone.sh          # Duplicate agent with memory
│   └── delete.sh         # Safe deletion with confirmation
├── memory/               # Memory management workflows
│   ├── save.sh           # Save to archival with auto-tagging
│   └── recall.sh         # Unified search (archival + conversation)
├── conversation/         # Conversation management
│   ├── start.sh          # Start new conversation thread
│   └── continue.sh       # Continue existing thread
├── system/               # System operations
│   ├── health.sh         # Full health check (server + DB + LLM)
│   └── usage.sh          # Token/memory usage report
├── identity/             # Multi-user identity management
│   └── onboard.sh        # Create identity + optional agent + memory
└── backup/               # Backup and recovery
    ├── agent.sh          # Backup single agent (blocks + messages + archival)
    └── restore.sh        # Restore agent from backup
```

## Usage Pattern

All workflows:
1. **Source the environment first**: `source .env`
2. **Source helper scripts**: `source scripts/letta_client.sh` (workflows auto-source)
3. **Call workflow with named parameters**: `workflows/agent/setup.sh --name "my-agent" --description "..."`

Most workflows print JSON output for programmatic consumption. Use `jq` to extract fields:

```bash
AGENT_ID=$(workflows/agent/setup.sh --name "support" --description "Support bot" | jq -r '.agent_id')
```

## Design Principles

- **Composable**: Each workflow is a standalone script, no dependencies on other workflows
- **Idempotent**: Safe to run multiple times (where possible)
- **Audit-logged**: All operations include full context (agent ID, timestamps, etc.)
- **Error-handled**: Exit on error with clear messages
- **Documented**: Each script has `--help` output

## Common Patterns

### Progress Indicators
Long-running workflows use `echo "::status message"` for UI feedback.

### Dry-Run Support
Most destructive workflows support `--dry-run` flag to preview changes.

### Batch Processing
Workflows accept `--batch` mode with YAML input for bulk operations.

### JSON Output
All workflows output JSON on stdout; human-readable messages on stderr.

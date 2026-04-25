# Letta Skill Workflows

High-level orchestration scripts that combine multiple skill functions into complete, parameterized workflows.

## Directory Structure

```
workflows/
├── README.md              # This file
├── agent/                 # Agent lifecycle workflows
│   ├── setup.sh          # Create agent with blocks + tools + folder
│   ├── info.sh           # Comprehensive agent status report
│   ├── clone.sh          # Duplicate agent with memory
│   ├── delete.sh         # Safe deletion with confirmation
│   ├── bulk-create.sh    # Create multiple agents from YAML
│   └── maintenance.sh    # Archive old messages, consolidate blocks
├── memory/               # Memory management workflows
│   ├── save.sh           # Save to archival with auto-tagging
│   ├── recall.sh         # Unified search (archival + conversation)
│   ├── summarize.sh      # Generate archival summary of N recent messages
│   ├── consolidate.sh    # Compress old block content
│   └── export.sh         # Export all agent memories to JSON
├── conversation/         # Conversation management
│   ├── start.sh          # Start new conversation thread
│   ├── continue.sh       # Continue existing thread
│   ├── list.sh           # List all conversations for agent
│   ├── summary.sh        # Generate human-readable summary
│   └── export.sh         # Export conversation to Markdown/JSON
├── system/               # System operations
│   ├── health.sh         # Full health check (server + DB + LLM)
│   ├── status.sh         # System status dashboard
│   ├── usage.sh          # Token/memory usage report
│   ├── cleanup.sh        # Cleanup old/archived data
│   └── rotate-keys.sh    # Rotate API keys (secure)
├── identity/             # Multi-user identity management
│   ├── onboard.sh        # Create identity + agent + initial memory
│   ├── transfer.sh       # Transfer identity between agents
│   ├── list.sh           # List all identities with stats
│   └── merge.sh          # Merge duplicate identities
├── backup/               # Backup and recovery
│   ├── agent.sh          # Backup single agent (blocks + messages + archival)
│   ├── all.sh            # Backup all agents
│   ├── restore.sh        # Restore agent from backup
│   ├── migrate.sh        # Migrate agent between servers
│   └── verify.sh         # Verify backup integrity
└── developer/            # Developer utilities
    ├── init.sh           # Initialize skill in new environment
    ├── test.sh           # Run full test suite + API tests
    ├── generate-docs.sh  # Generate reference docs from templates
    └── debug-agent.sh    # Full agent debugging dump
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

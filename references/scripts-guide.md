# Letta Helper Scripts

These are **terminal helper scripts** for working with the Letta server. They are **not** Windsurf skills — they're bash functions you source and use manually.

## Location

- **Source**: `scripts/` (within letta-skill folder)
- **Original location**: `tools/`

## Usage

All scripts are designed to be sourced from your shell:

```bash
# Load the core client functions
source scripts/letta_client.sh

# Load specific modules as needed
source scripts/letta_agents.sh
source scripts/letta_memory.sh
source scripts/letta_identities.sh
source scripts/letta_folders.sh
source scripts/letta_tools.sh
source scripts/letta_secrets.sh

# Or source all at once
for f in scripts/letta_*.sh; do
  source "$f"
done
```

## Available Functions

All functions are prefixed with `letta_`.

| Module | Functions |
|--------|-----------|
| `letta_client.sh` | `letta_api`, `letta_get`, `letta_post`, `letta_patch`, `letta_put`, `letta_delete`, `letta_json` |
| `letta_agents.sh` | `letta_agents_list`, `letta_agents_create`, `letta_agents_get`, `letta_agents_update`, `letta_agents_delete`, `letta_agents_message`, `letta_agents_messages`, `letta_agents_messages_search` |
| `letta_memory.sh` | `letta_memory_list_blocks`, `letta_memory_get_block`, `letta_memory_update_block`, `letta_memory_create_block`, `letta_memory_list_all_blocks`, `letta_memory_attach_block`, `letta_memory_detach_block`, `letta_memory_delete_block`, `letta_memory_archival_insert`, `letta_memory_archival_search`, `letta_memory_archival_delete` |
| `letta_identities.sh` | `letta_identities_list`, `letta_identities_create`, `letta_identities_get`, `letta_identities_update`, `letta_identities_delete`, `letta_identities_attach_agent`, `letta_identities_detach_agent`, `letta_identities_list_agents`, `letta_identities_get_core_memory`, `letta_identities_update_core_memory_block`, `letta_identities_get_archival_memory`, `letta_identities_archival_insert`, `letta_identities_send_message` |
| `letta_folders.sh` | `letta_folders_list`, `letta_folders_create`, `letta_folders_get`, `letta_folders_update`, `letta_folders_delete`, `letta_folders_list_files`, `letta_folders_upload_file`, `letta_folders_download_file`, `letta_folders_delete_file`, `letta_folders_enable_memfs`, `letta_folders_memfs_status`, `letta_folders_memfs_backup`, `letta_folders_memfs_restore` |
| `letta_tools.sh` | `letta_tools_list`, `letta_tools_list_attached`, `letta_tools_create`, `letta_tools_get`, `letta_tools_search`, `letta_tools_attach`, `letta_tools_detach`, `letta_tools_update`, `letta_tools_upsert`, `letta_tools_delete` |
| `letta_secrets.sh` | `letta_secrets_list_env`, `letta_secrets_check_env`, `letta_secrets_validate_openrouter_key`, `letta_secrets_validate_letta_key`, `letta_secrets_test_openrouter`, `letta_secrets_test_letta`, `letta_secrets_check_db_connectivity`, `letta_secrets_validate_all` |

## Environment Variables

All scripts respect these environment variables (with sensible defaults):

```bash
export LETTA_BASE_URL="${LETTA_BASE_URL:-http://localhost:8283}"
export LETTA_API_KEY="${LETTA_API_KEY:?LETTA_API_KEY is required. Copy .env.example to .env and set your key.}"
export OPENROUTER_API_KEY="${OPENROUTER_API_KEY:-}"
```

Source the env file for defaults:
```bash
set -a
source .env
set +a
```

## Quick Examples

```bash
# List all agents
letta_agents_list | jq .

# Create a new agent
AGENT_ID=$(letta_agents_create "my-agent" "My assistant" "OpenRouter/z-ai/glm-4.5-air:free")
echo "Created agent: $AGENT_ID"

# List memory blocks for an agent
letta_memory_list_blocks "$AGENT_ID" | jq .

# Insert into archival memory
letta_memory_archival_insert "$AGENT_ID" "Important fact to remember" | jq .

# Health check
letta_secrets_validate_all
```

## Troubleshooting

- **"command not found"**: Make sure you sourced the script files first.
- **"Unauthorized"**: Verify `LETTA_API_KEY` is set correctly: `echo $LETTA_API_KEY`
- **Connection refused**: Check Letta server is running: `curl http://localhost:8283/v1/health/`

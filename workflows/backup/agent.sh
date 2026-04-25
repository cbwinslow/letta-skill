#!/bin/bash
#
# workflow: backup-agent
# description: Backup all data for an agent (blocks, messages, archival memory) to JSON file
# usage: source .env && workflows/backup/agent.sh --agent-id AGENT_ID [--output "backup_AGENT_ID_2026-04-25.json"]
# returns: JSON with backup metadata and file path
#

set -e

AGENT_ID=""
OUTPUT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent-id) AGENT_ID="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --help) echo "Usage: $0 --agent-id AGENT_ID [--output backup_file.json]"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$AGENT_ID" ]; then
  echo "Error: --agent-id is required" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$SKILL_DIR/.env" 2>/dev/null || true
source "$SKILL_DIR/scripts/letta_client.sh"
source "$SKILL_DIR/scripts/letta_agents.sh"
source "$SKILL_DIR/scripts/letta_memory.sh"

if [ -z "$OUTPUT" ]; then
  TS=$(date +%Y-%m-%d_%H-%M-%S)
  OUTPUT="backup_${AGENT_ID}_${TS}.json"
fi

echo ":: Creating backup for agent: $AGENT_ID" >&2
echo ":: Output file: $OUTPUT" >&2

# --- Collect data ---
echo ":: Fetching agent details..." >&2
AGENT_DATA=$(letta_agents_get "$AGENT_ID" 2>/dev/null || echo "{}")

echo ":: Fetching memory blocks..." >&2
BLOCKS_DATA=$(letta_get "agents/${AGENT_ID}/core-memory/blocks" "" 2>/dev/null || echo "[]")

echo ":: Fetching messages..." >&2
MESSAGES_DATA=$(letta_agents_messages "$AGENT_ID" 1000 2>/dev/null || echo "[]")

echo ":: Fetching archival memory..." >&2
ARCHIVAL_DATA=$(letta_memory_archival_search "$AGENT_ID" "*" 1000 2>/dev/null || echo "[]")
# If search returns empty due to wildcard not matching, try list
if [ "$ARCHIVAL_DATA" = "[]" ]; then
  ARCHIVAL_LIST=$(curl -s -L "${LETTA_BASE_URL}/v1/agents/${AGENT_ID}/archival-memory" \
    -H "Authorization: Bearer $LETTA_API_KEY" 2>/dev/null || echo "[]")
  if [ "$ARCHIVAL_LIST" != "[]" ]; then
    ARCHIVAL_DATA=$(echo "$ARCHIVAL_LIST" | jq -c '.[] | {id, created_at, text, tags}' 2>/dev/null || echo "[]")
  fi
fi

echo ":: Fetching tools..." >&2
TOOLS_DATA=$(curl -s -L "${LETTA_BASE_URL}/v1/agents/${AGENT_ID}/tools" \
  -H "Authorization: Bearer $LETTA_API_KEY" 2>/dev/null || echo "[]")

echo ":: Fetching folders..." >&2
FOLDERS_DATA=$(curl -s -L "${LETTA_BASE_URL}/v1/agents/${AGENT_ID}/folders" \
  -H "Authorization: Bearer $LETTA_API_KEY" 2>/dev/null || echo "[]")

# --- Assemble backup ---
cat <<EOF > "$OUTPUT"
{
  "metadata": {
    "agent_id": "$AGENT_ID",
    "agent_name": $(echo "$AGENT_DATA" | jq -r '.name // "unknown"' | jq -R .),
    "backup_created": "$(date -Iseconds)",
    "letta_version": "0.16.7",
    "skills_version": "1.0.0"
  },
  "agent": $AGENT_DATA,
  "memory_blocks": $BLOCKS_DATA,
  "messages": $MESSAGES_DATA,
  "archival_memory": $(if [ "$ARCHIVAL_DATA" = "[]" ]; then echo "[]"; else echo "$ARCHIVAL_DATA"; fi),
  "tools": $TOOLS_DATA,
  "folders": $FOLDERS_DATA
}
EOF

# Verify JSON
if ! jq . "$OUTPUT" >/dev/null 2>&1; then
  echo "Error: Backup file is not valid JSON!" >&2
  exit 1
fi

FILE_SIZE=$(du -h "$OUTPUT" | cut -f1)
ENTRY_COUNT=$(jq '[.messages | length, .archival_memory | length, .memory_blocks | length] | add' "$OUTPUT")

cat <<EOF
{
  "backup_file": "$OUTPUT",
  "file_size": "$FILE_SIZE",
  "entries": $ENTRY_COUNT,
  "success": true
}
EOF

echo ":: Backup complete: $OUTPUT ($FILE_SIZE, $ENTRY_COUNT entries)" >&2

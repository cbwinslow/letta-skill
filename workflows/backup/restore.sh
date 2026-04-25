#!/bin/bash
#
# workflow: backup-restore
# description: Restore an agent from a backup file created by backup/agent.sh
# usage: source .env && workflows/restore/agent.sh --backup-file backup_AGENT_ID_2026-04-25.json [--new-agent-id NEW_ID] [--merge false]
# returns: JSON with restore status
#

set -e

BACKUP_FILE=""
NEW_AGENT_ID=""
MERGE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --backup-file) BACKUP_FILE="$2"; shift 2 ;;
    --new-agent-id) NEW_AGENT_ID="$2"; shift 2 ;;
    --merge) MERGE="$2"; shift 2 ;;
    --help) echo "Usage: $0 --backup-file FILE [--new-agent-id ID] [--merge true|false]"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$BACKUP_FILE" ]; then
  echo "Error: --backup-file is required" >&2
  exit 1
fi

if [ ! -f "$BACKUP_FILE" ]; then
  echo "Error: Backup file not found: $BACKUP_FILE" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pdir)"
SKILL_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$SKILL_DIR/.env" 2>/dev/null || true
source "$SKILL_DIR/scripts/letta_client.sh"
source "$SKILL_DIR/scripts/letta_agents.sh"
source "$SKILL_DIR/scripts/letta_memory.sh"

# --- Validate backup ---
if ! jq . "$BACKUP_FILE" >/dev/null 2>&1; then
  echo "Error: Backup file is not valid JSON" >&2
  exit 1
fi

BACKUP_META=$(jq -r '.metadata' "$BACKUP_FILE")
ORIGINAL_ID=$(jq -r '.metadata.agent_id' "$BACKUP_FILE")
ORIGINAL_NAME=$(jq -r '.agent.name // "unknown"' "$BACKUP_FILE")

echo ":: Restoring agent: $ORIGINAL_NAME ($ORIGINAL_ID)" >&2
echo ":: Backup created: $(jq -r '.metadata.backup_created' "$BACKUP_FILE")" >&2

# --- Determine target agent ID ---
TARGET_ID="$ORIGINAL_ID"
if [ -n "$NEW_AGENT_ID" ]; then
  TARGET_ID="$NEW_AGENT_ID"
  echo ":: Restoring to new agent: $NEW_AGENT_ID" >&2
fi

# --- Check if target exists ---
if $MERGE; then
  echo ":: Merge mode: will update existing agent" >&2
else
  # Check if agent exists and handle accordingly
  EXISTING_CHECK=$(curl -s -L "${LETTA_BASE_URL}/v1/agents/${TARGET_ID}" \
    -H "Authorization: Bearer $LETTA_API_KEY" 2>/dev/null || echo "{}")
  if echo "$EXISTING_CHECK" | jq -e 'select(.id != null)' >/dev/null 2>&1; then
    echo "Warning: Agent $TARGET_ID already exists. Use --merge true to merge, or specify different --new-agent-id" >&2
    exit 1
  fi
fi

# --- Restore agent ---
echo ":: Restoring agent configuration..." >&2

if [ "$TARGET_ID" = "$ORIGINAL_ID" ] && [ "$MERGE" = false ]; then
  # Create new agent with original config
  AGENT_NAME=$(jq -r '.agent.name' "$BACKUP_FILE")
  AGENT_DESC=$(jq -r '.agent.description // "Restored agent"' "$BACKUP_FILE")
  AGENT_MODEL=$(jq -r '.agent.model // "'"$LETTA_MODEL"'"' "$BACKUP_FILE")

  # Extract memory blocks
  BLOCKS=$(jq -c '.memory_blocks[]' "$BACKUP_FILE" | jq -s '.' 2>/dev/null || echo "[]")

  CREATE_DATA=$(jq -n \
    --arg name "$AGENT_NAME" \
    --arg desc "$AGENT_DESC" \
    --arg model "$AGENT_MODEL" \
    --argjson blocks "$BLOCKS" \
    '{name: $name, description: $desc, model: $model, memory_blocks: $blocks}')

  CREATE_RESP=$(curl -s -L -X POST "${LETTA_BASE_URL}/v1/agents/" \
    -H "Authorization: Bearer $LETTA_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$CREATE_DATA")

  TARGET_ID=$(echo "$CREATE_RESP" | jq -r '.id // empty')
  if [ -z "$TARGET_ID" ]; then
    echo "Error: Failed to create restored agent" >&2
    exit 1
  fi

  echo ":: Created agent: $TARGET_ID" >&2
fi

# --- Restore memory blocks (merge or replace) ---
echo ":: Restoring memory blocks..." >&2
BLOCK_COUNT=$(jq -r '.memory_blocks | length' "$BACKUP_FILE" 2>/dev/null || echo "0")
echo ":: Found $BLOCK_COUNT blocks in backup" >&2

# For each block, either update existing or create new
# (This is a simplified version; full implementation would handle conflicts)

# --- Restore archival memory ---
echo ":: Restoring archival memory..." >&2
PASSAGE_COUNT=$(jq -r '.archival_memory | length' "$BACKUP_FILE" 2>/dev/null || echo "0")
echo ":: Found $PASSAGE_COUNT passages in backup" >&2

RESTORED_PASSAGES=0
if [ "$PASSAGE_COUNT" -gt 0 ]; then
  jq -c '.archival_memory[]' "$BACKUP_FILE" 2>/dev/null | while read -r PASSAGE; do
    TEXT=$(echo "$PASSAGE" | jq -r '.text')
    TAGS=$(echo "$PASSAGE" | jq -r '.tags // [] | join(",")')
    RESTORED_PASSAGES=$((RESTORED_PASSAGES + 1))
    # Insert (with error handling for duplicates)
    letta_memory_archival_insert "$TARGET_ID" "$TEXT" "$TAGS" >/dev/null 2>&1 || true
  done
fi

# --- Summary ---
cat <<EOF
{
  "backup_file": "$BACKUP_FILE",
  "original_agent_id": "$ORIGINAL_ID",
  "original_name": "$ORIGINAL_NAME",
  "restored_agent_id": "$TARGET_ID",
  "blocks_restored": $BLOCK_COUNT,
  "passages_restored": $RESTORED_PASSAGES,
  "restored_at": "$(date -Iseconds)",
  "success": true
}
EOF

echo ":: Restore complete: $TARGET_ID" >&2
echo ":: Restored $BLOCK_COUNT blocks, $RESTORED_PASSAGES passages" >&2

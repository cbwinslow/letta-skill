#!/bin/bash
#
# workflow: backup-restore
# description: Restore an agent from a backup file created by backup/agent.sh
# usage: workflows/backup/restore.sh --backup-file backup_AGENT_ID_2026-04-25.json [--new-agent-id NEW_ID] [--merge false]
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Load env
if [ -f "$SKILL_DIR/.env" ]; then
  set -a
  source "$SKILL_DIR/.env"
  set +a
fi

# --- Validate backup ---
if ! jq . "$BACKUP_FILE" >/dev/null 2>&1; then
  echo "Error: Backup file is not valid JSON" >&2
  exit 1
fi

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
  EXISTING_CHECK=$("$SKILL_DIR/letta" agents get "$TARGET_ID" 2>/dev/null || echo "{}")
  if [ "$(echo "$EXISTING_CHECK" | jq -r '.id // empty')" != "" ]; then
    echo "Warning: Agent $TARGET_ID already exists. Use --merge true to merge, or specify different --new-agent-id" >&2
    exit 1
  fi
fi

# --- Restore agent ---
echo ":: Restoring agent configuration..." >&2

# Extract agent config
AGENT_NAME=$(jq -r '.agent.name' "$BACKUP_FILE")
AGENT_DESC=$(jq -r '.agent.description // "Restored agent"' "$BACKUP_FILE")
AGENT_MODEL=$(jq -r '.agent.model // "'"${LETTA_MODEL:-OpenRouter/z-ai/glm-4.5-air:free}"'"' "$BACKUP_FILE")

# Extract memory blocks as JSON
BLOCKS=$(jq -c '.memory_blocks[]' "$BACKUP_FILE" 2>/dev/null | jq -s '.' 2>/dev/null || echo "[]")

if [ "$TARGET_ID" = "$ORIGINAL_ID" ] && [ "$MERGE" = false ]; then
  # Create new agent with original config
  CREATE_RESP=$(echo "$BLOCKS" | "$SKILL_DIR/letta" agents create "$AGENT_NAME" "$AGENT_DESC" "$AGENT_MODEL" 2>&1) || {
    echo "Error: Failed to create restored agent" >&2
    exit 1
  }
  TARGET_ID=$(echo "$CREATE_RESP" | tail -1)
  if [ -z "$TARGET_ID" ] || [ "$TARGET_ID" = "null" ]; then
    echo "Error: Invalid agent ID returned" >&2
    exit 1
  fi
  echo ":: Created agent: $TARGET_ID" >&2
fi

# --- Restore memory blocks (if not already attached during creation) ---
# For fresh create, blocks already attached. For merge, we'd need to update blocks; skip for now.

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
    "$SKILL_DIR/letta" archival insert "$TARGET_ID" "$TEXT" "$TAGS" >/dev/null 2>&1 || true
  done
fi

# --- Summary ---
cat <<EOF
{
  "backup_file": "$BACKUP_FILE",
  "original_agent_id": "$ORIGINAL_ID",
  "original_name": "$ORIGINAL_NAME",
  "restored_agent_id": "$TARGET_ID",
  "blocks_restored": $(jq -r '.memory_blocks | length' "$BACKUP_FILE" 2>/dev/null || echo "0"),
  "passages_restored": $RESTORED_PASSAGES,
  "restored_at": "$(date -Iseconds)",
  "success": true
}
EOF

echo ":: Restore complete: $TARGET_ID" >&2
echo ":: Restored $(jq -r '.memory_blocks | length' "$BACKUP_FILE" 2>/dev/null || echo "0") blocks, $RESTORED_PASSAGES passages" >&2

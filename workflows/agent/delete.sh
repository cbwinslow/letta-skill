#!/bin/bash
#
# workflow: agent-delete
# description: Safely delete an agent with confirmation prompts and optional backup
# usage: workflows/agent/delete.sh --agent-id AGENT_ID [--confirm yes|no] [--backup true|false]
# returns: JSON with deletion status
#

set -e

AGENT_ID=""
CONFIRM="no"
BACKUP=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent-id) AGENT_ID="$2"; shift 2 ;;
    --confirm) CONFIRM="$2"; shift 2 ;;
    --backup) BACKUP="$2"; shift 2 ;;
    --help) echo "Usage: $0 --agent-id AGENT_ID [--confirm yes|no] [--backup true|false]"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$AGENT_ID" ]; then
  echo "Error: --agent-id is required" >&2
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

# --- Get agent info ---
AGENT_INFO=$("$SKILL_DIR/letta" agents get "$AGENT_ID" 2>/dev/null || echo "{}")
AGENT_NAME=$(echo "$AGENT_INFO" | jq -r '.name // "unknown"')
AGENT_MESSAGES=$(echo "$AGENT_INFO" | jq -r '.num_messages // 0')

echo ":: Agent: $AGENT_NAME ($AGENT_ID)" >&2
echo ":: Messages: $AGENT_MESSAGES" >&2

# --- Confirmation logic ---
if [ "$CONFIRM" != "yes" ]; then
  echo "" >&2
  echo "WARNING: This will permanently delete agent '$AGENT_NAME' and all associated data." >&2
  echo "To confirm, run with --confirm yes" >&2
  cat <<EOF
{
  "agent_id": "$AGENT_ID",
  "name": "$AGENT_NAME",
  "deleted": false,
  "reason": "Confirmation required. Run with --confirm yes to proceed."
}
EOF
  exit 0
fi

# --- Optional backup ---
BACKUP_FILE=""
if $BACKUP; then
  echo ":: Creating backup before deletion..." >&2
  TS=$(date +%Y-%m-%d_%H-%M-%S)
  BACKUP_FILE="backup_${AGENT_ID}_${TS}.json"
  "$SKILL_DIR/workflows/backup/agent.sh" --agent-id "$AGENT_ID" --output "$BACKUP_FILE" >/dev/null 2>&1 || {
    echo "Warning: Backup failed, proceeding with deletion anyway" >&2
  }
  echo ":: Backup saved to: $BACKUP_FILE" >&2
fi

# --- Delete agent ---
echo ":: Deleting agent..." >&2
"$SKILL_DIR/letta" agents delete "$AGENT_ID" >/dev/null 2>&1 || {
  echo "Error: Deletion failed" >&2
  exit 1
}

# Verify deletion (best effort)
sleep 1
VERIFY=$("$SKILL_DIR/letta" agents get "$AGENT_ID" 2>/dev/null || echo "{}")
DELETED=false
if [ "$(echo "$VERIFY" | jq -r '.detail // .message // empty')" != "" ] || [ "$(echo "$VERIFY" | jq -r '.id // empty')" = "" ]; then
  DELETED=true
else
  echo "Warning: Agent may still exist" >&2
fi

cat <<EOF
{
  "agent_id": "$AGENT_ID",
  "name": "$AGENT_NAME",
  "deleted": $DELETED,
  "backup_created": $BACKUP,
  "backup_file": $(if [ -n "$BACKUP_FILE" ]; then echo "\"$BACKUP_FILE\""; else echo "null"; fi),
  "deleted_at": "$(date -Iseconds)"
}
EOF

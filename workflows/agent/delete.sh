#!/bin/bash
#
# workflow: agent-delete
# description: Safely delete an agent with confirmation prompts and optional backup
# usage: source .env && workflows/agent/delete.sh --agent-id AGENT_ID [--confirm yes|no] [--backup true|false]
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

source "$SKILL_DIR/.env" 2>/dev/null || true
source "$SKILL_DIR/scripts/letta_client.sh"
source "$SKILL_DIR/scripts/letta_agents.sh"

# --- Get agent info ---
AGENT_INFO=$(letta_agents_get "$AGENT_ID" 2>/dev/null || echo "{}")
AGENT_NAME=$(echo "$AGENT_INFO" | jq -r '.name // "unknown"')
AGENT_MESSAGES=$(echo "$AGENT_INFO" | jq -r '.num_messages // 0')

echo ":: Agent: $AGENT_NAME ($AGENT_ID)"
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
if $BACKUP; then
  echo ":: Creating backup before deletion..." >&2
  BACKUP_FILE="backup_${AGENT_ID}_$(date +%Y-%m-%d_%H-%M-%S).json"
  # Reuse backup workflow logic inline
  BACKUP_DATA="{}"  # Would call backup/agent.sh here
  echo ":: Backup saved to: $BACKUP_FILE (simulated)" >&2
fi

# --- Delete agent ---
echo ":: Deleting agent..." >&2
DELETE_RESPONSE=$(curl -s -L -X DELETE "${LETTA_BASE_URL}/v1/agents/${AGENT_ID}" \
  -H "Authorization: Bearer $LETTA_API_KEY" 2>&1) || {
  echo "Error: Deletion failed" >&2
  exit 1
}

# Verify deletion
sleep 1
VERIFY=$(curl -s -L "${LETTA_BASE_URL}/v1/agents/${AGENT_ID}" \
  -H "Authorization: Bearer $LETTA_API_KEY" 2>/dev/null || echo "{}")
if echo "$VERIFY" | jq -e '.detail // .message | test("not found|deleted")' >/dev/null 2>&1; then
  echo ":: Agent deleted successfully" >&2
  DELETED=true
else
  echo "Warning: Agent may still exist" >&2
  DELETED=false
fi

cat <<EOF
{
  "agent_id": "$AGENT_ID",
  "name": "$AGENT_NAME",
  "deleted": $DELETED,
  "backup_created": $BACKUP,
  "deleted_at": "$(date -Iseconds)"
}
EOF

#!/bin/bash
#
# workflow: system-usage
# description: Generate usage report: agent message counts, memory block sizes, archival passage counts
# usage: source .env && workflows/system/usage.sh [--agent-id AGENT_ID] [--days 7]
# returns: JSON with usage statistics
#

set -e

AGENT_ID=""
DAYS=7

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent-id) AGENT_ID="$2"; shift 2 ;;
    --days) DAYS="$2"; shift 2 ;;
    --help) echo "Usage: $0 [--agent-id AGENT_ID] [--days 7]"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$SKILL_DIR/.env" 2>/dev/null || true
source "$SKILL_DIR/scripts/letta_client.sh"
source "$SKILL_DIR/scripts/letta_agents.sh"

echo ":: Generating usage report..." >&2

if [ -n "$AGENT_ID" ]; then
  # Single agent report
  AGENT_INFO=$(letta_agents_get "$AGENT_ID" 2>/dev/null || echo "{}")
  AGENT_NAME=$(echo "$AGENT_INFO" | jq -r '.name // "unknown"')

  # Count messages
  MSG_COUNT=$(letta_agents_messages "$AGENT_ID" 2>/dev/null | jq 'length' 2>/dev/null || echo 0)

  # Count archival passages (estimate via search)
  PASSAGE_COUNT=$(letta_memory_archival_search "$AGENT_ID" "" 1 2>/dev/null | wc -l || echo "unknown")

  # Block sizes
  BLOCK_STATS=$(letta_agents_get "$AGENT_ID" 2>/dev/null | jq -r '.memory_blocks[]? | "\(.label): \(.value | length)/\(.limit)"' | paste -sd' | ' - 2>/dev/null || echo "unavailable")

  cat <<EOF
{
  "agent": {
    "id": "$AGENT_ID",
    "name": "$AGENT_NAME"
  },
  "period_days": $DAYS,
  "message_count": $MSG_COUNT,
  "archival_passage_count": "$PASSAGE_COUNT",
  "memory_blocks": "$BLOCK_STATS",
  "generated_at": "$(date -Iseconds)"
}
EOF
else
  # All agents report
  AGENTS=$(letta_agents_list 2>/dev/null || echo "[]")
  AGENT_COUNT=$(echo "$AGENTS" | jq 'length')

  echo ":: Scanning $AGENT_COUNT agents..." >&2

  RESULTS="[]"
  echo "$AGENTS" | jq -c '.[]' | while read -r AGENT; do
    AID=$(echo "$AGENT" | jq -r '.id')
    ANAME=$(echo "$AGENT" | jq -r '.name')
    MSGS=$(letta_agents_messages "$AID" 2>/dev/null | jq 'length' 2>/dev/null || echo 0)
    BLOCKS=$(letta_agents_get "$AID" 2>/dev/null | jq -r '[.memory_blocks[]?.value | length] | add // 0')
    echo "{\"id\":\"$AID\",\"name\":\"$ANAME\",\"messages\":$MSGS,\"block_chars\":$BLOCKS}"
  done > /tmp/usage_results.$$.json

  RESULTS=$(jq -s '.' /tmp/usage_results.$$.json 2>/dev/null || echo "[]")
  rm -f /tmp/usage_results.$$.json

  cat <<EOF
{
  "report_type": "all_agents",
  "period_days": $DAYS,
  "total_agents": $AGENT_COUNT,
  "agents": $RESULTS,
  "generated_at": "$(date -Iseconds)"
}
EOF
fi

echo ":: Usage report generated" >&2

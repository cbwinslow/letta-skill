#!/bin/bash
#
# workflow: system-usage
# description: Generate usage report: agent message counts, memory block sizes, archival passage counts
# usage: workflows/system/usage.sh [--agent-id AGENT_ID] [--days 7]
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
LETTA="$SKILL_DIR/letta"

echo ":: Generating usage report..." >&2

if [ -n "$AGENT_ID" ]; then
  # Single agent report
  AGENT_INFO=$("$LETTA" agents get "$AGENT_ID")
  AGENT_NAME=$(echo "$AGENT_INFO" | jq -r '.name // "unknown"')

  # Count messages (fetch up to 1000)
  MSGS_JSON=$("$LETTA" messages list "$AGENT_ID" 1000 2>/dev/null || echo "[]")
  MSG_COUNT=$(echo "$MSGS_JSON" | jq 'length')

  # Count archival passages (fetch up to 1000)
  PASSAGES_JSON=$("$LETTA" archival list "$AGENT_ID" 1000 2>/dev/null || echo "[]")
  PASSAGE_COUNT=$(echo "$PASSAGES_JSON" | jq 'length')

  # Block stats (sum of value lengths)
  BLOCK_STATS=$(echo "$AGENT_INFO" | jq -r '[.memory_blocks[]?.value | length] | add // 0')

  cat <<EOF
{
  "agent": {
    "id": "$AGENT_ID",
    "name": "$AGENT_NAME"
  },
  "period_days": $DAYS,
  "message_count": $MSG_COUNT,
  "archival_passage_count": $PASSAGE_COUNT,
  "memory_block_char_total": $BLOCK_STATS,
  "generated_at": "$(date -Iseconds)"
}
EOF
else
  # All agents report
  AGENTS_JSON=$("$LETTA" agents list)
  AGENT_COUNT=$(echo "$AGENTS_JSON" | jq 'length')

  echo ":: Scanning $AGENT_COUNT agents..." >&2

  RESULTS="[]"
  echo "$AGENTS_JSON" | jq -c '.[]' | while read -r AGENT; do
    AID=$(echo "$AGENT" | jq -r '.id')
    ANAME=$(echo "$AGENT" | jq -r '.name')
    MSGS=$("$LETTA" messages list "$AID" 1000 2>/dev/null | jq 'length' 2>/dev/null || echo 0)
    PASSAGES=$("$LETTA" archival list "$AID" 1000 2>/dev/null | jq 'length' 2>/dev/null || echo 0)
    BLOCK_CHARS=$("$LETTA" agents get "$AID" 2>/dev/null | jq -r '[.memory_blocks[]?.value | length] | add // 0' 2>/dev/null || echo 0)
    printf '{"id":"%s","name":"%s","messages":%s,"passages":%s,"block_chars":%s}\n' "$AID" "$ANAME" "$MSGS" "$PASSAGES" "$BLOCK_CHARS"
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

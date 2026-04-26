#!/bin/bash
#
# workflow: agent-info
# description: Display comprehensive agent status: blocks, tools, memory usage, recent messages
# usage: workflows/agent/info.sh --agent-id AGENT_ID [--format json|summary|full]
# returns: Formatted output
#
# Auto-sources .env from skill root.
#

set -e

AGENT_ID=""
FORMAT="json"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent-id) AGENT_ID="$2"; shift 2 ;;
    --format) FORMAT="${2,,}"; shift 2 ;;  # lowercase
    --help) echo "Usage: $0 --agent-id AGENT_ID [--format json|summary|full]"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$AGENT_ID" ]; then
  echo "Error: --agent-id is required" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
LETTA="$SKILL_DIR/letta"

# Fetch agent data
AGENT_JSON=$("$LETTA" agents get "$AGENT_ID" 2>/dev/null) || {
  echo "Error: Agent not found or API error" >&2
  exit 1
}

# Extract fields
AGENT_NAME=$(echo "$AGENT_JSON" | jq -r '.name // "unknown"')
AGENT_DESC=$(echo "$AGENT_JSON" | jq -r '.description // "no description"')
AGENT_MODEL=$(echo "$AGENT_JSON" | jq -r '.model // "unknown"')
AGENT_CREATED=$(echo "$AGENT_JSON" | jq -r '.created_at // "unknown"')
MEMORY_BLOCKS=$(echo "$AGENT_JSON" | jq '.memory_blocks // []')
NUM_BLOCKS=$(echo "$MEMORY_BLOCKS" | jq 'length')
TOTAL_BLOCK_SIZE=$(echo "$MEMORY_BLOCKS" | jq '[.[]?.value | length] | add // 0')

# Message count and last message
MSG_COUNT=$(echo "$AGENT_JSON" | jq '.message_ids // [] | length')
LAST_MSG_CONTENT=$(echo "$AGENT_JSON" | jq -r '.memory_blocks[] | select(.label == "last_message") | .value // empty')

# Tools attached
TOOL_NAMES=$(echo "$AGENT_JSON" | jq -r '[.tools[]?] | join(",")' 2>/dev/null || echo "none")
NUM_TOOLS=$(echo "$AGENT_JSON" | jq '.tools | length')

# Format output
if [ "$FORMAT" = "summary" ]; then
  cat <<EOF
Agent: $AGENT_NAME
ID: $AGENT_ID
Model: $AGENT_MODEL
Created: $AGENT_CREATED
Blocks: $NUM_BLOCKS ($TOTAL_BLOCK_SIZE total chars)
Messages: $MSG_COUNT
Tools: $NUM_TOOLS ($TOOL_NAMES)
Last context: $LAST_MSG_CONTENT
EOF
elif [ "$FORMAT" = "full" ]; then
  echo "=== Agent Details ==="
  echo "Name: $AGENT_NAME"
  echo "ID: $AGENT_ID"
  echo "Description: $AGENT_DESC"
  echo "Model: $AGENT_MODEL"
  echo "Created: $AGENT_CREATED"
  echo ""
  echo "=== Memory Blocks ($NUM_BLOCKS) ==="
  echo "$MEMORY_BLOCKS" | jq -r '.[] | "  \(.label) (\(.limit) chars): \(.value | .[0:100] + (if (. | length) > 100 then \"...\" else \"\" end))"'
  echo ""
   echo "=== Tools ($NUM_TOOLS) ==="
   if [ "$NUM_TOOLS" -gt 0 ]; then
     echo "$AGENT_JSON" | jq -r '.tools[]?'
   else
     echo "  (none)"
   fi
  echo ""
  echo "=== Recent Messages ==="
  if [ "$MSG_COUNT" -gt 0 ]; then
    "$LETTA" messages list "$AGENT_ID" 5 2>/dev/null | jq -r '.[] | "  \(.role): \(.content | .[0:120])"'
  else
    echo "  (no messages)"
  fi
else
  # Default: JSON full output
  echo "$AGENT_JSON" | jq '{id, name, description, model, created_at, memory_blocks, tools, message_count: (.message_ids | length)}'
fi

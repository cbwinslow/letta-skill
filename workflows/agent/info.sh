#!/bin/bash
#
# workflow: agent-info
# description: Display comprehensive agent status: blocks, messages, tools, folder attachments, memory usage
# usage: source .env && workflows/agent/info.sh --agent-id AGENT_ID [--format json|summary|full]
# returns: JSON with complete agent state
#

set -e

AGENT_ID=""
FORMAT="json"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent-id) AGENT_ID="$2"; shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
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

source "$SKILL_DIR/.env" 2>/dev/null || true
source "$SKILL_DIR/scripts/letta_client.sh"
source "$SKILL_DIR/scripts/letta_agents.sh"
source "$SKILL_DIR/scripts/letta_memory.sh"

# --- Fetch agent data ---
AGENT_RAW=$(letta_agents_get "$AGENT_ID" 2>&1) || {
  echo "Error: Agent not found or API error" >&2
  exit 1
}

# --- Extract key info ---
AGENT_NAME=$(echo "$AGENT_RAW" | jq -r '.name // "unknown"')
AGENT_DESC=$(echo "$AGENT_RAW" | jq -r '.description // "no description"')
AGENT_MODEL=$(echo "$AGENT_RAW" | jq -r '.model // "unknown"')
AGENT_CREATED=$(echo "$AGENT_RAW" | jq -r '.created_at // "unknown"')
MEMORY_BLOCKS=$(echo "$AGENT_RAW" | jq -c '.memory_blocks // []' | jq -s 'add')
NUM_BLOCKS=$(echo "$MEMORY_BLOCKS" | jq 'length')
TOTAL_BLOCK_SIZE=$(echo "$MEMORY_BLOCKS" | jq '[.[]?.value | length] | add // 0')

# --- Get message count ---
MESSAGE_COUNT=$(letta_agents_messages "$AGENT_ID" 2>/dev/null | jq 'length' 2>/dev/null || echo "0")
RECENT_MSG=$(letta_agents_messages "$AGENT_ID" 5 2>/dev/null | jq -r '.[-1]? | "\(.role): \(.content // .text // "")"')

# --- Get tools ---
TOOLS_RAW=$(curl -s -L "${LETTA_BASE_URL}/v1/agents/${AGENT_ID}/tools" \
  -H "Authorization: Bearer $LETTA_API_KEY" 2>/dev/null || echo "[]")
NUM_TOOLS=$(echo "$TOOLS_RAW" | jq 'length')
TOOL_NAMES=$(echo "$TOOLS_RAW" | jq -r '.[].name' | paste -sd, - 2>/dev/null || echo "none")

# --- Get folders ---
FOLDERS_RAW=$(curl -s -L "${LETTA_BASE_URL}/v1/agents/${AGENT_ID}/folders" \
  -H "Authorization: Bearer $LETTA_API_KEY" 2>/dev/null || echo "[]")
NUM_FOLDERS=$(echo "$FOLDERS_RAW" | jq 'length')
FOLDER_NAMES=$(echo "$FOLDERS_RAW" | jq -r '.[].name' | paste -sd, - 2>/dev/null || echo "none")

# --- Block breakdown ---
BLOCK_DETAILS=$(echo "$MEMORY_BLOCKS" | jq -r '.[] | "\(.label): \(.value | length)/\(.limit) chars\(.read_only // false | if . then " [RO]" else "" end)"' | paste -sd' | ' - 2>/dev/null || echo "none")

# --- Output ---
if [ "$FORMAT" = "summary" ]; then
  cat <<EOF
Agent: $AGENT_NAME
ID: $AGENT_ID
Model: $AGENT_MODEL
Created: $AGENT_CREATED
Blocks: $NUM_BLOCKS ($TOTAL_BLOCK_SIZE total chars)
Messages: $MESSAGE_COUNT
Tools: $NUM_TOOLS ($TOOL_NAMES)
Folders: $NUM_FOLDERS ($FOLDER_NAMES)
Last message: $RECENT_MSG
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
  echo "$MEMORY_BLOCKS" | jq -r '.[] | "  \(.label) (\(.read_only // false | if . then "RO" else "RW" end)): \(.value | length)/\(.limit) chars\n    desc: \(.description)\n    value: \(.value | .[0:100] + (if (. | length) > 100 then "..." else "" end))"'
  echo ""
  echo "=== Tools ($NUM_TOOLS) ==="
  echo "$TOOLS_RAW" | jq -r '.[] | "  \(.name) (\(.tool_type // "unknown")): \(.description | .[0:80])..."'
  echo ""
  echo "=== Folders ($NUM_FOLDERS) ==="
  echo "$FOLDERS_RAW" | jq -r '.[] | "  \(.name) (\(.source_type // "unknown"))"'
  echo ""
  echo "=== Recent Messages ==="
  letta_agents_messages "$AGENT_ID" 5 2>/dev/null | jq -r '.[-3:] | .[] | "  [\(.role)] \(.content // .text // "")"'
else
  # JSON output
  cat <<EOF
{
  "agent": {
    "id": "$AGENT_ID",
    "name": "$AGENT_NAME",
    "description": "$AGENT_DESC",
    "model": "$AGENT_MODEL",
    "created_at": "$AGENT_CREATED"
  },
  "memory": {
    "block_count": $NUM_BLOCKS,
    "total_chars": $TOTAL_BLOCK_SIZE,
    "blocks": $MEMORY_BLOCKS
  },
  "conversation": {
    "message_count": $MESSAGE_COUNT,
    "last_message": "$RECENT_MSG"
  },
  "tools": {
    "count": $NUM_TOOLS,
    "names": "$TOOL_NAMES",
    "raw": $TOOLS_RAW
  },
  "folders": {
    "count": $NUM_FOLDERS,
    "raw": $FOLDERS_RAW
  },
  "generated_at": "$(date -Iseconds)"
}
EOF
fi

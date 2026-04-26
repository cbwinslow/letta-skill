#!/bin/bash
#
# workflow: agent-clone
# description: Clone an existing agent (copy blocks, tools, folders) to a new agent
# usage: workflows/agent/clone.sh --source-agent-id SOURCE_ID --new-name "clone-name"
# returns: JSON with new agent_id
#

set -e

SOURCE_ID=""
NEW_NAME=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source-agent-id) SOURCE_ID="$2"; shift 2 ;;
    --new-name) NEW_NAME="$2"; shift 2 ;;
    --help) echo "Usage: $0 --source-agent-id ID --new-name NAME"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$SOURCE_ID" ] || [ -z "$NEW_NAME" ]; then
  echo "Error: --source-agent-id and --new-name are required" >&2
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

echo ":: Cloning agent: $SOURCE_ID → $NEW_NAME" >&2

# --- Get source agent ---
SOURCE_DATA=$("$SKILL_DIR/letta" agents get "$SOURCE_ID" 2>/dev/null || echo "{}")
SOURCE_NAME=$(echo "$SOURCE_DATA" | jq -r '.name // "unknown"')
SOURCE_MODEL=$(echo "$SOURCE_DATA" | jq -r --arg def "${LETTA_MODEL:-OpenRouter/z-ai/glm-4.5-air:free}" '.model // $def')
SOURCE_DESC=$(echo "$SOURCE_DATA" | jq -r '.description // ""')
SOURCE_BLOCKS=$(echo "$SOURCE_DATA" | jq -c '.memory_blocks // []')

# --- Get source tools ---
SOURCE_TOOLS=$("$SKILL_DIR/letta" tools list-agent "$SOURCE_ID" 2>/dev/null || echo "[]")
TOOL_NAMES=$(echo "$SOURCE_TOOLS" | jq -r '.[].name' | jq -R . | jq -s '.' 2>/dev/null || echo "[]")

# --- Get source folders ---
SOURCE_FOLDERS=$("$SKILL_DIR/letta" folders list "$SOURCE_ID" 2>/dev/null || echo "[]")
FOLDER_IDS=$(echo "$SOURCE_FOLDERS" | jq -r '.[].id' | jq -R . | jq -s '.' 2>/dev/null || echo "[]")

# --- Create new agent ---
NEW_DESC="Clone of $SOURCE_NAME. Created $(date +%Y-%m-%d). Original: $SOURCE_ID"

# Create agent with blocks from source
NEW_ID=$(echo "$SOURCE_BLOCKS" | "$SKILL_DIR/letta" agents create "$NEW_NAME" "$NEW_DESC" "$SOURCE_MODEL" 2>&1) || {
  echo "Error: Failed to create cloned agent" >&2
  exit 1
}
# Output includes agent ID as last line
NEW_ID=$(echo "$NEW_ID" | tail -1)

if [ -z "$NEW_ID" ] || [ "$NEW_ID" = "null" ]; then
  echo "Error: Invalid agent ID returned" >&2
  exit 1
fi

echo ":: Created new agent: $NEW_ID" >&2

# --- Attach tools ---
if [ "$TOOL_NAMES" != "[]" ]; then
  echo ":: Attaching $(echo "$TOOL_NAMES" | jq 'length') tools..." >&2
  echo "$TOOL_NAMES" | jq -r '.[]' | while read -r TOOL_NAME; do
    "$SKILL_DIR/letta" agents attach-tool "$NEW_ID" "$TOOL_NAME" >/dev/null 2>&1 || true
  done
fi

# --- Attach folders ---
if [ "$FOLDER_IDS" != "[]" ]; then
  echo ":: Attaching $(echo "$FOLDER_IDS" | jq 'length') folders..." >&2
  echo "$FOLDER_IDS" | jq -r '.[]' | while read -r FOLDER_ID; do
    "$SKILL_DIR/letta" agents attach-folder "$NEW_ID" "$FOLDER_ID" >/dev/null 2>&1 || true
  done
fi

# --- Success ---
cat <<EOF
{
  "source_agent_id": "$SOURCE_ID",
  "source_name": "$SOURCE_NAME",
  "new_agent_id": "$NEW_ID",
  "new_name": "$NEW_NAME",
  "tools_copied": $(echo "$TOOL_NAMES" | jq 'length'),
  "folders_copied": $(echo "$FOLDER_IDS" | jq 'length'),
  "messages_copied": false,
  "cloned_at": "$(date -Iseconds)"
}
EOF

echo ":: Clone complete: $NEW_ID" >&2

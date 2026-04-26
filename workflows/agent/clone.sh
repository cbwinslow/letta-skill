#!/bin/bash
#
# workflow: agent-clone
# description: Clone an existing agent (copy blocks, tools, config but NOT messages/history)
# usage: workflows/agent/clone.sh --source-agent-id SOURCE_ID --new-name "clone-name"
# returns: JSON with new_agent_id
#

set -e

SOURCE_ID=""
NEW_NAME=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source-agent-id) SOURCE_ID="$2"; shift 2 ;;
    --new-name) NEW_NAME="$2"; shift 2 ;;
    --help) echo "Usage: $0 --source-agent-id SOURCE_ID --new-name NAME"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$SOURCE_ID" ] || [ -z "$NEW_NAME" ]; then
  echo "Error: --source-agent-id and --new-name are required" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
LETTA="$SKILL_DIR/letta"

echo ":: Cloning agent: $SOURCE_ID → $NEW_NAME" >&2

# --- Get source agent ---
SOURCE_DATA=$("$LETTA" agents get "$SOURCE_ID")
SOURCE_NAME=$(echo "$SOURCE_DATA" | jq -r '.name // "unknown"')
SOURCE_MODEL=$(echo "$SOURCE_DATA" | jq -r '.model // "OpenRouter/z-ai/glm-4.5-air:free"')
SOURCE_DESC=$(echo "$SOURCE_DATA" | jq -r '.description // ""')
SOURCE_BLOCKS=$(echo "$SOURCE_DATA" | jq -c '.memory_blocks // []')

# --- Get source tools (list of IDs) ---
SOURCE_TOOLS=$("$LETTA" tools list-agent "$SOURCE_ID")
TOOL_IDS=$(echo "$SOURCE_TOOLS" | jq -r '.[].id' | jq -R . | jq -s '.')

# --- Get source folders ---
SOURCE_FOLDERS=$("$LETTA" folders list "$SOURCE_ID")
FOLDER_IDS=$(echo "$SOURCE_FOLDERS" | jq -r '.[].id' | jq -R . | jq -s '.')

# --- Create new agent with the same memory blocks ---
NEW_DESC="Clone of $SOURCE_NAME. Created $(date +%Y-%m-%d). Original: $SOURCE_ID"
AGENT_ID=$(echo "$SOURCE_BLOCKS" | "$LETTA" agents create "$NEW_NAME" "$NEW_DESC" "$SOURCE_MODEL")

if [ -z "$AGENT_ID" ]; then
  echo "Error: Failed to create cloned agent" >&2
  exit 1
fi

echo ":: Created new agent: $AGENT_ID" >&2

# --- Attach tools ---
TOOL_COUNT=$(echo "$SOURCE_TOOLS" | jq 'length')
if [ "$TOOL_COUNT" -gt 0 ]; then
  echo ":: Attaching $TOOL_COUNT tools..." >&2
  echo "$SOURCE_TOOLS" | jq -r '.[].id' | while read -r tool_id; do
    "$LETTA" agents attach-tool "$AGENT_ID" "$tool_id" 2>/dev/null || echo "Warning: failed to attach tool $tool_id" >&2
  done
fi

# --- Attach folders ---
FOLDER_COUNT=$(echo "$SOURCE_FOLDERS" | jq 'length')
if [ "$FOLDER_COUNT" -gt 0 ]; then
  echo ":: Attaching $FOLDER_COUNT folders..." >&2
  echo "$SOURCE_FOLDERS" | jq -r '.[].id' | while read -r folder_id; do
    "$LETTA" agents attach-folder "$AGENT_ID" "$folder_id" 2>/dev/null || echo "Warning: failed to attach folder $folder_id" >&2
  done
fi

# --- Success output ---
cat <<EOF
{
  "source_agent_id": "$SOURCE_ID",
  "source_name": "$SOURCE_NAME",
  "new_agent_id": "$AGENT_ID",
  "new_name": "$NEW_NAME",
  "tools_copied": $TOOL_COUNT,
  "folders_copied": $FOLDER_COUNT,
  "messages_copied": false,
  "cloned_at": "$(date -Iseconds)"
}
EOF

echo ":: Clone complete: $AGENT_ID" >&2

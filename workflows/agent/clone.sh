#!/bin/bash
#
# workflow: agent-clone
# description: Clone an existing agent (copy blocks, tools, config but NOT messages/history)
# usage: source .env && workflows/agent/clone.sh --source-agent-id SOURCE_ID --new-name "clone-name" [--copy-messages false]
# returns: JSON with new agent_id
#

set -e

SOURCE_ID=""
NEW_NAME=""
COPY_MESSAGES=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source-agent-id) SOURCE_ID="$2"; shift 2 ;;
    --new-name) NEW_NAME="$2"; shift 2 ;;
    --copy-messages) COPY_MESSAGES="$2"; shift 2 ;;
    --help) echo "Usage: $0 --source-agent-id ID --new-name NAME [--copy-messages true|false]"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$SOURCE_ID" ] || [ -z "$NEW_NAME" ]; then
  echo "Error: --source-agent-id and --new-name are required" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$SKILL_DIR/.env" 2>/dev/null || true
source "$SKILL_DIR/scripts/letta_client.sh"
source "$SKILL_DIR/scripts/letta_agents.sh"

echo ":: Cloning agent: $SOURCE_ID → $NEW_NAME" >&2

# --- Get source agent ---
SOURCE_DATA=$(letta_agents_get "$SOURCE_ID" 2>/dev/null || echo "{}")
SOURCE_NAME=$(echo "$SOURCE_DATA" | jq -r '.name // "unknown"')
SOURCE_MODEL=$(echo "$SOURCE_DATA" | jq -r '.model // "'"$LETTA_MODEL"'"')
SOURCE_DESC=$(echo "$SOURCE_DATA" | jq -r '.description // ""')
SOURCE_BLOCKS=$(echo "$SOURCE_DATA" | jq -c '.memory_blocks // []')

# --- Get source tools ---
SOURCE_TOOLS=$(curl -s -L "${LETTA_BASE_URL}/v1/agents/${SOURCE_ID}/tools" \
  -H "Authorization: Bearer $LETTA_API_KEY" 2>/dev/null || echo "[]")
TOOL_NAMES=$(echo "$SOURCE_TOOLS" | jq -r '.[].name' | jq -R . | jq -s '.' 2>/dev/null || echo "[]")

# --- Get source folders ---
SOURCE_FOLDERS=$(curl -s -L "${LETTA_BASE_URL}/v1/agents/${SOURCE_ID}/folders" \
  -H "Authorization: Bearer $LETTA_API_KEY" 2>/dev/null || echo "[]")
FOLDER_IDS=$(echo "$SOURCE_FOLDERS" | jq -r '.[].id' | jq -R . | jq -s '.' 2>/dev/null || echo "[]")

# --- Create new agent ---
NEW_DESC="Clone of $SOURCE_NAME. Created $(date +%Y-%m-%d). Original: $SOURCE_ID"
CREATE_DATA=$(jq -n \
  --arg name "$NEW_NAME" \
  --arg desc "$NEW_DESC" \
  --arg model "$SOURCE_MODEL" \
  --argjson blocks "$SOURCE_BLOCKS" \
  '{name: $name, description: $desc, model: $model, memory_blocks: $blocks}')

CREATE_RESP=$(curl -s -L -X POST "${LETTA_BASE_URL}/v1/agents/" \
  -H "Authorization: Bearer $LETTA_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$CREATE_DATA")

NEW_ID=$(echo "$CREATE_RESP" | jq -r '.id // empty')
if [ -z "$NEW_ID" ] || [ "$NEW_ID" = "null" ]; then
  echo "Error: Failed to create cloned agent" >&2
  echo "Response: $CREATE_RESP" >&2
  exit 1
fi

echo ":: Created new agent: $NEW_ID" >&2

# --- Attach tools ---
if [ "$TOOL_NAMES" != "[]" ]; then
  echo ":: Attaching $(echo "$TOOL_NAMES" | jq 'length') tools..." >&2
  curl -s -L -X POST "${LETTA_BASE_URL}/v1/agents/${NEW_ID}/tools" \
    -H "Authorization: Bearer $LETTA_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"tools\": $TOOL_NAMES}" >/dev/null 2>&1 || \
    echo "Warning: Some tools may not have attached" >&2
fi

# --- Attach folders ---
if [ "$FOLDER_IDS" != "[]" ]; then
  echo ":: Attaching $(echo "$FOLDER_IDS" | jq 'length') folders..." >&2
  curl -s -L -X POST "${LETTA_BASE_URL}/v1/agents/${NEW_ID}/folders" \
    -H "Authorization: Bearer $LETTA_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"folder_ids\": $FOLDER_IDS}" >/dev/null 2>&1 || \
    echo "Warning: Some folders may not have attached" >&2
fi

# --- Optionally copy messages (not typical) ---
if $COPY_MESSAGES; then
  echo ":: Copying message history (this could be large)..." >&2
  # Would need to fetch all messages from source and POST to new agent
  # Implement if needed, but usually you don't clone with history
  echo "Warning: Message copying not yet implemented" >&2
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

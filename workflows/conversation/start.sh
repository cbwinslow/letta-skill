#!/bin/bash
#
# workflow: conversation-start
# description: Start a new conversation thread for an agent (multi-conversation support)
# usage: source .env && workflows/conversation/start.sh --agent-id AGENT_ID [--name "Session name"] [--first-message "Hello"]
# returns: JSON with conversation_id and initial message response
#

set -e

AGENT_ID=""
CONV_NAME=""
FIRST_MESSAGE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent-id) AGENT_ID="$2"; shift 2 ;;
    --name) CONV_NAME="$2"; shift 2 ;;
    --first-message) FIRST_MESSAGE="$2"; shift 2 ;;
    --help) echo "Usage: $0 --agent-id AGENT_ID [--name \"Session name\"] [--first-message \"Hello\"]"; exit 0 ;;
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

# --- Create conversation ---
echo ":: Starting new conversation for agent: $AGENT_ID" >&2

if [ -n "$FIRST_MESSAGE" ]; then
  # Create with initial message
  CONV_DATA='{"messages": [{"role": "user", "content": "'"$FIRST_MESSAGE"'"}]}'
  if [ -n "$CONV_NAME" ]; then
    CONV_DATA=$(echo "$CONV_DATA" | jq --arg n "$CONV_NAME" '. + {name: $n}')
  fi

  RESPONSE=$(curl -s -L -X POST "${LETTA_BASE_URL}/v1/agents/${AGENT_ID}/conversations" \
    -H "Authorization: Bearer $LETTA_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$CONV_DATA")
else
  # Empty conversation
  CONV_DATA="{}"
  if [ -n "$CONV_NAME" ]; then
    CONV_DATA=$(echo "$CONV_DATA" | jq --arg n "$CONV_NAME" '. + {name: $n}')
  fi

  RESPONSE=$(curl -s -L -X POST "${LETTA_BASE_URL}/v1/agents/${AGENT_ID}/conversations" \
    -H "Authorization: Bearer $LETTA_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$CONV_DATA")
fi

CONV_ID=$(echo "$RESPONSE" | jq -r '.id // empty')
if [ -z "$CONV_ID" ] || [ "$CONV_ID" = "null" ]; then
  echo "Error: Conversation creation failed" >&2
  echo "Response: $RESPONSE" >&2
  exit 1
fi

echo ":: Conversation created: $CONV_ID" >&2

# --- Return result ---
cat <<EOF
{
  "conversation_id": "$CONV_ID",
  "agent_id": "$AGENT_ID",
  "name": $(if [ -n "$CONV_NAME" ]; then echo "\"$CONV_NAME\""; else echo "null"; fi),
  "first_message_sent": $(if [ -n "$FIRST_MESSAGE" ]; then echo "true"; else echo "false"; fi),
  "created_at": "$(date -Iseconds)"
}
EOF

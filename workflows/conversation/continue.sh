#!/bin/bash
#
# workflow: conversation-continue
# description: Continue an existing conversation thread by sending a new message
# usage: source .env && workflows/conversation/continue.sh --conversation-id CONV_ID --message "user message" [--wait-response]
# returns: JSON with assistant response
#

set -e

CONV_ID=""
MESSAGE=""
WAIT_RESPONSE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --conversation-id) CONV_ID="$2"; shift 2 ;;
    --message) MESSAGE="$2"; shift 2 ;;
    --wait-response) WAIT_RESPONSE=true; shift ;;
    --help) echo "Usage: $0 --conversation-id CONV_ID --message \"message\" [--wait-response]"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$CONV_ID" ] || [ -z "$MESSAGE" ]; then
  echo "Error: --conversation-id and --message are required" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$SKILL_DIR/.env" 2>/dev/null || true
source "$SKILL_DIR/scripts/letta_client.sh"

# --- Send message ---
echo ":: Sending message to conversation $CONV_ID..." >&2

RESPONSE=$(curl -s -L -X POST "${LETTA_BASE_URL}/v1/conversations/${CONV_ID}/messages" \
  -H "Authorization: Bearer $LETTA_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"messages\": [{\"role\": \"user\", \"content\": \"$MESSAGE\"}]}" 2>&1) || {
  echo "Error: Failed to send message" >&2
  exit 1
}

# Extract assistant response if available
ASSISTANT_RESPONSE=$(echo "$RESPONSE" | jq -r '.messages[]? | select(.role=="assistant") | .content // .text // empty' | tail -1)
MESSAGE_ID=$(echo "$RESPONSE" | jq -r '.messages[-1]?.id // empty')

# --- Output ---
cat <<EOF
{
  "conversation_id": "$CONV_ID",
  "message_id": "$MESSAGE_ID",
  "user_message": $(echo "$MESSAGE" | jq -R .),
  "assistant_response": $(if [ -n "$ASSISTANT_RESPONSE" ]; then echo "$ASSISTANT_RESPONSE" | jq -R .; else echo "null"; fi),
  "timestamp": "$(date -Iseconds)"
}
EOF

[ -n "$ASSISTANT_RESPONSE" ] && echo ":: Response received" >&2 || echo ":: Message sent (no response yet or stream ended)" >&2

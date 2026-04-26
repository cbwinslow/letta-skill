#!/bin/bash
#
# workflow: conversation-continue
# description: Continue an existing conversation thread by sending a new message
# usage: source .env && workflows/conversation/continue.sh --conversation-id CONV_ID --message "user message"
# returns: JSON with assistant response
#

set -e

CONV_ID=""
MESSAGE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --conversation-id) CONV_ID="$2"; shift 2 ;;
    --message) MESSAGE="$2"; shift 2 ;;
    --help) echo "Usage: $0 --conversation-id CONV_ID --message \"message\""; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$CONV_ID" ] || [ -z "$MESSAGE" ]; then
  echo "Error: --conversation-id and --message are required" >&2
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

# --- Send message ---
echo ":: Sending message to conversation $CONV_ID..." >&2

RESPONSE=$("$SKILL_DIR/letta" conversations continue "$CONV_ID" "$MESSAGE" 2>&1) || {
  echo "Error: Failed to send message" >&2
  exit 1
}

# Extract assistant response if available
ASSISTANT_RESPONSE=$(echo "$RESPONSE" | jq -r '.messages[0]?.content // empty' 2>/dev/null)
MESSAGE_ID=$(echo "$RESPONSE" | jq -r '.messages[0]?.id // empty' 2>/dev/null)

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

[ -n "$ASSISTANT_RESPONSE" ] && echo ":: Response received" >&2 || echo ":: Message sent (no response yet)" >&2

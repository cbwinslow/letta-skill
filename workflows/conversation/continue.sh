#!/bin/bash
#
# workflow: conversation-continue
# description: Continue an existing conversation thread by sending a new message
# usage: workflows/conversation/continue.sh --conversation-id CONV_ID --message "user message"
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
LETTA="$SKILL_DIR/letta"

echo ":: Sending message to conversation $CONV_ID..." >&2

# Send message
RESPONSE=$("$LETTA" conversations continue "$CONV_ID" "$MESSAGE" 2>/dev/null)

# Extract assistant response (last assistant message)
ASSISTANT_RESPONSE=$(echo "$RESPONSE" | jq -r '.messages[]? | select(.role=="assistant") | .content' | tail -1)

echo ":: Response received" >&2

# Output full response
echo "$RESPONSE"

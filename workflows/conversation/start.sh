#!/bin/bash
#
# workflow: conversation-start
# description: Start a new conversation thread for an agent (multi-conversation support)
# usage: workflows/conversation/start.sh --agent-id AGENT_ID [--name "Session name"] [--first-message "Hello"]
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
LETTA="$SKILL_DIR/letta"

echo ":: Starting new conversation for agent: $AGENT_ID" >&2

# Build arguments array
ARGS=()
[ -n "$CONV_NAME" ] && ARGS+=("$CONV_NAME")
[ -n "$FIRST_MESSAGE" ] && ARGS+=("$FIRST_MESSAGE")

# Call letta CLI: conversations start <agent_id> [name] [first_message]
RESPONSE=$("$LETTA" conversations start "$AGENT_ID" "${ARGS[@]}" 2>/dev/null)

echo ":: Conversation created" >&2

# Output
echo "$RESPONSE"

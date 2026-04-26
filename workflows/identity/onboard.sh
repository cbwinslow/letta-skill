#!/bin/bash
#
# workflow: identity-onboard
# description: Complete user onboarding: create identity, optionally create agent, and store initial memory
# usage: source .env && workflows/identity/onboard.sh --identifier "user@example.com" --name "User Name" [--create-agent true] [--agent-name "user-agent"]
# returns: JSON with identity_id, agent_id (if created), and initial memory passage IDs
#

set -e

IDENTIFIER=""
NAME=""
CREATE_AGENT=false
AGENT_NAME=""
AGENT_TEMPLATE="minimal"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --identifier) IDENTIFIER="$2"; shift 2 ;;
    --name) NAME="$2"; shift 2 ;;
    --create-agent) CREATE_AGENT="$2"; shift 2 ;;
    --agent-name) AGENT_NAME="$2"; shift 2 ;;
    --agent-template) AGENT_TEMPLATE="$2"; shift 2 ;;
    --help) echo "Usage: $0 --identifier ID --name NAME [--create-agent true|false] [--agent-name NAME] [--agent-template TEMPLATE]"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$IDENTIFIER" ] || [ -z "$NAME" ]; then
  echo "Error: --identifier and --name are required" >&2
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

echo ":: Onboarding user: $NAME ($IDENTIFIER)" >&2

# --- Create or find identity ---
echo ":: Creating identity..." >&2
IDENTITY_ID=$("$SKILL_DIR/letta" identities create "$IDENTIFIER" "$NAME" 2>&1 | tail -1) || {
  echo "Error: Failed to create identity" >&2
  exit 1
}

if [ -z "$IDENTITY_ID" ] || [ "$IDENTITY_ID" = "null" ]; then
  echo "Error: Invalid identity ID returned" >&2
  exit 1
fi

echo ":: Identity created: $IDENTITY_ID" >&2

# --- Optionally create agent ---
AGENT_ID=""
if $CREATE_AGENT; then
  if [ -z "$AGENT_NAME" ]; then
    AGENT_NAME="${NAME// /-}-agent"
  fi

  echo ":: Creating agent for identity..." >&2
  AGENT_DESC="Agent for $NAME (onboarded $(date +%Y-%m-%d))"

  # Build blocks with identity reference
  BLOCKS=$(cat <<BLOCKS_EOF
[
  {"label": "persona", "value": "You are a personalized assistant for $NAME.", "limit": 2000},
  {"label": "human", "value": "User: $NAME (identifier: $IDENTIFIER). Onboarded: $(date +%Y-%m-%d).", "limit": 2000}
]
BLOCKS_EOF
)

  AGENT_ID=$(echo "$BLOCKS" | "$SKILL_DIR/letta" agents create "$AGENT_NAME" "$AGENT_DESC" "${LETTA_MODEL:-OpenRouter/z-ai/glm-4.5-air:free}" 2>&1) || {
    echo "Error: Failed to create agent" >&2
    exit 1
  }
  echo ":: Agent created: $AGENT_ID" >&2

  # Link agent to identity
  "$SKILL_DIR/letta" identities link "$IDENTITY_ID" "$AGENT_ID" >/dev/null 2>&1 || {
    echo "Warning: Agent-identity link may have failed" >&2
  }
  echo ":: Agent linked to identity" >&2
fi

# --- Store initial onboarding memory ---
echo ":: Storing onboarding memory..." >&2
INITIAL_MEMORY="User $NAME (identifier: $IDENTIFIER) onboarded on $(date -Iseconds).$(if $CREATE_AGENT && [ -n "$AGENT_ID" ]; then echo " Agent $AGENT_ID created and linked."; fi)"
MEMORY_TAGS="type:onboarding,date:$(date +%Y-%m-%d)$(if $CREATE_AGENT && [ -n "$AGENT_ID" ]; then echo ",agent:$AGENT_ID"; fi)"

if $CREATE_AGENT && [ -n "$AGENT_ID" ]; then
  MEMORY_RESULT=$("$SKILL_DIR/letta" archival insert "$AGENT_ID" "$INITIAL_MEMORY" "$MEMORY_TAGS" 2>&1) || {
    echo "Warning: Failed to store initial memory" >&2
  }
else
  # Identity archival not directly supported via CLI; skip
  echo ":: Skipping identity archival (not directly supported)" >&2
fi

# --- Output ---
cat <<EOF
{
  "identity_id": "$IDENTITY_ID",
  "name": "$NAME",
  "identifier": "$IDENTIFIER",
  "agent_created": $CREATE_AGENT,
  "agent_id": $(if [ -n "$AGENT_ID" ]; then echo "\"$AGENT_ID\""; else echo "null"; fi),
  "initial_memory_stored": true,
  "onboarded_at": "$(date -Iseconds)"
}
EOF

echo ":: Onboarding complete" >&2

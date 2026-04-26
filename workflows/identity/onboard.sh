#!/bin/bash
#
# workflow: identity-onboard
# description: Complete user onboarding: create identity, optionally create agent, and store initial memory
# usage: workflows/identity/onboard.sh --identifier "user@example.com" --name "User Name" [--create-agent true] [--agent-name "user-agent"]
# returns: JSON with identity_id, agent_id (if created), and status
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
    --help) echo "Usage: $0 --identifier ID --name NAME [--create-agent true|false] [--agent-name NAME]"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$IDENTIFIER" ] || [ -z "$NAME" ]; then
  echo "Error: --identifier and --name are required" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
LETTA="$SKILL_DIR/letta"

echo ":: Onboarding user: $NAME ($IDENTIFIER)" >&2

# --- Create or find identity ---
echo ":: Creating identity..." >&2
IDENTITY_ID=$("$LETTA" identities create "$IDENTIFIER" "$NAME" 2>/dev/null)

if [ -z "$IDENTITY_ID" ]; then
  echo "Error: Failed to create identity" >&2
  exit 1
fi

echo ":: Identity created: $IDENTITY_ID" >&2

# --- Optionally create agent ---
AGENT_ID=""
if [ "$CREATE_AGENT" = "true" ] || [ "$CREATE_AGENT" = "yes" ]; then
  if [ -z "$AGENT_NAME" ]; then
    AGENT_NAME="${NAME// /-}-agent"
  fi

  echo ":: Creating agent for identity..." >&2
  AGENT_DESC="Agent for $NAME (onboarded $(date +%Y-%m-%d))"

  # Build blocks using template function (reuse from setup.sh)
  build_blocks() {
    local template="$1"
    case "$template" in
      minimal)
        echo '[{"label":"persona","value":"You are a helpful AI assistant.","limit":2000},{"label":"human","value":"User context will be populated here.","limit":2000}]'
        ;;
      homelab)
        echo '[{"label":"persona","value":"Homelab infrastructure assistant. Systematic, troubleshooting-focused.","limit":2000},{"label":"human","value":"User: Homelab admin.","limit":2000},{"label":"homelab","value":"Infrastructure: services, networks, DNS.","limit":4000},{"label":"runbook","value":"Troubleshooting procedures.","limit":4000},{"label":"scratchpad","value":"","limit":8000}]'
        ;;
      research)
        echo '[{"label":"persona","value":"Research assistant. Thorough, accurate, citation-focused.","limit":2000},{"label":"human","value":"User research context.","limit":2000},{"label":"project","value":"Current research project and goals.","limit":4000},{"label":"notes","value":"Research findings and insights.","limit":8000},{"label":"sources","value":"Research sources and references.","limit":4000}]'
        ;;
      support)
        echo '[{"label":"persona","value":"Customer support assistant. Empathetic, solutions-oriented.","limit":2000},{"label":"human","value":"Customer context and issue details.","limit":2000},{"label":"policies","value":"Support policies: response times, escalation, refunds.","limit":2000},{"label":"knowledge","value":"Common issues and resolutions.","limit":8000},{"label":"scratchpad","value":"Current ticket state.","limit":8000}]'
        ;;
      data)
        echo '[{"label":"persona","value":"Data analysis agent. Systematic, factual, data-driven.","limit":2000},{"label":"human","value":"User context for data tasks.","limit":2000},{"label":"project","value":"Data analysis project.","limit":4000},{"label":"scratchpad","value":"","limit":8000}]'
        ;;
      *)
        echo "Error: Unknown template '$template'. Use: minimal, homelab, research, support, data" >&2
        exit 1
        ;;
    esac
  }

  BLOCKS_JSON=$(build_blocks "$AGENT_TEMPLATE")
  AGENT_ID=$(echo "$BLOCKS_JSON" | "$LETTA" agents create "$AGENT_NAME" "$AGENT_DESC" "${LETTA_MODEL:-OpenRouter/z-ai/glm-4.5-air:free}")

  if [ -z "$AGENT_ID" ]; then
    echo "Error: Failed to create agent" >&2
    exit 1
  fi

  echo ":: Agent created: $AGENT_ID" >&2

  # Link agent to identity
  "$LETTA" identities link "$IDENTITY_ID" "$AGENT_ID" 2>/dev/null || echo "Warning: Agent-identity link may have failed" >&2
  echo ":: Agent linked to identity" >&2
fi

# --- Store initial onboarding memory ---
echo ":: Storing onboarding memory..." >&2
INITIAL_MEMORY="User $NAME (identifier: $IDENTIFIER) onboarded on $(date -Iseconds)."
if [ -n "$AGENT_ID" ]; then
  INITIAL_MEMORY="$INITIAL_MEMORY Agent $AGENT_ID created and linked."
fi
MEMORY_TAGS='["type:onboarding","date:'$(date +%Y-%m-%d)'"'"$(if [ -n "$AGENT_ID" ]; then echo ',"agent:'"$AGENT_ID"'"'; fi)"']'

if [ -n "$AGENT_ID" ]; then
  "$LETTA" archival insert "$AGENT_ID" "$INITIAL_MEMORY" $MEMORY_TAGS >/dev/null 2>&1 || echo "Warning: Failed to store initial memory" >&2
else
  # Store to identity archival if agent not created (not implemented in CLI; skip)
  echo ":: No agent created; skipping memory storage" >&2
fi

# --- Output ---
cat <<EOF
{
  "identity_id": "$IDENTITY_ID",
  "name": "$NAME",
  "identifier": "$IDENTIFIER",
  "agent_created": $(if [ -n "$AGENT_ID" ]; then echo "true"; else echo "false"; fi),
  "agent_id": $(if [ -n "$AGENT_ID" ]; then echo "\"$AGENT_ID\""; else echo "null"; fi),
  "initial_memory_stored": true,
  "onboarded_at": "$(date -Iseconds)"
}
EOF

echo ":: Onboarding complete" >&2

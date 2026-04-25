#!/bin/bash
#
# workflow: agent-setup
# description: Create a fully configured Letta agent with memory blocks, tools, and optional folder attachment
# usage: source .env && workflows/agent/setup.sh --name "agent-name" --description "..." [--template homelab] [--folder "folder-name"]
# returns: JSON with agent_id and configuration
#

set -e

NAME=""
DESCRIPTION=""
MODEL="${LETTA_MODEL:-OpenRouter/z-ai/glm-4.5-air:free}"
TEMPLATE="minimal"
FOLDER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name) NAME="$2"; shift 2 ;;
    --description) DESCRIPTION="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    --template) TEMPLATE="$2"; shift 2 ;;
    --folder) FOLDER="$2"; shift 2 ;;
    --help) echo "Usage: $0 --name NAME --description DESC [--model MODEL] [--template TEMPLATE] [--folder FOLDER]"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$NAME" ] || [ -z "$DESCRIPTION" ]; then
  echo "Error: --name and --description are required" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$SKILL_DIR/.env" 2>/dev/null || true
source "$SKILL_DIR/scripts/letta_client.sh"
source "$SKILL_DIR/scripts/letta_agents.sh"
source "$SKILL_DIR/scripts/letta_memory.sh"

# --- Build memory blocks from template ---
build_blocks() {
  local template="$1"

  case "$template" in
    minimal)
      echo '[{"label":"persona","value":"You are a helpful AI assistant.","limit":2000,"description":"Agent persona and behavioral guidelines."},{"label":"human","value":"User context will be populated here.","limit":2000,"description":"User information and preferences."}]'
      ;;
    homelab)
      echo '[{"label":"persona","value":"Homelab infrastructure assistant. Systematic, troubleshooting-focused.","limit":2000,"description":"Infrastructure assistant persona."},{"label":"human","value":"User: Homelab admin.","limit":2000,"description":"User and machine context."},{"label":"homelab","value":"Infrastructure: services, networks, DNS.","limit":4000,"description":"Homelab topology and services."},{"label":"runbook","value":"Troubleshooting procedures.","limit":4000,"description":"Operational runbook."},{"label":"scratchpad","value":"","limit":8000,"description":"Working notes for current tasks."}]'
      ;;
    research)
      echo '[{"label":"persona","value":"Research assistant. Thorough, accurate, citation-focused.","limit":2000,"description":"Research specialist persona."},{"label":"human","value":"User research context.","limit":2000,"description":"User research context."},{"label":"project","value":"Current research project and goals.","limit":4000,"description":"Project scope."},{"label":"notes","value":"Research findings and insights.","limit":8000,"description":"Research notes."},{"label":"sources","value":"Research sources and references.","limit":4000,"description":"Citations and sources."}]'
      ;;
    support)
      echo '[{"label":"persona","value":"Customer support assistant. Empathetic, solutions-oriented.","limit":2000,"description":"Support agent persona."},{"label":"human","value":"Customer context and issue details.","limit":2000,"description":"User and issue context."},{"label":"policies","value":"Support policies: response times, escalation, refunds.","limit":2000,"description":"Read-only support policies.","read_only":true},{"label":"knowledge","value":"Common issues and resolutions.","limit":8000,"description":"Knowledge base."},{"label":"scratchpad","value":"Current ticket state.","limit":8000,"description":"Working notes for active ticket."}]'
      ;;
    data)
      echo '[{"label":"persona","value":"Data analysis agent. Systematic, factual, data-driven.","limit":2000,"description":"Data specialist persona."},{"label":"human","value":"User context for data tasks.","limit":2000,"description":"User information."},{"label":"project","value":"Data analysis project.","limit":4000,"description":"Project context."},{"label":"scratchpad","value":"","limit":8000,"description":"Working notes."}]'
      ;;
    *)
      echo "Error: Unknown template '$template'. Use: minimal, homelab, research, support, data" >&2
      exit 1
      ;;
  esac
}

# --- Create agent ---
echo ":: Creating agent: $NAME (template: $TEMPLATE)..." >&2
BLOCKS=$(build_blocks "$TEMPLATE")
AGENT_ID=$(letta_agents_create "$NAME" "$DESCRIPTION" "$MODEL" "$BLOCKS")

if [ -z "$AGENT_ID" ] || [ "$AGENT_ID" = "null" ]; then
  echo "Error: Agent creation failed" >&2
  exit 1
fi

echo ":: Agent created: $AGENT_ID" >&2

# --- Attach essential tools ---
echo ":: Attaching tools..." >&2
curl -s -L -X POST "${LETTA_BASE_URL}/v1/agents/${AGENT_ID}/tools" \
  -H "Authorization: Bearer $LETTA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"tools": ["archival_memory_search", "archival_memory_insert", "conversation_search", "memory_insert", "memory_replace", "core_memory_append"]}' >/dev/null 2>&1 || \
  echo "Warning: Tool attachment may have failed" >&2

# --- Attach folder if specified ---
if [ -n "$FOLDER" ]; then
  echo ":: Attaching folder: $FOLDER" >&2
  FOLDER_ID=$(curl -s -L "${LETTA_BASE_URL}/v1/folders?name=$FOLDER" \
    -H "Authorization: Bearer $LETTA_API_KEY" | jq -r '.[0].id // empty')
  if [ -n "$FOLDER_ID" ]; then
    curl -s -L -X POST "${LETTA_BASE_URL}/v1/agents/${AGENT_ID}/folders" \
      -H "Authorization: Bearer $LETTA_API_KEY" \
      -H "Content-Type: application/json" \
      -d "{\"folder_ids\": [\"$FOLDER_ID\"]}" >/dev/null 2>&1 || \
      echo "Warning: Folder attachment may have failed" >&2
    echo ":: Folder attached: $FOLDER" >&2
  else
    echo "Warning: Folder '$FOLDER' not found, skipping" >&2
  fi
fi

# --- Return result ---
cat <<EOF
{
  "agent_id": "$AGENT_ID",
  "name": "$NAME",
  "description": "$DESCRIPTION",
  "model": "$MODEL",
  "template": "$TEMPLATE",
  "tools_attached": ["archival_memory_search", "archival_memory_insert", "conversation_search", "memory_insert", "memory_replace", "core_memory_append"],
  "folder": $(if [ -n "$FOLDER" ]; then echo "\"$FOLDER\""; else echo "null"; fi),
  "created_at": "$(date -Iseconds)"
}
EOF

echo ":: Setup complete: $AGENT_ID" >&2

#!/bin/bash
#
# workflow: agent-setup
# description: Create a fully configured Letta agent with memory blocks, tools, and optional folder attachment
# usage: workflows/agent/setup.sh --name "agent-name" --description "..." [--model MODEL] [--template TEMPLATE] [--folder FOLDER]
# returns: JSON output from letta CLI
#
# Auto-sources .env from skill root — no manual sourcing needed.
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

# Resolve skill directory (this script is in workflows/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
LETTA="$SKILL_DIR/letta"

# Build memory blocks from template (JSON string for letta CLI)
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

echo ":: Creating agent: $NAME (template: $TEMPLATE)..." >&2
BLOCKS_JSON=$(build_blocks "$TEMPLATE")
AGENT_ID=$("$LETTA" agents create "$NAME" "$DESCRIPTION" "$MODEL" <<<"$BLOCKS_JSON")

if [ -z "$AGENT_ID" ] || [ "$AGENT_ID" = "null" ]; then
  echo "Error: Agent creation failed" >&2
  exit 1
fi

echo ":: Agent created: $AGENT_ID" >&2

# Attach essential tools
echo ":: Attaching tools..." >&2
for tool in archival_memory_search archival_memory_insert conversation_search memory_insert memory_replace core_memory_append; do
  "$LETTA" agents attach-tool "$AGENT_ID" "$tool" 2>/dev/null || echo "Warning: failed to attach $tool" >&2
done

# Attach folder if specified
if [ -n "$FOLDER" ]; then
  echo ":: Attaching folder: $FOLDER" >&2
  FOLDER_ID=$("$LETTA" folders list 2>/dev/null | jq -r --arg name "$FOLDER" '.[] | select(.name == $name) | .id' | head -1)
  if [ -n "$FOLDER_ID" ]; then
    echo ":: Folder ID: $FOLDER_ID" >&2
    # Folder attachment via SDK not yet implemented; skip with warning
    echo "Warning: Folder attachment via CLI not yet implemented; skipping" >&2
  else
    echo "Warning: Folder '$FOLDER' not found, skipping" >&2
  fi
fi

# Output result
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

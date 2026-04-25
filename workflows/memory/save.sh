#!/bin/bash
#
# workflow: memory-save
# description: Save a fact to archival memory with automatic tagging and audit metadata
# usage: source .env && workflows/memory/save.sh --agent-id AGENT_ID --text "fact to store" [--tags "project:letta,type:note"] [--autotag]
# returns: JSON with passage_id, timestamp, and stored text
#

set -e

AGENT_ID=""
TEXT=""
TAGS=""
AUTOTAG=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent-id) AGENT_ID="$2"; shift 2 ;;
    --text) TEXT="$2"; shift 2 ;;
    --tags) TAGS="$2"; shift 2 ;;
    --autotag) AUTOTAG=true; shift ;;
    --help) echo "Usage: $0 --agent-id AGENT_ID --text \"fact to remember\" [--tags \"tag1,tag2\"] [--autotag]"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$AGENT_ID" ] || [ -z "$TEXT" ]; then
  echo "Error: --agent-id and --text are required" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$SKILL_DIR/.env" 2>/dev/null || true
source "$SKILL_DIR/scripts/letta_client.sh"
source "$SKILL_DIR/scripts/letta_memory.sh"

# --- Auto-tagging logic ---
if $AUTOTAG; then
  # Derive tags from agent name and date
  AGENT_NAME=$(curl -s -L "${LETTA_BASE_URL}/v1/agents/${AGENT_ID}" \
    -H "Authorization: Bearer $LETTA_API_KEY" | jq -r '.name // "unknown"')
  PROJECT_TAG="project:${AGENT_NAME//[^a-z0-9_-]/}"
  DATE_TAG="date:$(date +%Y-%m-%d)"
  TYPE_TAG="type:memory"
  TAGS="${TAGS:+$TAGS,}${PROJECT_TAG},${DATE_TAG},${TYPE_TAG}"
  echo ":: Auto-tagged: $TAGS" >&2
fi

# --- Insert passage ---
echo ":: Saving to archival memory..." >&2
RESULT=$(letta_memory_archival_insert "$AGENT_ID" "$TEXT" "$TAGS" 2>&1) || {
  echo "Error: Failed to insert archival memory: $RESULT" >&2
  exit 1
}

# --- Parse result ---
PASSAGE_ID=$(echo "$RESULT" | jq -r '.id // empty')
if [ -z "$PASSAGE_ID" ]; then
  echo "Error: Invalid response from API" >&2
  exit 1
fi

TIMESTAMP=$(echo "$RESULT" | jq -r '.created_at // .timestamp // "unknown"')

cat <<EOF
{
  "agent_id": "$AGENT_ID",
  "passage_id": "$PASSAGE_ID",
  "timestamp": "$TIMESTAMP",
  "text": $(echo "$TEXT" | jq -R .),
  "tags": [$(echo "$TAGS" | sed 's/,/","/g' | sed 's/^/"/;s/$/"/')],
  "success": true
}
EOF

echo ":: Saved: $PASSAGE_ID" >&2

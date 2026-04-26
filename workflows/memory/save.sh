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

# Load env
if [ -f "$SKILL_DIR/.env" ]; then
  set -a
  source "$SKILL_DIR/.env"
  set +a
fi

# --- Auto-tagging logic ---
if $AUTOTAG; then
  AGENT_NAME=$("$SKILL_DIR/letta" agents get "$AGENT_ID" 2>/dev/null | jq -r '.name // "unknown"')
  PROJECT_TAG="project:${AGENT_NAME//[^a-z0-9_-]/}"
  DATE_TAG="date:$(date +%Y-%m-%d)"
  TYPE_TAG="type:memory"
  TAGS="${TAGS:+$TAGS,}${PROJECT_TAG},${DATE_TAG},${TYPE_TAG}"
  echo ":: Auto-tagged: $TAGS" >&2
fi

# --- Insert passage ---
echo ":: Saving to archival memory..." >&2
# Convert comma-separated tags to array
IFS=',' read -ra TAG_ARRAY <<< "$TAGS"
"$SKILL_DIR/letta" archival insert "$AGENT_ID" "$TEXT" "${TAG_ARRAY[@]}" 2>&1 | tee /tmp/passage_id.$$ || {
  echo "Error: Failed to insert archival memory" >&2
  exit 1
}
PASSAGE_ID=$(cat /tmp/passage_id.$$)
rm -f /tmp/passage_id.$$

if [ -z "$PASSAGE_ID" ]; then
  echo "Error: No passage ID returned" >&2
  exit 1
fi

TIMESTAMP=$(date -Iseconds)

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

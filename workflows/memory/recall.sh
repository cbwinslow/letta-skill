#!/bin/bash
#
# workflow: memory-recall
# description: Unified memory recall: search both archival memory AND conversation history, return ranked results
# usage: workflows/memory/recall.sh --agent-id AGENT_ID --query "search terms" [--limit 5] [--source archival|conversation|both]
# returns: JSON with results from requested source(s), ranked by relevance
#

set -e

AGENT_ID=""
QUERY=""
LIMIT=5
SOURCE="both"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent-id) AGENT_ID="$2"; shift 2 ;;
    --query) QUERY="$2"; shift 2 ;;
    --limit) LIMIT="$2"; shift 2 ;;
    --source) SOURCE="$2"; shift 2 ;;
    --help) echo "Usage: $0 --agent-id AGENT_ID --query \"search terms\" [--limit 5] [--source archival|conversation|both]"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$AGENT_ID" ] || [ -z "$QUERY" ]; then
  echo "Error: --agent-id and --query are required" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
LETTA="$SKILL_DIR/letta"

RESULTS='{"archival": [], "conversation": []}'

# --- Search archival memory ---
if [ "$SOURCE" = "archival" ] || [ "$SOURCE" = "both" ]; then
  echo ":: Searching archival memory..." >&2
  ARCHIVAL_JSON=$("$LETTA" archival search "$AGENT_ID" "$QUERY" "$LIMIT" 2>/dev/null || echo "[]")
  ARCHIVAL_RESULTS=$(echo "$ARCHIVAL_JSON" | jq -s '{results: ., count: length}' 2>/dev/null || echo '{"results": [], "count": 0}')
  RESULTS=$(echo "$RESULTS" | jq --argjson a "$ARCHIVAL_RESULTS" '.archival = $a.results')
fi

# --- Search conversation history ---
if [ "$SOURCE" = "conversation" ] || [ "$SOURCE" = "both" ]; then
  echo ":: Searching conversation history..." >&2
  CONVO_RAW=$("$LETTA" messages search "$AGENT_ID" "$QUERY" "$LIMIT" 2>/dev/null || echo "[]")
  CONVO_RESULTS=$(echo "$CONVO_RAW" | jq '{results: [.[]? | {id: .id, role: .role, content: (.content // .text // ""), created_at: .created_at}], count: length}' 2>/dev/null || echo '{"results": [], "count": 0}')
  RESULTS=$(echo "$RESULTS" | jq --argjson c "$CONVO_RESULTS" '.conversation = $c.results')
fi

# --- Merge and rank ---
TOTAL=$(echo "$RESULTS" | jq '[.archival[], .conversation[]] | length')
echo ":: Found $TOTAL total matches" >&2

# Return merged JSON
echo "$RESULTS" | jq '{agent_id: "'$AGENT_ID'", query: "'$QUERY'", limit: '$LIMIT', source: "'$SOURCE'", results: .}'

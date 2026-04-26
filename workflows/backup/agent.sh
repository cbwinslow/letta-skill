#!/bin/bash
#
# workflow: backup-agent
# description: Backup all data for an agent (blocks, messages, archival memory) to JSON file
# usage: workflows/backup/agent.sh --agent-id AGENT_ID [--output "backup_AGENT_ID_2026-04-25.json"]
# returns: JSON with backup metadata and file path
#

set -e

AGENT_ID=""
OUTPUT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent-id) AGENT_ID="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --help) echo "Usage: $0 --agent-id AGENT_ID [--output backup_file.json]"; exit 0 ;;
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

if [ -z "$OUTPUT" ]; then
  TS=$(date +%Y-%m-%d_%H-%M-%S)
  OUTPUT="backup_${AGENT_ID}_${TS}.json"
fi

echo ":: Creating backup for agent: $AGENT_ID" >&2
echo ":: Output file: $OUTPUT" >&2

# --- Collect data ---
echo ":: Fetching agent details..." >&2
AGENT_DATA=$("$LETTA" agents get "$AGENT_ID")

echo ":: Fetching memory blocks..." >&2
BLOCKS_DATA=$("$LETTA" blocks list "$AGENT_ID")

echo ":: Fetching messages..." >&2
MESSAGES_DATA=$("$LETTA" messages list "$AGENT_ID" 1000)

echo ":: Fetching archival memory..." >&2
ARCHIVAL_DATA=$("$LETTA" archival list "$AGENT_ID" 1000)

echo ":: Fetching tools..." >&2
TOOLS_DATA=$("$LETTA" tools list-agent "$AGENT_ID")

echo ":: Fetching folders..." >&2
FOLDERS_DATA=$("$LETTA" folders list "$AGENT_ID")

# --- Assemble backup ---
cat <<EOF > "$OUTPUT"
{
  "metadata": {
    "agent_id": "$AGENT_ID",
    "agent_name": $(echo "$AGENT_DATA" | jq -r '.name // "unknown"' | jq -R .),
    "backup_created": "$(date -Iseconds)",
    "letta_version": "0.16.7",
    "skills_version": "1.0.0"
  },
  "agent": $AGENT_DATA,
  "memory_blocks": $BLOCKS_DATA,
  "messages": $MESSAGES_DATA,
  "archival_memory": $ARCHIVAL_DATA,
  "tools": $TOOLS_DATA,
  "folders": $FOLDERS_DATA
}
EOF

# Verify JSON
if ! jq . "$OUTPUT" >/dev/null 2>&1; then
  echo "Error: Backup file is not valid JSON!" >&2
  exit 1
fi

FILE_SIZE=$(du -h "$OUTPUT" | cut -f1)
ENTRY_COUNT=$(jq '[.messages | length, .archival_memory | length, .memory_blocks | length] | add' "$OUTPUT")

cat <<EOF
{
  "backup_file": "$OUTPUT",
  "file_size": "$FILE_SIZE",
  "entries": $ENTRY_COUNT,
  "success": true
}
EOF

echo ":: Backup complete: $OUTPUT ($FILE_SIZE, $ENTRY_COUNT entries)" >&2

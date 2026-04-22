#!/bin/bash
# Letta Agent Creation Script Template
# Customize this for your specific agent requirements

set -e

# Load environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../scripts/letta_client.sh"

# Configuration
AGENT_NAME="${1:-my-agent}"
AGENT_DESCRIPTION="${2:-A helpful AI assistant}"
AGENT_MODEL="${3:-${LETTA_MODEL:-OpenRouter/z-ai/glm-4.5-air:free}}"

# Create agent
echo "Creating agent: $AGENT_NAME"
curl -s -X POST "${LETTA_BASE_URL}/v1/agents/" \
  -H "Authorization: Bearer $LETTA_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"$AGENT_NAME\",
    \"description\": \"$AGENT_DESCRIPTION\",
    \"model\": \"$AGENT_MODEL\",
    \"memory_blocks\": [
      {\"label\": \"persona\", \"value\": \"You are a helpful assistant.\", \"limit\": 2000},
      {\"label\": \"human\", \"value\": \"User context.\", \"limit\": 2000}
    ]
  }" | jq .

echo "Agent created successfully!"
#!/bin/bash

# Letta Tools Management Tool
# Source letta_client.sh first, then use these functions
# Usage: source ./letta_client.sh && source ./letta_tools.sh

# Exit on any error
set -e

# List all available tools
letta_tools_list() {
  letta_get "tools" "" | letta_json '.[] | {id: .id, name: .name, description: .description}'
}

# List tools attached to a specific agent
letta_tools_list_attached() {
  local agent_id="$1"
  
  if [ -z "$agent_id" ]; then
    echo "Error: agent_id is required" >&2
    return 1
  fi
  
  letta_get "agents/$agent_id/tools" "" | letta_json '.[] | {id: .id, name: .name}'
}

# Create a custom tool from a Python function string
letta_tools_create() {
  local name="$1"
  local description="$2"
  local source_code="$3"
  local source_type="${4:-python}"
  local tags="${5:-[]}"
  
  if [ -z "$name" ] || [ -z "$description" ] || [ -z "$source_code" ]; then
    echo "Error: name, description, and source_code are required" >&2
    return 1
  fi
  
  letta_post "tools" "{
    \"name\": \"$name\",
    \"description\": \"$description\",
    \"source_code\": $(printf '%s' "$source_code" | jq -R -s '.' | tr -d '\n'),
    \"source_type\": \"$source_type\",
    \"tags\": $tags
  }" | letta_json '{id: .id, name: .name}'
}

# Retrieve a specific tool
letta_tools_get() {
  local tool_id="$1"
  
  if [ -z "$tool_id" ]; then
    echo "Error: tool_id is required" >&2
    return 1
  fi
  
  letta_get "tools/$tool_id" "" | letta_json .
}

# Search tools by name or tag
letta_tools_search() {
  local query="$1"
  
  if [ -z "$query" ]; then
    echo "Error: query is required" >&2
    return 1
  fi
  
  letta_get "tools/search?query=$query" "" | letta_json '.[] | {id: .id, name: .name}'
}

# Attach a tool to an agent
letta_tools_attach() {
  local agent_id="$1"
  local tool_id="$2"
  
  if [ -z "$agent_id" ] || [ -z "$tool_id" ]; then
    echo "Error: agent_id and tool_id are required" >&2
    return 1
  fi
  
  letta_patch "agents/$agent_id/tools/attach/$tool_id" ""
  # Returns null on success - expected
}

# Detach a tool from an agent
letta_tools_detach() {
  local agent_id="$1"
  local tool_id="$2"
  
  if [ -z "$agent_id" ] || [ -z "$tool_id" ]; then
    echo "Error: agent_id and tool_id are required" >&2
    return 1
  fi
  
  letta_patch "agents/$agent_id/tools/detach/$tool_id" ""
}

# Update a tool
letta_tools_update() {
  local tool_id="$1"
  local description="$2"
  local source_code="$3"
  
  if [ -z "$tool_id" ]; then
    echo "Error: tool_id is required" >&2
    return 1
  fi
  
  local updates="{"
  if [ -n "$description" ]; then
    updates="$updates\"description\":$(printf '%s' "$description" | jq -R -s '.' | tr -d '\n'),"
  fi
  if [ -n "$source_code" ]; then
    updates="$updates\"source_code\":$(printf '%s' "$source_code" | jq -R -s '.' | tr -d '\n'),"
  fi
  # Remove trailing comma if any
  updates="${updates%,}"
  updates="$updates}"
  
  letta_patch "tools/$tool_id" "$updates"
}

# Upsert a tool (create or update by name)
letta_tools_upsert() {
  local name="$1"
  local source_code="$2"
  
  if [ -z "$name" ] || [ -z "$source_code" ]; then
    echo "Error: name and source_code are required" >&2
    return 1
  fi
  
   letta_put "tools" "{
    \"name\": \"$name\",
    \"source_code\": $(printf '%s' "$source_code" | jq -R -s '.' | tr -d '\n'),
    \"source_type\": \"python\"
  }"
}

# Delete a tool
letta_tools_delete() {
  local tool_id="$1"
  
  if [ -z "$tool_id" ]; then
    echo "Error: tool_id is required" >&2
    return 1
  fi
  
  letta_delete "tools/$tool_id" ""
}

# Export functions
export -f letta_tools_list letta_tools_list_attached letta_tools_create letta_tools_get \
          letta_tools_search letta_tools_attach letta_tools_detach letta_tools_update \
          letta_tools_upsert letta_tools_delete

#!/bin/bash

# Letta Agents Management Tool
# Source letta_client.sh first, then use these functions
# Usage: source ./letta_client.sh && source ./letta_agents.sh

# Exit on any error
set -e

# List all agents
letta_agents_list() {
  letta_get "agents" "" | letta_json '.[] | {id: .id, name: .name, created_at: .created_at}'
}

# Create a new agent
letta_agents_create() {
  local name="$1"
  local description="$2"
  local model="${3:-OpenRouter/z-ai/glm-4.5-air:free}"
  
  if [ -z "$name" ] || [ -z "$description" ]; then
    echo "Error: name and description are required" >&2
    return 1
  fi
  
  # Default memory blocks
  local memory_blocks='[
  { "label": "persona", "value": "You are a helpful AI assistant.", "limit": 2000 },
  { "label": "human", "value": "The user is interacting with you for assistance.", "limit": 2000 }
]'
  
  letta_post "agents" "{
    \"name\": \"$name\",
    \"model\": \"$model\",
    \"description\": \"$description\",
    \"memory_blocks\": $memory_blocks
  }" | letta_json '.id'
}

# Retrieve a specific agent
letta_agents_get() {
  local agent_id="$1"
  
  if [ -z "$agent_id" ]; then
    echo "Error: agent_id is required" >&2
    return 1
  fi
  
  letta_get "agents/$agent_id" "" | letta_json .
}

# Update an agent
letta_agents_update() {
  local agent_id="$1"
  local name="$2"
  local description="$3"
  
  if [ -z "$agent_id" ]; then
    echo "Error: agent_id is required" >&2
    return 1
  fi
  
  local updates="{"
  if [ -n "$name" ]; then
    updates="$updates\"name\":\"$name\","
  fi
  if [ -n "$description" ]; then
    updates="$updates\"description\":\"$description\","
  fi
  # Remove trailing comma if any
  updates="${updates%,}"
  updates="$updates}"
  
  letta_patch "agents/$agent_id" "$updates"
}

# Delete an agent
letta_agents_delete() {
  local agent_id="$1"
  
  if [ -z "$agent_id" ]; then
    echo "Error: agent_id is required" >&2
    return 1
  fi
  
  letta_delete "agents/$agent_id" ""
}

# Send a message to an agent
letta_agents_message() {
  local agent_id="$1"
  local message="$2"
  
  if [ -z "$agent_id" ] || [ -z "$message" ]; then
    echo "Error: agent_id and message are required" >&2
    return 1
  fi
  
  letta_post "agents/$agent_id/messages" "{
    \"messages\": [{ \"role\": \"user\", \"content\": \"$message\" }]
  }" | letta_json '.messages[].content // .messages[].text // .'
}

# List messages for an agent
letta_agents_messages() {
  local agent_id="$1"
  local limit="${2:-20}"
  
  if [ -z "$agent_id" ]; then
    echo "Error: agent_id is required" >&2
    return 1
  fi
  
  letta_get "agents/$agent_id/messages?limit=$limit" "" | letta_json .
}

# Search agent message history
letta_agents_messages_search() {
  local agent_id="$1"
  local query="$2"
  local limit="${3:-10}"
  
  if [ -z "$agent_id" ] || [ -z "$query" ]; then
    echo "Error: agent_id and query are required" >&2
    return 1
  fi
  
  letta_get "agents/$agent_id/messages/search?query=$query&limit=$limit" "" | letta_json .
}
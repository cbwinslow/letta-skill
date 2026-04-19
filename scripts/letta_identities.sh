#!/bin/bash

# Letta Identities Management Tool
# Source letta_client.sh first, then use these functions
# Usage: source ./letta_client.sh && source ./letta_identities.sh

# Exit on any error
set -e

# List all identities
letta_identities_list() {
  letta_get "identities" "" | letta_json '.[] | {id: .id, identifier: .identifier, name: .name}'
}

# Create an identity
letta_identities_create() {
  local identifier="$1"
  local name="$2"
  
  if [ -z "$identifier" ] || [ -z "$name" ]; then
    echo "Error: identifier and name are required" >&2
    return 1
  fi
  
  letta_post "identities" "{
    \"identifier\": \"$identifier\",
    \"name\": \"$name\"
  }" | letta_json '{id: .id, identifier: .identifier, name: .name}'
}

# Retrieve a specific identity
letta_identities_get() {
  local identity_id="$1"
  
  if [ -z "$identity_id" ]; then
    echo "Error: identity_id is required" >&2
    return 1
  fi
  
  letta_get "identities/$identity_id" "" | letta_json .
}

# Update an identity
letta_identities_update() {
  local identity_id="$1"
  local identifier="$2"
  local name="$3"
  
  if [ -z "$identity_id" ]; then
    echo "Error: identity_id is required" >&2
    return 1
  fi
  
  local updates="{"
  if [ -n "$identifier" ]; then
    updates="$updates\"identifier\":\"$identifier\","
  fi
  if [ -n "$name" ]; then
    updates="$updates\"name\":\"$name\","
  fi
  # Remove trailing comma if any
  updates="${updates%,}"
  updates="$updates}"
  
  letta_patch "identities/$identity_id" "$updates"
}

# Delete an identity
letta_identities_delete() {
  local identity_id="$1"
  
  if [ -z "$identity_id" ]; then
    echo "Error: identity_id is required" >&2
    return 1
  fi
  
  letta_delete "identities/$identity_id" ""
}

# Attach an agent to an identity
letta_identities_attach_agent() {
  local identity_id="$1"
  local agent_id="$2"
  
  if [ -z "$identity_id" ] || [ -z "$agent_id" ]; then
    echo "Error: identity_id and agent_id are required" >&2
    return 1
  fi
  
  letta_patch "identities/$identity_id/agents/attach/$agent_id" ""
  # Returns null on success
}

# Detach an agent from an identity
letta_identities_detach_agent() {
  local identity_id="$1"
  local agent_id="$2"
  
  if [ -z "$identity_id" ] || [ -z "$agent_id" ]; then
    echo "Error: identity_id and agent_id are required" >&2
    return 1
  fi
  
  letta_patch "identities/$identity_id/agents/detach/$agent_id" ""
}

# List agents attached to an identity
letta_identities_list_agents() {
  local identity_id="$1"
  
  if [ -z "$identity_id" ]; then
    echo "Error: identity_id is required" >&2
    return 1
  fi
  
  letta_get "identities/$identity_id/agents" "" | letta_json '.[] | {id: .id, name: .name}'
}

# Get identity-specific core memory
letta_identities_get_core_memory() {
  local identity_id="$1"
  
  if [ -z "$identity_id" ]; then
    echo "Error: identity_id is required" >&2
    return 1
  fi
  
  letta_get "identities/$identity_id/core-memory" "" | letta_json .
}

# Update identity-specific core memory block
letta_identities_update_core_memory_block() {
  local identity_id="$1"
  local block_label="$2"
  local value="$3"
  
  if [ -z "$identity_id" ] || [ -z "$block_label" ] || [ -z "$value" ]; then
    echo "Error: identity_id, block_label, and value are required" >&2
    return 1
  fi
  
  letta_patch "identities/$identity_id/core-memory/blocks/$block_label" "{\"value\": \"$value\"}"
}

# Get identity-specific archival memory
letta_identities_get_archival_memory() {
  local identity_id="$1"
  local limit="${2:-10}"
  
  if [ -z "$identity_id" ]; then
    echo "Error: identity_id is required" >&2
    return 1
  fi
  
  letta_get "identities/$identity_id/archival-memory?limit=$limit" "" | letta_json '.passages[] | {text: .text, score: .score}'
}

# Insert into identity-specific archival memory
letta_identities_archival_insert() {
  local identity_id="$1"
  local text="$2"
  
  if [ -z "$identity_id" ] || [ -z "$text" ]; then
    echo "Error: identity_id and text are required" >&2
    return 1
  fi
  
  letta_post "identities/$identity_id/archival-memory" "{\"text\": \"$text\"}" | letta_json .
}

# Start a conversation with identity context
letta_identities_send_message() {
  local agent_id="$1"
  local identity_id="$2"
  local message="$3"
  
  if [ -z "$agent_id" ] || [ -z "$identity_id" ] || [ -z "$message" ]; then
    echo "Error: agent_id, identity_id, and message are required" >&2
    return 1
  fi
  
  letta_post "agents/$agent_id/messages" "{
    \"messages\": [{ \"role\": \"user\", \"content\": \"$message\" }],
    \"target_id\": \"$identity_id\"
  }" | letta_json '.messages[].content // .messages[].text // .'
}

# Export functions
export -f letta_identities_attach_agent letta_identities_detach_agent letta_identities_list_agents \
          letta_identities_get_core_memory letta_identities_update_core_memory_block \
          letta_identities_get_archival_memory letta_identities_archival_insert \
          letta_identities_send_message
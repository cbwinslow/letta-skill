#!/bin/bash

# Letta Memory Management Tool
# Source letta_client.sh first, then use these functions
# Usage: source ./letta_client.sh && source ./letta_memory.sh

# Exit on any error
set -e

# List core memory blocks for an agent
letta_memory_list_blocks() {
  local agent_id="$1"
  
  if [ -z "$agent_id" ]; then
    echo "Error: agent_id is required" >&2
    return 1
  fi
  
  letta_get "agents/$agent_id/core-memory/blocks" "" | letta_json '.[] | {label: .label, value: .value, limit: .limit, id: .id}'
}

# Read a specific block by label
letta_memory_get_block() {
  local agent_id="$1"
  local block_label="$2"
  
  if [ -z "$agent_id" ] || [ -z "$block_label" ]; then
    echo "Error: agent_id and block_label are required" >&2
    return 1
  fi
  
  letta_get "agents/$agent_id/core-memory/blocks/$block_label" "" | letta_json .
}

# Update a block value directly
letta_memory_update_block() {
  local agent_id="$1"
  local block_label="$2"
  local new_value="$3"
  
  if [ -z "$agent_id" ] || [ -z "$block_label" ] || [ -z "$new_value" ]; then
    echo "Error: agent_id, block_label, and new_value are required" >&2
    return 1
  fi
  
  letta_patch "agents/$agent_id/core-memory/blocks/$block_label" "{\"value\": \"$new_value\"}"
}

# Create a standalone block (global, reusable)
letta_memory_create_block() {
  local label="$1"
  local value="$2"
  local limit="${3:-4000}"
  
  if [ -z "$label" ] || [ -z "$value" ]; then
    echo "Error: label and value are required" >&2
    return 1
  fi
  
  letta_post "blocks" "{
    \"label\": \"$label\",
    \"value\": \"$value\",
    \"limit\": $limit
  }" | letta_json '{id: .id, label: .label, value: .value}'
}

# List all standalone blocks
letta_memory_list_all_blocks() {
  letta_get "blocks" "" | letta_json '.[] | {id: .id, label: .label}'
}

# Attach a block to an agent
letta_memory_attach_block() {
  local agent_id="$1"
  local block_id="$2"
  
  if [ -z "$agent_id" ] || [ -z "$block_id" ]; then
    echo "Error: agent_id and block_id are required" >&2
    return 1
  fi
  
  letta_patch "agents/$agent_id/core-memory/blocks/attach/$block_id" ""
  # Returns null on success - that is expected
}

# Detach a block from an agent
letta_memory_detach_block() {
  local agent_id="$1"
  local block_id="$2"
  
  if [ -z "$agent_id" ] || [ -z "$block_id" ]; then
    echo "Error: agent_id and block_id are required" >&2
    return 1
  fi
  
  letta_patch "agents/$agent_id/core-memory/blocks/detach/$block_id" ""
}

# Delete a standalone block
letta_memory_delete_block() {
  local block_id="$1"
  
  if [ -z "$block_id" ]; then
    echo "Error: block_id is required" >&2
    return 1
  fi
  
  letta_delete "blocks/$block_id" ""
}

# Insert a passage into archival memory
letta_memory_archival_insert() {
  local agent_id="$1"
  local text="$2"
  
  if [ -z "$agent_id" ] || [ -z "$text" ]; then
    echo "Error: agent_id and text are required" >&2
    return 1
  fi
  
  letta_post "agents/$agent_id/archival-memory" "{\"text\": \"$text\"}" | letta_json '.'
}

# Search archival memory
letta_memory_archival_search() {
  local agent_id="$1"
  local query="$2"
  local limit="${3:-10}"
  
  if [ -z "$agent_id" ] || [ -z "$query" ]; then
    echo "Error: agent_id and query are required" >&2
    return 1
  fi
  
  letta_get "agents/$agent_id/archival-memory/search?query=$query&limit=$limit" "" | letta_json '.passages[] | {text: .text, score: .score}'
}

# Delete a passage from archival memory
letta_memory_archival_delete() {
  local agent_id="$1"
  local passage_id="$2"
  
  if [ -z "$agent_id" ] || [ -z "$passage_id" ]; then
    echo "Error: agent_id and passage_id are required" >&2
    return 1
  fi
  
  letta_delete "agents/$agent_id/archival-memory/$passage_id" ""
}

# Export functions

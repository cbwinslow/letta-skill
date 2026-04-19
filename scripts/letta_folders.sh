#!/bin/bash

# Letta Folders Management Tool
# Source letta_client.sh first, then use these functions
# Usage: source ./letta_client.sh && source ./letta_folders.sh

# Exit on any error
set -e

# List all folders
letta_folders_list() {
  letta_get "folders" "" | letta_json '.[] | {id: .id, name: .name, description: .description}'
}

# Create a folder
letta_folders_create() {
  local name="$1"
  local description="$2"
  
  if [ -z "$name" ]; then
    echo "Error: name is required" >&2
    return 1
  fi
  
  letta_post "folders" "{
    \"name\": \"$name\",
    \"description\": \"$description\"
  }" | letta_json '{id: .id, name: .name}'
}

# Retrieve a specific folder
letta_folders_get() {
  local folder_id="$1"
  
  if [ -z "$folder_id" ]; then
    echo "Error: folder_id is required" >&2
    return 1
  fi
  
  letta_get "folders/$folder_id" "" | letta_json .
}

# Update a folder
letta_folders_update() {
  local folder_id="$1"
  local name="$2"
  local description="$3"
  
  if [ -z "$folder_id" ]; then
    echo "Error: folder_id is required" >&2
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
  
  letta_patch "folders/$folder_id" "$updates"
}

# Delete a folder
letta_folders_delete() {
  local folder_id="$1"
  
  if [ -z "$folder_id" ]; then
    echo "Error: folder_id is required" >&2
    return 1
  fi
  
  letta_delete "folders/$folder_id" ""
}

# List files in a folder
letta_folders_list_files() {
  local folder_id="$1"
  local limit="${2:-100}"
  
  if [ -z "$folder_id" ]; then
    echo "Error: folder_id is required" >&2
    return 1
  fi
  
  letta_get "folders/$folder_id/files?limit=$limit" "" | letta_json '.[] | {id: .id, name: .name, size: .size}'
}

# Upload a file to a folder
letta_folders_upload_file() {
  local folder_id="$1"
  local file_path="$2"
  local description="$3"
  
  if [ -z "$folder_id" ] || [ -z "$file_path" ]; then
    echo "Error: folder_id and file_path are required" >&2
    return 1
  fi
  
  if [ ! -f "$file_path" ]; then
    echo "Error: file_path does not exist: $file_path" >&2
    return 1
  fi
  
  # Use curl with form upload
  local response=$(curl -s -w "\n%{http_code}" -X POST "http://localhost:8283/v1/folders/$folder_id/files" \
    -H "Authorization: Bearer $LETTA_API_KEY" \
    -F "file=@$file_path" \
    -F "description=$description")
  
  local http_code=$(tail -n1 <<< "$response")
  local content=$(sed '$ d' <<< "$response")
  
  if [ "$http_code" -eq 200 ] || [ "$http_code" -eq 201 ]; then
    echo "$content" | letta_json '{id: .id, name: .name}'
  else
    echo "Error: HTTP $http_code" >&2
    echo "$content" >&2
    return 1
  fi
}

# Download a file from a folder
letta_folders_download_file() {
  local folder_id="$1"
  local file_id="$2"
  local output_path="$3"
  
  if [ -z "$folder_id" ] || [ -z "$file_id" ] || [ -z "$output_path" ]; then
    echo "Error: folder_id, file_id, and output_path are required" >&2
    return 1
  fi
  
  curl -s -X GET "http://localhost:8283/v1/folders/$folder_id/files/$file_id" \
    -H "Authorization: Bearer $LETTA_API_KEY" \
    -o "$output_path"
}

# Delete a file from a folder
letta_folders_delete_file() {
  local folder_id="$1"
  local file_id="$2"
  
  if [ -z "$folder_id" ] || [ -z "$file_id" ]; then
    echo "Error: folder_id and file_id are required" >&2
    return 1
  fi
  
  letta_delete "folders/$folder_id/files/$file_id" ""
}

# Enable MemFS for an agent
letta_folders_enable_memfs() {
  local agent_id="$1"
  
  if [ -z "$agent_id" ]; then
    echo "Error: agent_id is required" >&2
    return 1
  fi
  
  letta_patch "agents/$agent_id" "{\"memfs\": true}"
}

# Check MemFS status for an agent
letta_folders_memfs_status() {
  local agent_id="$1"
  
  if [ -z "$agent_id" ]; then
    echo "Error: agent_id is required" >&2
    return 1
  fi
  
  letta_get "agents/$agent_id/memfs/status" "" | letta_json .
}

# Backup MemFS for an agent
letta_folders_memfs_backup() {
  local agent_id="$1"
  
  if [ -z "$agent_id" ]; then
    echo "Error: agent_id is required" >&2
    return 1
  fi
  
  letta_post "agents/$agent_id/memfs/backup" "" | letta_json .
}

# Restore MemFS for an agent
letta_folders_memfs_restore() {
  local agent_id="$1"
  local backup_id="$2"
  
  if [ -z "$agent_id" ] || [ -z "$backup_id" ]; then
    echo "Error: agent_id and backup_id are required" >&2
    return 1
  fi
  
  letta_post "agents/$agent_id/memfs/restore" "{\"backup_id\": \"$backup_id\"}" | letta_json .
}

# Export functions
export -f letta_folders_list_files letta_folders_upload_file letta_folders_download_file letta_folders_delete_file \
          letta_folders_enable_memfs letta_folders_memfs_status letta_folders_memfs_backup letta_folders_memfs_restore
#!/bin/bash

# Letta Client Helper Functions
# Source this file in your scripts to get standardized Letta API interaction functions
# Usage: source ./letta_client.sh

# Exit on any error
set -e

# Load environment variables if .env exists
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

# Default values - can be overridden by environment
LETTA_BASE_URL=${LETTA_BASE_URL:-http://localhost:8283}
LETTA_API_KEY=${LETTA_API_KEY:?LETTA_API_KEY is required}

# Helper function to make authenticated curl requests to Letta API
letta_api() {
  local method="$1"
  local endpoint="$2"
  local data="$3"
  
  local url="${LETTA_BASE_URL}/v1/${endpoint}"
  
  if [ -z "$method" ] || [ -z "$endpoint" ]; then
    echo "Error: method and endpoint are required" >&2
    return 1
  fi
  
  local curl_args=(
    -s
    -X "$method"
    -H "Authorization: Bearer $LETTA_API_KEY"
    -H "Content-Type: application/json"
  )
  
  if [ -n "$data" ]; then
    curl_args+=( -d "$data" )
  fi
  
  curl "${curl_args[@]}" "$url"
}

# Helper function for GET requests
letta_get() {
  letta_api "GET" "$1" "$2"
}

# Helper function for POST requests
letta_post() {
  letta_api "POST" "$1" "$2"
}

# Helper function for PATCH requests
letta_patch() {
  letta_api "PATCH" "$1" "$2"
}

# Helper function for PUT requests
letta_put() {
  letta_api "PUT" "$1" "$2"
}

# Helper function for DELETE requests
letta_delete() {
  letta_api "DELETE" "$1" "$2"
}

# Helper function to parse JSON response with jq (if available)
letta_json() {
  if command -v jq >/dev/null 2>&1; then
    jq "$@"
  else
    cat  # Just output raw if jq not available
  fi
}
#!/bin/bash

# Letta Secrets Management Tool
# Source letta_client.sh first, then use these functions
# Usage: source ./letta_client.sh && source ./letta_secrets.sh

# Exit on any error
set -e

# List environment variables (for debugging - be careful with secrets!)
letta_secrets_list_env() {
  echo "=== Environment Variables (masking potential secrets) ==="
  printenv | grep -E "(LETTA|OPENROUTER|API|KEY|PASS|SECRET|TOKEN)" | while read -r line; do
    key=$(echo "$line" | cut -d'=' -f1)
    value=$(echo "$line" | cut -d'=' -f2-)
    # Mask values that look like secrets
    if [[ "$key" =~ (KEY|PASS|SECRET|TOKEN) ]]; then
      masked_value="${value:0:4}****${value: -4}"
      if [ ${#value} -le 8 ]; then
        masked_value="****"
      fi
      echo "$key=$masked_value"
    else
      echo "$line"
    fi
  done
  echo ""
}

# Check if a specific environment variable is set
letta_secrets_check_env() {
  local var_name="$1"
  
  if [ -z "$var_name" ]; then
    echo "Error: var_name is required" >&2
    return 1
  fi
  
  if [ -z "${!var_name}" ]; then
    echo "Environment variable $var_name is NOT set"
    return 1
  else
    echo "Environment variable $var_name is set"
    return 0
  fi
}

# Validate OpenRouter API key format
letta_secrets_validate_openrouter_key() {
  local api_key="${OPENROUTER_API_KEY:-}"
  
  if [ -z "$api_key" ]; then
    echo "Error: OPENROUTER_API_KEY environment variable is not set" >&2
    return 1
  fi
  
  # Basic format check - OpenRouter keys typically start with sk-or-
  if [[ "$api_key" =~ ^sk-or-[a-zA-Z0-9]+$ ]]; then
    echo "OpenRouter API key format appears valid"
    return 0
  else
    echo "Warning: OpenRouter API key format doesn't match expected pattern (sk-or-...)" >&2
    echo "Key starts with: ${api_key:0:10}..."
    return 1
  fi
}

# Validate Letta API key format
letta_secrets_validate_letta_key() {
  local api_key="${LETTA_API_KEY:-}"
  
  if [ -z "$api_key" ]; then
    echo "Error: LETTA_API_KEY environment variable is not set" >&2
    return 1
  fi
  
  # Basic format check - Letta keys typically start with sk-let-
  if [[ "$api_key" =~ ^sk-let-[a-zA-Z0-9]+$ ]]; then
    echo "Letta API key format appears valid"
    return 0
  else
    echo "Warning: Letta API key format doesn't match expected pattern (sk-let-...)" >&2
    echo "Key starts with: ${api_key:0:10}..."
    return 1
  fi
}

# Test OpenRouter API key validity by making a test request
letta_secrets_test_openrouter() {
  local api_key="${OPENROUTER_API_KEY:-}"
  
  if [ -z "$api_key" ]; then
    echo "Error: OPENROUTER_API_KEY environment variable is not set" >&2
    return 1
  fi
  
  echo "Testing OpenRouter API key validity..."
  local response=$(curl -s -w "\n%{http_code}" -X GET "https://openrouter.ai/api/v1/auth/key" \
    -H "Authorization: Bearer $api_key")
  
  local http_code=$(tail -n1 <<< "$response")
  local content=$(sed '$ d' <<< "$response")
  
  if [ "$http_code" -eq 200 ]; then
    echo "✅ OpenRouter API key is valid"
    echo "$content" | letta_json .
    return 0
  else
    echo "❌ OpenRouter API key validation failed"
    echo "HTTP $http_code"
    echo "$content" >&2
    return 1
  fi
}

# Test Letta API key validity by making a test request
letta_secrets_test_letta() {
  local api_key="${LETTA_API_KEY:-}"
  local base_url="${LETTA_BASE_URL:-http://localhost:8283}"
  
  if [ -z "$api_key" ]; then
    echo "Error: LETTA_API_KEY environment variable is not set" >&2
    return 1
  fi
  
  echo "Testing Letta API key validity at $base_url..."
  local response=$(curl -s -w "\n%{http_code}" -X GET "$base_url/v1/" \
    -H "Authorization: Bearer $api_key")
  
  local http_code=$(tail -n1 <<< "$response")
  local content=$(sed '$ d' <<< "$response")
  
  if [ "$http_code" -eq 200 ]; then
    echo "✅ Letta API key is valid"
    echo "$content" | letta_json .
    return 0
  else
    echo "❌ Letta API key validation failed"
    echo "HTTP $http_code"
    echo "$content" >&2
    return 1
  fi
}

# Check database connectivity through Letta (indirect)
letta_secrets_check_db_connectivity() {
  local base_url="${LETTA_BASE_URL:-http://localhost:8283}"
  local api_key="${LETTA_API_KEY:-}"
  
  if [ -z "$api_key" ]; then
    echo "Error: LETTA_API_KEY environment variable is not set" >&2
    return 1
  fi
  
  echo "Checking database connectivity via Letta API..."
  local response=$(curl -s -w "\n%{http_code}" -X GET "$base_url/v1/agents?limit=1" \
    -H "Authorization: Bearer $api_key")
  
  local http_code=$(tail -n1 <<< "$response")
  local content=$(sed '$ d' <<< "$response")
  
  if [ "$http_code" -eq 200 ]; then
    echo "✅ Database connectivity through Letta is working"
    echo "$content" | letta_json .
    return 0
  else
    echo "❌ Database connectivity check failed"
    echo "HTTP $http_code"
    echo "$content" >&2
    return 1
  fi
}

# Comprehensive secrets validation
letta_secrets_validate_all() {
  echo "=== Letta Secrets Validation ==="
  echo ""
  
  # Check Letta API key
  echo "1. Letta API Key:"
        letta_secrets_check_env "LETTA_API_KEY" && letta_secrets_validate_letta_key
  echo ""
  
  # Check OpenRouter API key
  echo "2. OpenRouter API Key:"
  letta_secrets_check_env "OPENROUTER_API_KEY" && letta_secrets_validate_openrouter_key
  echo ""
  
  # Check database URI
  echo "3. Database Connection String:"
  letta_secrets_check_env "LETTA_PG_URI" && echo "LETTA_PG_URI is set" || echo "LETTA_PG_URI is NOT set"
  echo ""
  
  # Test actual connectivity
  echo "4. Live Connectivity Tests:"
  letta_secrets_test_letta
  echo ""
  letta_secrets_test_openrouter
  echo ""
  letta_secrets_check_db_connectivity
  echo ""
  
  echo "=== Validation Complete ==="
}

# Export functions
export -f letta_secrets_list_env letta_secrets_check_env letta_secrets_validate_openrouter_key \
          letta_secrets_validate_letta_key letta_secrets_test_openrouter letta_secrets_test_letta \
          letta_secrets_check_db_connectivity letta_secrets_validate_all
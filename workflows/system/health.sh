#!/bin/bash
#
# workflow: system-health
# description: Comprehensive health check: Letta server, PostgreSQL, LLM providers, and agent status
# usage: workflows/system/health.sh [--detailed]
# returns: JSON with health status of all components
#

set -e

DETAILED=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --detailed) DETAILED=true; shift ;;
    --help) echo "Usage: $0 [--detailed]"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
LETTA="$SKILL_DIR/letta"

# Load .env for PostgreSQL URI and LLM keys
source "$SKILL_DIR/.env" 2>/dev/null || true

echo ":: Running comprehensive health check..." >&2

# --- Letta server health ---
echo ":: Checking Letta server..." >&2
LETTA_STATUS="unknown"
LETTA_CODE=0
LETTA_RESPONSE=$($LETTA health 2>/dev/null || echo "")
if [ -n "$LETTA_RESPONSE" ]; then
  LETTA_STATUS=$(echo "$LETTA_RESPONSE" | jq -r '.status // "unknown"' 2>/dev/null || echo "unknown")
  # Extract code if present (unused)
fi

# --- PostgreSQL connectivity ---
echo ":: Checking PostgreSQL..." >&2
PG_STATUS="unknown"
PG_CODE=0
if [ -n "$LETTA_POSTGRES_URI" ]; then
  if command -v psql &>/dev/null; then
    PG_CHECK=$(PGPASSWORD=$(echo "$LETTA_POSTGRES_URI" | sed 's/.*:\/\/\(.*\):\(.*\)@\(.*\):\(.*\)\/\(.*\)/\2/') \
      timeout 3 psql "$LETTA_POSTGRES_URI" -c "SELECT 1;" 2>&1) || PG_CODE=$?
    if [ $PG_CODE -eq 0 ]; then
      PG_STATUS="connected"
    else
      PG_STATUS="failed: $PG_CHECK"
    fi
  else
    PG_STATUS="psql not installed"
  fi
else
  PG_STATUS="no URI configured"
fi

# --- LLM provider health ---
echo ":: Checking LLM providers..." >&2
OR_STATUS="not_configured"
if [ -n "$OPENROUTER_API_KEY" ]; then
  OR_CHECK=$(curl -s -w "\n%{http_code}" "https://openrouter.ai/api/v1/auth/key" \
    -H "Authorization: Bearer $OPENROUTER_API_KEY" 2>/dev/null || echo "")
  OR_CODE=$(echo "$OR_CHECK" | tail -1)
  OR_STATUS=$(if [ "$OR_CODE" = "200" ]; then echo "ok"; elif [ "$OR_CODE" = "401" ]; then echo "invalid_key"; else echo "error:$OR_CODE"; fi)
fi

# --- Agent count ---
AGENT_COUNT=0
AGENT_LIST=$($LETTA agents list 2>/dev/null || echo "[]")
AGENT_COUNT=$(echo "$AGENT_LIST" | jq 'length')

# --- Overall status ---
OVERALL="healthy"
if [ "$LETTA_STATUS" != "ok" ]; then OVERALL="degraded"; fi
if [ "$PG_STATUS" != "connected" ]; then OVERALL="unhealthy"; fi

# --- Output ---
cat <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "overall_status": "$OVERALL",
  "letta_server": {
    "url": "${LETTA_BASE_URL:-http://localhost:8283}",
    "status": "$LETTA_STATUS",
    "http_code": "$LETTA_CODE"
  },
  "postgresql": {
    "status": "$PG_STATUS"
  },
  "providers": {
    "openrouter": "$OR_STATUS"
  },
  "agents": {
    "count": $AGENT_COUNT
  },
  "detailed": $(if $DETAILED; then echo "true"; else echo "false"; fi)
}
EOF

echo ":: Health check complete: $OVERALL" >&2

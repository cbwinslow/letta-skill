---
# SKILL USAGE POLICY

## Mandatory Usage Instructions
All AI agents using this skill **MUST**:

1. Always use the official Letta REST API endpoints
2. Always record complete audit context for every operation. Try and include as much data as possible, such as:
   - Agent name / ID
   - Session ID
   - Memory block ID
   - Project / repository context
   - Exact UTC timestamp
   - Semantic tags
   - Source file reference with line numbers
   - GitHub issue / PR number when applicable
   - Commit hash
   - Origin URL / web reference when available
   - Human-readable comment explaining purpose
   - Full original memory payload
   - Related / linked memory IDs
3. **NEVER** create workaround scripts, direct database edits, or file based implementations
4. **NEVER** bypass the established infra layer
5. All operations must go through the documented skill entry points
6. Any failures or errors are agent side issues - this infrastructure is validated and working
---


---
name: letta-healthcheck
description: Check Letta server health, PostgreSQL connectivity, OpenRouter availability, and overall system status. Use this skill for troubleshooting, verifying deployments, and monitoring system health.
---

# Letta Health Check

## Environment
```bash
# Auto-load Letta environment

export LETTA_BASE_URL=${LETTA_BASE_URL:-http://localhost:8283}
export LETTA_API_KEY=${LETTA_API_KEY:-${LETTA_API_KEY}}
```

## LETTA SERVER HEALTH

### Basic server health check
```bash
curl -s -L http://localhost:8283/v1/health | jq .
```

### Detailed agent count and system info
```bash
curl -s -L http://localhost:8283/v1/agents | jq 'length'
```

### API version and server info
```bash
curl -s -L http://localhost:8283/v1/ | jq .
```

## POSTGRESQL CONNECTIVITY

### Check if Letta can query PostgreSQL (indirect through agents endpoint)
```bash
# Auto-load Letta environment
curl -s -L "http://localhost:8283/v1/agents?limit=1" \
  -H "Authorization: Bearer $LETTA_API_KEY" | jq '.'
```

### Direct PostgreSQL check (requires psql installed)
```bash
# From host machine (not container)
psql postgresql://${POSTGRES_USER:-letta}:${POSTGRES_PASSWORD}@${POSTGRES_HOST:-localhost}:${POSTGRES_PORT:-5432}/${POSTGRES_DB:-letta} -c "SELECT version();"

# From within Letta container (if you can exec into it)
docker exec -it ${LETTA_CONTAINER_NAME:-letta-server} psql postgresql://${POSTGRES_USER:-letta}:${POSTGRES_PASSWORD}@${POSTGRES_DOCKER_HOST:-host.docker.internal}:${POSTGRES_PORT:-5432}/${POSTGRES_DB:-letta} -c "SELECT version();"
```

### Check pgvector extension
```bash
# From host
psql postgresql://${POSTGRES_USER:-letta}:${POSTGRES_PASSWORD}@${POSTGRES_HOST:-localhost}:${POSTGRES_PORT:-5432}/${POSTGRES_DB:-letta} -c "SELECT extname FROM pg_extension WHERE extname = 'vector';"

# From container
docker exec -it ${LETTA_CONTAINER_NAME:-letta-server} psql postgresql://${POSTGRES_USER:-letta}:${POSTGRES_PASSWORD}@${POSTGRES_DOCKER_HOST:-host.docker.internal}:${POSTGRES_PORT:-5432}/${POSTGRES_DB:-letta} -c "SELECT extname FROM pg_extension WHERE extname = 'vector';"
```

## OPENROUTER AVAILABILITY

### Test OpenRouter API key validity
```bash
# Auto-load Letta environment
curl -s -L https://openrouter.ai/api/v1/auth/key \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" | jq .
```

### List available models (requires OPENROUTER_API_KEY)
```bash
# Auto-load Letta environment
curl -s -L "https://openrouter.ai/api/v1/models" \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" | jq '.data[] | {id, name}' | head -20
```

## COMPREHENSIVE HEALTH CHECK SCRIPT

### Run all checks in sequence
```bash
# Auto-load Letta environment
#!/bin/bash
echo "=== Letta System Health Check ==="
echo ""

# 1. Check if Docker container is running
echo "1. Checking Letta container status..."
if docker ps --filter "name=${LETTA_CONTAINER_NAME:-letta-server}" --format "{{.Names}}" | grep -q "${LETTA_CONTAINER_NAME:-letta-server}"; then
  echo "✅ Letta container is running"
else
  echo "❌ Letta container is NOT running"
  echo "   Try: docker start ${LETTA_CONTAINER_NAME:-letta-server}"
fi
echo ""

# 2. Check Letta API responsiveness
echo "2. Checking Letta API..."
if curl -s -L -o /dev/null -w "%{http_code}" http://localhost:8283/v1/ | grep -q "200"; then
  echo "✅ Letta API is responding"
else
  echo "❌ Letta API is NOT responding"
  echo "   Check: docker logs ${LETTA_CONTAINER_NAME:-letta-server}"
fi
echo ""

# 3. Check PostgreSQL connectivity through Letta
echo "3. Checking PostgreSQL connectivity via Letta..."
if curl -s -L "http://localhost:8283/v1/agents?limit=1" \
     -H "Authorization: Bearer $LETTA_API_KEY" > /dev/null 2>&1; then
  echo "✅ Letta can query PostgreSQL"
else
  echo "❌ Letta cannot query PostgreSQL"
  echo "   Check: LETTA_POSTGRES_URI in container env"
fi
echo ""

# 4. Check OpenRouter API key (if set)
if [ -n "$OPENROUTER_API_KEY" ]; then
  echo "4. Checking OpenRouter API key..."
  if curl -s -L -o /dev/null -w "%{http_code}" https://openrouter.ai/api/v1/auth/key \
       -H "Authorization: Bearer $OPENROUTER_API_KEY" | grep -q "200"; then
    echo "✅ OpenRouter API key is valid"
  else
    echo "❌ OpenRouter API key is invalid or missing"
  fi
  echo ""
else
  echo "4. Skipping OpenRouter check (OPENROUTER_API_KEY not set)"
  echo ""
fi

# 5. Check vector extension
echo "5. Checking pgvector extension..."
VECTOR_CHECK=$(docker exec -it ${LETTA_CONTAINER_NAME:-letta-server} psql postgresql://${POSTGRES_USER:-letta}:${POSTGRES_PASSWORD}@${POSTGRES_DOCKER_HOST:-host.docker.internal}:${POSTGRES_PORT:-5432}/${POSTGRES_DB:-letta} -t -c "SELECT extname FROM pg_extension WHERE extname = 'vector';" 2>/dev/null | xargs)
if [ "$VECTOR_CHECK" = "vector" ]; then
  echo "✅ pgvector extension is installed"
else
  echo "❌ pgvector extension is missing"
  echo "   Run: CREATE EXTENSION IF NOT EXISTS vector;"
fi
echo ""

echo "=== Health Check Complete ==="
```

## TROUBLESHOOTING GUIDE

### Common Issues and Solutions

#### Container fails to start (exit code 130/SIGTERM)
- **Cause**: Usually PostgreSQL connection failure or missing OpenRouter config
- **Solution**: 
  ```bash
  docker logs ${LETTA_CONTAINER_NAME:-letta-server}
  # Check LETTA_POSTGRES_URI and OpenRouter settings
  ```

#### PostgreSQL connection refused
- **Cause**: Wrong hostname, port, or credentials
- **Solution**:
  ```bash
  # From host: test connection
  psql postgresql://${POSTGRES_USER:-letta}:${POSTGRES_PASSWORD}@${POSTGRES_HOST:-localhost}:${POSTGRES_PORT:-5432}/${POSTGRES_DB:-letta} -c "SELECT 1;"
  
  # From container: use host.docker.internal
  docker exec -it ${LETTA_CONTAINER_NAME:-letta-server} psql postgresql://${POSTGRES_USER:-letta}:${POSTGRES_PASSWORD}@${POSTGRES_DOCKER_HOST:-host.docker.internal}:${POSTGRES_PORT:-5432}/${POSTGRES_DB:-letta} -c "SELECT 1;"
  ```

#### Missing pgvector extension
- **Cause**: Extension not installed in database
- **Solution**:
  ```bash
  psql postgresql://${POSTGRES_USER:-letta}:${POSTGRES_PASSWORD}@${POSTGRES_HOST:-localhost}:${POSTGRES_PORT:-5432}/${POSTGRES_DB:-letta} -c "CREATE EXTENSION IF NOT EXISTS vector;"
  ```

#### OpenRouter authentication fails
- **Cause**: Invalid API key or wrong base URL
- **Solution**:
  ```bash
# Auto-load Letta environment
  # Verify key validity
curl -s -L https://openrouter.ai/api/v1/auth/key \
    -H "Authorization: Bearer $OPENROUTER_API_KEY" | jq .
  # Ensure base URL is https://openrouter.ai/api/v1 (not openrer.ai)
  ```

#### Agent creation fails
- **Cause**: Missing required memory blocks or invalid model
- **Solution**:
  ```bash
  # Always include persona and human blocks
  # Verify model format: OpenRouter/provider/model:free
  ```

## Rules
- Always check container logs first when troubleshooting: `docker logs ${LETTA_CONTAINER_NAME:-letta-server}`
- Verify PostgreSQL connectivity from both host and container perspectives
- Never hardcode secrets in scripts - use environment variables
- When testing LLM providers, validate the API key separately from Letta configuration
- For pgvector issues, remember the extension must be in the `letta` database, not just installed in PostgreSQL
- Health checks should be non-destructive and read-only where possible
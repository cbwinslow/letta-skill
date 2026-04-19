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
name: letta-secrets-manager
description: Securely manage secrets for Letta agents using environment variables and external secret stores. Use this skill when agents need to access API keys, database credentials, or other sensitive information without exposing them in memory blocks or tool code.
---

# Letta Secrets Manager

## Environment
```bash
# Auto-load Letta environment

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
ENV_FILE="${REPO_ROOT}/.env"
if [ -f "$ENV_FILE" ]; then
  set -a; . "$ENV_FILE"; set +a
fi

export LETTA_API_KEY=${LETTA_API_KEY:?LETTA_API_KEY is required}
export LETTA_BASE_URL=${LETTA_BASE_URL:-http://localhost:8283}

```

## SECRET MANAGEMENT APPROACHES

### 1. Environment Variables (Recommended for Letta Server)
Secrets are injected into the Letta container at startup and accessed by tools via process environment.

#### Example: OpenRouter API key in .env file
```env
LETTA_POSTGRES_URI=postgresql://${POSTGRES_USER:-letta}:${POSTGRES_PASSWORD}@${POSTGRES_DOCKER_HOST:-host.docker.internal}:${POSTGRES_PORT:-5432}/${POSTGRES_DB:-letta}
OPENROUTER_API_KEY=${OPENROUTER_API_KEY}
OPENAI_API_BASE=https://openrouter.ai/api/v1
```

#### Accessing secrets in Python tools
```python
# Auto-load Letta environment
import os
OPENROUTER_API_KEY = os.environ.get("OPENROUTER_API_KEY")
```

### 2. External Secret Stores (AWS Secrets Manager, HashiCorp Vault, etc.)
For production deployments, integrate with external secret management systems.

#### Example: Using AWS Secrets Manager in a tool
```python
import boto3
import json
import os

def get_secret(secret_name):
    client = boto3.client('secretsmanager')
    response = client.get_secret_value(SecretId=secret_name)
    return json.loads(response['SecretString'])

# Usage in a tool
db_credentials = get_secret("letta/database/credentials")
```

### 3. Letta Agent-Specific Secrets (Limited Use)
For agent-specific secrets that don't need to be shared, consider:
- Storing encrypted values in archival memory (with encryption handled outside Letta)
- Using identity-specific contexts for user-specific secrets
- Temporary session-only secrets passed in message context

## BEST PRACTICES

### Never Do This
```python
# ❌ NEVER hardcode secrets in tool source code
def bad_tool():
    api_key = os.environ.get("EXTERNAL_API_KEY")  # Retrieve from environment
    # ... use api_key
```

### Do This Instead
```python
# ✅ Retrieve secrets from environment at runtime
def good_tool():
    import os
    api_key = os.environ.get("EXTERNAL_API_KEY")
    if not api_key:
        raise ValueError("EXTERNAL_API_KEY not set in environment")
    # ... use api_key
```

### Secret Rotation Strategy
1. Update secret in external store or .env file
2. Restart Letta container to pick up new environment variables
3. Verify agents can still access required services
4. Old secret remains valid during transition period (if using external store with versioning)

## INTEGRATION WITH LETTA TOOLS

### Example: Tool that uses OpenRouter API key from environment
```bash
# Auto-load Letta environment
# Create tool via letta-tool-builder skill
curl -s -L -X POST http://localhost:8283/v1/tools/ \
  -H "Authorization: Bearer $LETTA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "openrouter_chat",
    "description": "Chat with a model via OpenRouter using environment variable for API key",
    "source_code": "import os\nimport requests\n\ndef openrouter_chat(prompt: str) -> str:\n    \"\"\"\n    Send a prompt to a model via OpenRouter.\n    \n    Args:\n        prompt: The user\'s message to send to the model\n    \n    Returns:\n        str: The model\'s response\n    \"\"\"\n    api_key = os.environ.get(\"OPENROUTER_API_KEY\")\n    if not api_key:\n        return \"Error: OPENROUTER_API_KEY not found in environment\"\n    \n    headers = {\n        \"Authorization\": f\"Bearer {api_key}\",\n        \"Content-Type\": \"application/json\"\n    }\n    \n    data = {\n        \"model\": \"openrouter/free\",\n        \"messages\": [{\"role\": \"user\", \"content\": prompt}]\n    }\n    \n    response = requests.post(\n        \"https://openrouter.ai/api/v1/chat/completions\",\n        headers=headers,\n        json=data\n    )\n    \n    if response.status_code != 200:\n        return f\"Error: {response.status_code} - {response.text}\"\n    \n    result = response.json()\n    return result[\"choices\"][0][\"message\"][\"content\"]",
    "source_type": "python",
    "tags": ["openrouter", "chat", "llm"]
  }'
```

## Rules
- Never store raw secrets in Letta memory blocks (core or archival)
- Always retrieve secrets from environment variables at runtime in tools
- Use external secret stores for production deployments
- Rotate secrets regularly and update container environment accordingly
- Test that tools handle missing secrets gracefully (clear error messages)
- When using identity-specific contexts, avoid storing secrets there too

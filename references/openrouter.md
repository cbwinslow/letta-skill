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
name: letta-openrouter-model-picker
description: Select and configure OpenRouter models for Letta agents. Use this skill when you need to choose appropriate free or paid models, test model availability, or configure agent model settings.
---

# Letta OpenRouter Model Picker

## Environment
```bash
# Auto-load Letta environment

export LETTA_BASE_URL=${LETTA_BASE_URL:-http://localhost:8283}
export LETTA_API_KEY=${LETTA_API_KEY:?LETTA_API_KEY is required. Copy .env.example to .env and set your key.}
export OPENROUTER_API_KEY=${OPENROUTER_API_KEY:?OPENROUTER_API_KEY is required. Copy .env.example to .env and set your key.}
```

## OPENROUTER MODEL SELECTION

### List available OpenRouter models (requires API key)
```bash
# Auto-load Letta environment
curl -s -L "https://openrouter.ai/api/v1/models" \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" | jq '.data[] | {id: .id, name: .name, context_length: .context_length, pricing: .pricing}' | head -20
```

### List free models specifically
```bash
# Auto-load Letta environment
curl -s -L "https://openrouter.ai/api/v1/models" \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" | jq '.data[] | select(.pricing.prompt == "0" and .pricing.completion == "0") | {id: .id, name: .name, context_length: .context_length}'
```

### Test if a specific model is available
```bash
# Auto-load Letta environment
curl -s -L "https://openrouter.ai/api/v1/models" \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" | jq --arg MODEL_ID "openrouter/free" '.data[] | select(.id == $MODEL_ID)'
```

## RECOMMENDED FREE MODELS

Based on common OpenRouter free model availability:

### General Purpose Free Models
- `openrouter/free` - Router that selects from available free models
- `openrouter/huggingfaceh4/zephyr-7b-beta:free` - Zephyr 7B beta
- `openrouter/nousresearch/hermes-2-pro-mistral-7b:free` - Hermes 2 Pro Mistral 7B
- `openrouter/openchat/openchat-7b:free` - OpenChat 7B
- `openrouter/google/gemma-7b-it:free` - Gemma 7B IT

### Coding-Focused Free Models (when available)
- `openrouter/codellama/codellama-7b-instruct:free` - Code Llama 7B
- `openrouter/bigcode/starcoder:free` - StarCoder
- `openrouter/huggingfaceface/codebert-base:free` - CodeBERT (check availability)

## AGENT MODEL CONFIGURATION

### Create agent with specific OpenRouter model
```bash
# Auto-load Letta environment
curl -s -L -X POST http://localhost:8283/v1/agents/ \
  -H "Authorization: Bearer $LETTA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "AGENT_NAME",
    "model": "openrouter/free",
    "description": "Agent using OpenRouter free model router",
    "memory_blocks": [
      { "label": "persona", "value": "You are a helpful AI assistant.", "limit": 2000 },
      { "label": "human", "value": "The user is interacting with you for assistance.", "limit": 2000 }
    ]
  }'
```

### Create agent with specific free model variant
```bash
# Auto-load Letta environment
curl -s -L -X POST http://localhost:8283/v1/agents/ \
  -H "Authorization: Bearer $LETTA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "CODING_AGENT",
    "model": "openrouter/codellama/codellama-7b-instruct:free",
    "description": "Coding agent using Code Llama 7B instruct",
    "memory_blocks": [
      { "label": "persona", "value": "You are a helpful coding assistant.", "limit": 2000 },
      { "label": "human", "value": "The user is asking for programming help.", "limit": 2000 },
      { "label": "project", "value": "Current project: software development tasks.", "limit": 4000 }
    ],
    "tools": ["memory_edit", "conversation_search", "run_code"]
  }'
```

## MODEL TESTING

### Test model connectivity through Letta
```bash
# First create a test agent
AGENT_ID=$(letta agents create "Model Test Agent" "Testing model connectivity" "openrouter/free" | jq -r '.id')

# Then send a test message
letta agents message "$AGENT_ID" "Hello, please respond with a brief greeting to confirm you're working."

# Clean up
letta agents delete "$AGENT_ID"
```

### Direct OpenRouter API test
```bash
# Auto-load Letta environment
curl -s -L https://openrouter.ai/api/v1/chat/completions \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "openrouter/free",
    "messages": [{"role": "user", "content": "Say hello in one word"}],
    "max_tokens": 10
  }'
```

## MODEL SWAPPING STRATEGY

### Update agent to use different model
```bash
letta agents update "$AGENT_ID" "" "" "openrouter/z-ai/glm-4.5-air:free"
```

### Recommended model selection workflow:
1. Start with `openrouter/free` for experimentation
2. If consistent behavior needed, pin to specific `:free` variant
3. For critical agents, maintain paid fallback model
4. Monitor rate limits and adjust accordingly

## Rules
- Always verify model availability before assigning to agent
- Free models may have varying availability and performance
- Use `openrouter/free` router for maximum availability
- Pin to specific `:free` models when consistent behavior is required
- Monitor OpenRouter rate limits and adjust usage accordingly
- Consider paid fallback for production-critical agents
- Normalize model names with `OpenRouter/` prefix as required by Letta
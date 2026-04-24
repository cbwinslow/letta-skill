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
name: letta-agent-manager
description: Create, list, update, retrieve, and delete Letta agents via the REST API. Use this skill for any task involving agent lifecycle management, agent creation with memory blocks and tools, sending messages to agents, searching agent message history, or managing agent conversations.
---

# Letta Agent Manager

## Environment
```bash
# Auto-load Letta environment (adjust path if needed)

export LETTA_BASE_URL=${LETTA_BASE_URL:-http://localhost:8283}
export LETTA_API_KEY=${LETTA_API_KEY:?LETTA_API_KEY is required. Copy .env.example to .env and set your key.}
export LETTA_MODEL=${LETTA_MODEL:-OpenRouter/z-ai/glm-4.5-air:free}
```

## List all agents
```bash
# Auto-load Letta environment
curl -s -L http://localhost:8283/v1/agents \
  -H "Authorization: Bearer $LETTA_API_KEY" | jq '.[].id + " " + .[].name'
```

## Create agent with memory blocks
```bash
# Auto-load Letta environment
curl -s -L -X POST http://localhost:8283/v1/agents/ \
  -H "Authorization: Bearer $LETTA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "AGENT_NAME",
    "model": "'"$LETTA_MODEL"'",
    "description": "DESCRIPTION",
    "memory_blocks": [
      { "label": "persona", "value": "PERSONA_TEXT", "limit": 2000 },
      { "label": "human",   "value": "HUMAN_CONTEXT", "limit": 2000 },
      { "label": "project", "value": "PROJECT_NOTES", "limit": 4000 }
    ],
    "tools": ["memory_edit", "conversation_search"]
  }'
```

## Retrieve a single agent
```bash
# Auto-load Letta environment
curl -s -L http://localhost:8283/v1/agents/AGENT_ID \
  -H "Authorization: Bearer $LETTA_API_KEY" | jq .
```

## Update agent name or description
```bash
# Auto-load Letta environment
curl -s -L -X PATCH http://localhost:8283/v1/agents/AGENT_ID \
  -H "Authorization: Bearer $LETTA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"name": "NEW_NAME", "description": "NEW_DESC"}'
```

## Send a message to an agent
```bash
# Auto-load Letta environment
curl -s -L -X POST http://localhost:8283/v1/agents/AGENT_ID/messages \
  -H "Authorization: Bearer $LETTA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [{ "role": "user", "content": "YOUR MESSAGE HERE" }]
  }' | jq '.messages[].content // .messages[].text // .'
```

## List messages for an agent
```bash
# Auto-load Letta environment
curl -s -L "http://localhost:8283/v1/agents/AGENT_ID/messages?limit=20" \
  -H "Authorization: Bearer $LETTA_API_KEY" | jq .
```

## Search agent message history
```bash
# Auto-load Letta environment
curl -s -L "http://localhost:8283/v1/agents/AGENT_ID/messages/search?query=SEARCH_TERM" \
  -H "Authorization: Bearer $LETTA_API_KEY" | jq .
```

## Delete an agent
```bash
# Auto-load Letta environment
curl -s -L -X DELETE http://localhost:8283/v1/agents/AGENT_ID \
  -H "Authorization: Bearer $LETTA_API_KEY" | jq .
```

## Rules
- Always capture agent ID from create response before proceeding
- Never delete an agent without confirming with the user first
- When listing agents for selection, print id + name clearly
- Default model is OpenRouter/z-ai/glm-4.5-air:free unless user specifies otherwise
- Include at least persona and human blocks on every new agent
- ALWAYS use description field on memory blocks (see best-practices.md)

---

## RECOMMENDED: Create Agent with Separate Blocks

**Best Practice:** Create blocks first, then create agent, then attach (per best-practices.md)

```bash
# 1. Create persona block first
PERSONA_ID=$(curl -s -X POST http://localhost:8283/v1/blocks/ \
  -H "Authorization: Bearer $LETTA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "label": "persona",
    "value": "You are a helpful AI assistant specialized in data analysis.",
    "description": "Agent persona: role, communication style, and behavioral guidelines.",
    "limit": 2000
  }' | jq -r '.id')

# 2. Create human block
HUMAN_ID=$(curl -s -X POST http://localhost:8283/v1/blocks/ \
  -H "Authorization: Bearer $LETTA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "label": "human",
    "value": "User: data analyst. Machine: cbwdellr720.",
    "description": "User information: name, machine, preferences, and context.",
    "limit": 2000
  }' | jq -r '.id')

# 3. Create the agent (without inline blocks)
AGENT_ID=$(curl -s -X POST http://localhost:8283/v1/agents/ \
  -H "Authorization: Bearer $LETTA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "data-agent",
    "model": "OpenRouter/z-ai/glm-4.5-air:free",
    "description": "AI assistant for data analysis tasks"
  }' | jq -r '.id')

# 4. Attach persona block
curl -s -X PATCH "http://localhost:8283/v1/agents/$AGENT_ID/core-memory/blocks/attach/$PERSONA_ID" \
  -H "Authorization: Bearer $LETTA_API_KEY"

# 5. Attach human block
curl -s -X PATCH "http://localhost:8283/v1/agents/$AGENT_ID/core-memory/blocks/attach/$HUMAN_ID" \
  -H "Authorization: Bearer $LETTA_API_KEY"

echo "Created agent $AGENT_ID with persona and human blocks"
```

**Why separate blocks?**
- Blocks can be reused across agents (shared memory)
- Better audit trail
- Easier updates
- Enables shared memory patterns

**See also:** `references/best-practices.md` for full details
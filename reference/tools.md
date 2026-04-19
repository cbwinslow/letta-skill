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
name: letta-tool-builder
description: Create, list, attach, detach, update, and delete custom tools on the Letta server. Use this skill when building new agent capabilities, registering Python functions as tools, attaching tools to agents, or inspecting what tools an agent currently has access to.
---

# Letta Tool Builder

## Environment
```bash
# Auto-load Letta environment

export LETTA_BASE_URL=${LETTA_BASE_URL:-http://localhost:8283}
export LETTA_API_KEY=${LETTA_API_KEY:?LETTA_API_KEY is required. Copy .env.example to .env and set your key.}
```

## List all available tools
```bash
# Auto-load Letta environment
curl -s -L http://localhost:8283/v1/tools/ \
  -H "Authorization: Bearer $LETTA_API_KEY" | jq '.[] | {id, name, description}'
```

## List tools attached to a specific agent
```bash
# Auto-load Letta environment
curl -s -L http://localhost:8283/v1/agents/AGENT_ID/tools \
  -H "Authorization: Bearer $LETTA_API_KEY" | jq '.[] | {id, name}'
```

## Create a custom tool from a Python function string
```bash
# Auto-load Letta environment
curl -s -L -X POST http://localhost:8283/v1/tools/ \
  -H "Authorization: Bearer $LETTA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "TOOL_NAME",
    "description": "What this tool does",
    "source_code": "def TOOL_NAME(param: str) -> str:\n    \"\"\"\n    Tool description here.\n    Args:\n        param: Description of param\n    Returns:\n        str: description of return\n    \"\"\"\n    return f\"Result: {param}\"",
    "source_type": "python",
    "tags": ["custom", "utility"]
  }' | jq '{id, name}'
```

## Retrieve a specific tool
```bash
# Auto-load Letta environment
curl -s -L http://localhost:8283/v1/tools/TOOL_ID \
  -H "Authorization: Bearer $LETTA_API_KEY" | jq .
```

## Search tools by name or tag
```bash
# Auto-load Letta environment
curl -s -L "http://localhost:8283/v1/tools/search?query=SEARCH_TERM" \
  -H "Authorization: Bearer $LETTA_API_KEY" | jq '.[] | {id, name}'
```

## Attach a tool to an agent (returns null)
```bash
# Auto-load Letta environment
curl -s -L -X PATCH http://localhost:8283/v1/agents/AGENT_ID/tools/attach/TOOL_ID \
  -H "Authorization: Bearer $LETTA_API_KEY"
# Returns null on success — expected
```

## Detach a tool from an agent (returns null)
```bash
# Auto-load Letta environment
curl -s -L -X PATCH http://localhost:8283/v1/agents/AGENT_ID/tools/detach/TOOL_ID \
  -H "Authorization: Bearer $LETTA_API_KEY"
```

## Update a tool
```bash
# Auto-load Letta environment
curl -s -L -X PATCH http://localhost:8283/v1/tools/TOOL_ID \
  -H "Authorization: Bearer $LETTA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "description": "Updated description",
    "source_code": "def TOOL_NAME(param: str) -> str:\n    ..."
  }'
```

## Upsert a tool (create or update by name)
```bash
# Auto-load Letta environment
curl -s -L -X PUT http://localhost:8283/v1/tools/ \
  -H "Authorization: Bearer $LETTA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "TOOL_NAME",
    "source_code": "def TOOL_NAME(param: str) -> str:\n    ...",
    "source_type": "python"
  }'
```

## Delete a tool
```bash
# Auto-load Letta environment
curl -s -L -X DELETE http://localhost:8283/v1/tools/TOOL_ID \
  -H "Authorization: Bearer $LETTA_API_KEY"
```

## Built-in tools available by default
| Tool name             | Purpose                                      |
|-----------------------|----------------------------------------------|
| memory_edit           | Agent edits its own core memory blocks       |
| conversation_search   | Agent searches its own message history       |
| archival_memory_insert| Agent inserts to its own archival memory     |
| archival_memory_search| Agent searches its own archival memory       |
| web_search            | Agent performs a web search                  |
| run_code              | Agent executes Python code server-side       |

## Rules
- Tool source_code must be a valid Python function string with a proper docstring
- Docstring is parsed to generate the OpenAI tool schema — make it descriptive
- Always tag tools for easy filtering later
- Attach/detach returns null — that is correct behavior, not an error
- Use upsert (PUT) when you want idempotent tool registration in scripts

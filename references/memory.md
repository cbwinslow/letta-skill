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
name: letta-memory-manager
description: Create, read, update, attach, detach, and manage Letta memory blocks (core memory). Use this skill for any task involving agent memory blocks, shared blocks across agents, reading or updating block values, archival memory (long-term storage), or searching an agent's archival memory passages.
---

# Letta Memory Manager

## Environment
```bash
# Auto-load Letta environment

export LETTA_BASE_URL=${LETTA_BASE_URL:-http://localhost:8283}
export LETTA_API_KEY=${LETTA_API_KEY:?LETTA_API_KEY is required. Copy .env.example to .env and set your key.}
```

## CORE MEMORY (blocks)

### List blocks for an agent
```bash
# Auto-load Letta environment
curl -s -L http://localhost:8283/v1/agents/AGENT_ID/core-memory/blocks \
  -H "Authorization: Bearer $LETTA_API_KEY" | jq '.[] | {label, value, limit, id}'
```

### Read a specific block by label
```bash
# Auto-load Letta environment
curl -s -L http://localhost:8283/v1/agents/AGENT_ID/core-memory/blocks/BLOCK_LABEL \
  -H "Authorization: Bearer $LETTA_API_KEY" | jq .
```

### Update a block value directly
```bash
# Auto-load Letta environment
curl -s -L -X PATCH http://localhost:8283/v1/agents/AGENT_ID/core-memory/blocks/BLOCK_LABEL \
  -H "Authorization: Bearer $LETTA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"value": "NEW CONTENT FOR BLOCK"}'
```

### Create a standalone block (global, reusable)
```bash
# Auto-load Letta environment
curl -s -L -X POST http://localhost:8283/v1/blocks/ \
  -H "Authorization: Bearer $LETTA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "label": "BLOCK_LABEL",
    "value": "INITIAL CONTENT",
    "limit": 4000
  }' | jq '{id, label, value}'
```

### List all standalone blocks
```bash
# Auto-load Letta environment
curl -s -L http://localhost:8283/v1/blocks/ \
  -H "Authorization: Bearer $LETTA_API_KEY" | jq '.[] | {id, label}'
```

### Attach a block to an agent (PATCH, returns null)
```bash
# Auto-load Letta environment
curl -s -L -X PATCH \
  http://localhost:8283/v1/agents/AGENT_ID/core-memory/blocks/attach/BLOCK_ID \
  -H "Authorization: Bearer $LETTA_API_KEY"
# Returns null on success — that is expected behavior
```

### Detach a block from an agent (PATCH, returns null)
```bash
# Auto-load Letta environment
curl -s -L -X PATCH \
  http://localhost:8283/v1/agents/AGENT_ID/core-memory/blocks/detach/BLOCK_ID \
  -H "Authorization: Bearer $LETTA_API_KEY"
```

### Delete a standalone block
```bash
# Auto-load Letta environment
curl -s -L -X DELETE http://localhost:8283/v1/blocks/BLOCK_ID \
  -H "Authorization: Bearer $LETTA_API_KEY"
```

## ARCHIVAL MEMORY (long-term searchable storage)

### Insert a passage into archival memory
```bash
# Auto-load Letta environment
curl -s -L -X POST http://localhost:8283/v1/agents/AGENT_ID/archival-memory \
  -H "Authorization: Bearer $LETTA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"text": "TEXT TO STORE IN LONG TERM MEMORY"}'
```

### Search archival memory
```bash
# Auto-load Letta environment
curl -s -L "http://localhost:8283/v1/agents/AGENT_ID/archival-memory/search?query=SEARCH_TERM&limit=10" \
  -H "Authorization: Bearer $LETTA_API_KEY" | jq '.passages[] | {text, score}'
```

### Delete a passage from archival memory
```bash
# Auto-load Letta environment
curl -s -L -X DELETE \
  http://localhost:8283/v1/agents/AGENT_ID/archival-memory/PASSAGE_ID \
  -H "Authorization: Bearer $LETTA_API_KEY"
```

## Block design recommendations

| Label       | Purpose                                      | Limit  | Shared? |
|-------------|----------------------------------------------|--------|---------|
| persona     | Agent role, tone, operating rules            | 2000   | No      |
| human       | Who the user is, preferences, context        | 2000   | No      |
| project     | Current project facts, hosts, services       | 4000   | Yes     |
| runbook     | Deployment facts, commands, and troubleshooting conventions | 4000   | Yes     |
| scratchpad  | Working notes the agent may revise frequently | 8000   | No      |
| policies    | Read-only compliance, guardrails, or organization rules | 2000   | Yes     |

---

## CRITICAL: The Description Field

> "The `description` field is crucial - it's how the agent determines how to read and write to the block. Without a good description, the agent may not understand how to use the block." — Letta Docs

**Every memory block MUST include a description:**

```bash
curl -s -X POST http://localhost:8283/v1/blocks/ \
  -H "Authorization: Bearer $LETTA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "label": "data_sources",
    "value": "Retrosheet: 62K games...",
    "description": "Retrosheet data sources and their current status. Updated as new data is ingested.",
    "limit": 4000
  }' | jq '{id, label, description}'
```

**Good description examples:**
- "User preferences for tone, formatting, and communication style"
- "Current project context and working goals"
- "Data sources and how to access them"
- "Skills and tools available to use"

---

## Tagging Archival Passages

**Always tag archival passages with:**

- **project**: identifier (project:retrosheet, project:letta)
- **type**: category (type:overview, type:fixes, type:docs)
- **agent**: owner (agent:blaine-assistant)
- **folder**: reference (folder:homelab)
- **date**: when relevant (date:2026-04-24)

```bash
curl -s -X POST http://localhost:8283/v1/agents/AGENT_ID/archival-memory \
  -H "Authorization: Bearer $LETTA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Letta organization completed. Fixed all blocks...",
    "tags": ["project:letta", "type:organization", "agent:opencode", "folder:homelab", "date:2026-04-24"]
  }'
```

---

## Memory Block Size Management

When approaching character limits:

1. **Split by topic:** `customer_profile` → `customer_business`, `customer_preferences`
2. **Split by time:** `interaction_history` → `recent_interactions`, archive older
3. **Archive historical data:** Move old information to archival memory
4. **Consolidate with memory_rethink:** Summarize and rewrite block

---

## Rules
- Attach/detach calls return null — do not treat null as an error
- Core memory blocks are always in context — keep them concise and factual
- Use archival memory for anything that should be searchable but not always in context
- Shared blocks should contain only information safe for all attached agents to see
- Never store raw secrets or passwords in memory blocks

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
name: letta-best-practices
description: Comprehensive Letta best practices based on official documentation and web research. Use this skill when creating agents, managing memory blocks, or organizing archival memory. Covers memory types, block design, tagging, size management, and advanced patterns.
---

# Letta Best Practices Guide

**Source**: Derived from Letta official docs + web research (2026-04-24)
**Related**: PROCEDURES.md at ~/infra/letta/PROCEDURES.md

---

## 1. When to Use Each Memory Type

| Data Type | Recommended Abstraction | Why |
|----------|------------------------|-----|
| Important memories agent always needs (e.g., "user's name is Sarah") | Memory Blocks | Always visible in context |
| Company guidelines 1-2 pages | Memory Blocks | Frequent reference |
| Company documentation 100s of pages | Files (Folders) | Too large for blocks |
| Less important memories not always needed | Archival Memory | Searchable but not in context |
| Millions of documents | External RAG | Scale beyond Letta |

---

## 1.5 Memory Architecture: Three Distinct Systems

Letta has **three separate memory systems** with different purposes and access patterns:

### Core Memory (Blocks)
- **What**: Permanent memory blocks always included in the agent's context window
- **Access**: Automatically in every prompt — no search needed
- **Edit tools**: `memory_replace`, `memory_insert`, `core_memory_append`
- **Use for**: User identity, agent persona, project goals, current task state
- **Size**: Limited per block (2000–8000 chars typical)

### Archival Memory (Passages)
- **What**: Long-term semantic searchable storage; individual items are "passages"
- **Access**: NOT automatic — must be explicitly recalled via `archival_memory_search` tool or API
- **Write**: `archival_memory_insert` tool or `POST /v1/agents/{id}/archival-memory` with `{"text": "..."}`
- **Read**: `archival_memory_search` tool or `GET /v1/agents/{id}/archival-memory/search?query=...`
- **Response format**: `{results: [{id, timestamp, content, tags}], count: N}`
- **Use for**: Meeting notes, decisions, project milestones, summaries — facts you want to remember across all future conversations
- **Size**: Unlimited, indexed for semantic retrieval

### Conversation History
- **What**: Past message transcripts (user/assistant/tool roles)
- **Access**: Search via `conversation_search` tool — hybrid text + semantic search of message content
- **Use for**: Recalling earlier dialogue turns, finding specific past statements
- **Note**: Distinct from archival memory — covers only message stream, not stored facts

#### Quick Comparison

| Feature | Core Memory | Archival Memory | Conversation History |
|---------|-------------|----------------|---------------------|
| Always in context? | ✅ Yes | ❌ No | ❌ No |
| Search mechanism | Direct read (always available) | Semantic search via `archival_memory_search` | Hybrid text+semantic via `conversation_search` |
| Write via | `memory_replace/insert/append` tools | `archival_memory_insert` tool or POST API | Implicit (every message) |
| Size limit | Per-block (2000–8000 chars) | Unlimited | Unlimited |
| Primary use | Essential facts (user, persona, project) | Important events/decisions/summaries | Past dialogue turns |
| Query pattern | Read directly by label | Query by meaning/semantics | Query by text + semantics |

---

## 2. Memory Block Best Practices

### 2.1 The Description Field is CRITICAL

> "The `description` field is crucial - it's how the agent determines how to read and write to the block. Without a good description, the agent may not understand how to use the block." — Letta Docs

**Good description examples:**
- "User preferences for tone, formatting, and communication style"
- "Current project context and working goals"
- "Data sources and how to access them"
- "Skills and tools available to use"

### 2.2 Block Structure by Agent Type

| Agent Type | Recommended Blocks |
|-----------|------------------|
| Data agent | persona, human, project, data_sources, skills |
| Homelab | persona, human, homelab, knowledge, runbook |
| Research | persona, human, project, notes, sources |
| Support | persona, human, policies, knowledge, scratchpad |

### 2.3 Block Design Guidelines

- **One block per distinct functional unit** — Keep blocks focused
- **Use clear, instructional descriptions** — Tell agent how to use the block
- **Keep under 50k characters** per block (recommended <20 blocks per agent)
- **Monitor size limits** — Typically 2000-5000 characters per block
- **Design for append operations** when sharing between agents
- **Keep total core memory under 80%** of context window

---

## 3. Tagging Passages (Archival Memory)

### Always include these tags on archival passages:

- **project**: identifier (project:retrosheet, project:letta)
- **type**: category (type:overview, type:fixes, type:docs)
- **agent**: owner (agent:blaine-assistant)
- **folder**: reference (folder:homelab)
- **date**: when relevant (date:2026-04-24)

### Example:
```bash
curl -X POST "http://localhost:8283/v1/agents/$AGENT_ID/archival-memory" \
  -H "Authorization: Bearer $LETTA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Letta organization completed. Fixed all blocks...",
    "tags": ["project:letta", "type:organization", "agent:opencode", "folder:homelab", "date:2026-04-24"]
  }'
```

---

## 4. Memory Block Size Management

When approaching character limits:

1. **Split by topic:** `customer_profile` → `customer_business`, `customer_preferences`
2. **Split by time:** `interaction_history` → `recent_interactions`, archive older
3. **Archive historical data:** Move old information to archival memory
4. **Consolidate with memory_rethink:** Summarize and rewrite block

---

## 5. Shared Memory Patterns

- **Attach same block to multiple agents** — Enables shared knowledge
- **Create read-only blocks** — For organizational policies shared across all agents
- **Dynamically control access** — Attach sensitive blocks only when needed, detach when done
- **Switch contexts** — Detach blocks for one task, attach blocks for another

---

## 6. Sleep-Time Compute

- Let agents "think" during idle time to reorganize memory
- Instead of lazy incremental updates, reorganize during downtime
- Improves response times and memory quality
- Use `memory_rethink` tool for consolidating memory

---

## 7. Eviction Strategies

When context window reaches capacity:

- **Intelligent eviction** — Only remove 70% of messages to ensure continuity
- **Summarize first** — Compress conversation history into summaries before removing
- **Preserve originals** — Keep original conversations for subsequent retrieval

---

## 8. Letta Code Specific Commands

- **`/doctor`** — Audit current memory layout, refine for proper placement and token usage
- **`/remember`** — Actively direct agent to remember specific information
- **`/memory`** — View agent's current memory state
- **MemFS** — Git-backed memory filesystem (`~/.letta/agents/<id>/memory`)
- **system/ folder** — Pinned to context window (important info like name, personality)

---

## 9. Advanced Patterns

- **performance tracking block** — Track metrics, watch agents optimize behavior
- **emotional state block** — Enable emergent behavior based on interaction patterns
- **scratchpad block** — Maintain working memory for current task
- **mirror external state** — Real-time awareness of user's current document/file

---

## 10. Concurrency Best Practices

- **Prefer append-only** — Use `memory_insert` for concurrent writes
- **Reserve memory_rethink** — Use for single-agent exclusive access only
- **Database uses row-level locking** — Last write wins on concurrent modifications

---

## 11. Creating Blocks (Correct Pattern)

### Wrong (inline with agent):
```bash
curl -X POST .../v1/agents/ \
  -d '{"memory_blocks": [{"label": "persona", "value": "..."}]}'
```

### Correct (create separately, then attach):
```bash
# 1. Create block
BLOCK_ID=$(curl -s -X POST http://localhost:8283/v1/blocks/ \
  -H "Authorization: Bearer $LETTA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "label": "persona",
    "value": "You are a helpful AI assistant.",
    "description": "Agent persona: role, communication style, and behavioral guidelines.",
    "limit": 2000
  }' | jq -r '.id')

# 2. Create agent
AGENT_ID=$(curl -s -X POST http://localhost:8283/v1/agents/ \
  -H "Authorization: Bearer $LETTA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"name": "my-agent", "model": "..."}' | jq -r '.id')

# 3. Attach block
curl -s -X PATCH "http://localhost:8283/v1/agents/$AGENT_ID/core-memory/blocks/attach/$BLOCK_ID" \
  -H "Authorization: Bearer $LETTA_API_KEY"
```

---

## 12. Quick Reference

| Task | Recommended Approach |
|-----|---------------------|
| Create agent | Create blocks first, then create agent, then attach |
| Add important info | Use memory blocks with descriptions |
| Add searchable info | Use archival with tags |
| Large documents | Use folders |
| Shared across agents | Create block once, attach to multiple |
| Working notes | Use scratchpad block |
| Keep under limit | Monitor block sizes, archive old data |

---

## 13. Active Recall Pattern (How Agents Use Memory During Conversation)

When a user asks a question, the agent should follow this decision tree to determine which memory system to query:

```text
User Query Arrives
    |
    v
Is the answer in CURRENT CONTEXT? → Yes → Answer directly
    |
    No
    |
    v
Is this about:                           No
├─ Past message history? ────────────────┐
│  (e.g., "What did you say earlier?")   │
│      → Use conversation_search           │
│                                         │
├─ Stored fact/decision/event? ──────────┤
│  (e.g., "What's my email?"             │
│        "When did we decide X?")        │
│      → Use archival_memory_search       │
│                                         │
└─ Need to modify memory?                │
   (e.g., "Update my address to...") ────┘
      → Use memory_replace/insert/rethink
```

### Step-by-step recall decision

**Step 1: Check core memory first**
Core memory blocks are always in context — just read them directly. No tool call needed.

**Step 2: For past dialogue, use `conversation_search`**
Tool: `conversation_search(query="...", roles=["assistant"], limit=5)`
Use when:
- User asks "What did you tell me earlier?"
- Need to find a specific statement from earlier in conversation
- Checking consistency with previous answers

**Step 3: For stored facts, use `archival_memory_search`**
Tool: `archival_memory_search(query="...", limit=5)`
Use when:
- User asks about remembered information (preferences, decisions, facts)
- Fact could have been stored in a past conversation
- Semantic similarity search needed (concepts not exact keywords)

**Step 4: For current state/working notes, use core memory blocks**
- `memory_insert` — append notes to scratchpad
- `memory_replace` — update user pref
- `memory_rethink` — consolidate/summarize

### Example conversation flow

```
User: "What's my favorite programming language?"

Agent (internal thinking):
  Core memory → check 'human' block    ← found: "User enjoys Rust"
  → Answer directly

---

User: "What did I ask you to build last week?"

Agent (internal thinking):
  conversation_search(query="project to build", roles=["user"], limit=3)
  → Find message: "Build a homelab network monitoring tool"
  → Answer with that context

---

User: "Where did we park the server in the data center?"

Agent (internal thinking):
  archival_memory_search(query="server rack location", limit=3)
  → Find passage: "Rack 12, position 3U, labeled 'letta-prod'"
  → Answer with that fact
```

### Tool attachment requirement

**CRITICAL:** Agents must have the relevant tools attached to use them. When creating an agent, include at minimum:

```bash
# Create agent with search tools
curl -s -X POST http://localhost:8283/v1/agents/ \
  -H "Authorization: Bearer $LETTA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "my-agent",
    "model": "OpenRouter/z-ai/glm-4.5-air:free",
    "description": "Agent with full memory capabilities",
    "tools": ["archival_memory_search", "conversation_search", "memory_edit"]
  }'
```

To add tools to an existing agent:
```bash
curl -s -X POST http://localhost:8283/v1/agents/AGENT_ID/tools \
  -H "Authorization: Bearer $LETTA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"tools": ["archival_memory_search", "conversation_search"]}'
```

Without proper tool attachment, agents cannot autonomously recall information. See `reference/tools.md` for full tool management guide.

---

## Related Documentation

- `references/memory.md` — Memory block and archival operations
- `references/agents.md` — Agent creation and management
- `templates/block-templates.yaml` — Pre-built block templates
- `templates/agent-templates.yaml` — Pre-built agent configs

---

## Custom Tool Creation

### Creating a Tool

```bash
curl -s -X POST http://localhost:8283/v1/tools/ \
  -H "Authorization: Bearer $LETTA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "description": "Run a read-only SQL query on the retrosheet database.",
    "source_code": "def pg_query(query: str) -> str:\n    \"\"\"\n    Run a read-only SQL query.\n    \n    Args:\n        query: SQL query string\n    \n    Returns:\n        str: Query results\n    \"\"\"\n    return query",
    "source_type": "python"
  }' | jq -r '.id, .name'
```

**Requirements:**
- Must have Google-style docstring
- `source_type`: "python" or "javascript"
- Add `pip_requirements` for packages (e.g., `["psycopg2-binary"]`)

### Tools in Database

| Tool Name | Purpose | Agent |
|-----------|---------|-------|
| pg_query | Run SELECT queries on retrosheet DB | retrosheet-warehouse |

### Adding Tools to Agents

Use the Letta Python SDK to attach custom tools:
```python
from letta_client import Letta
client = Letta()
agent = client.agents.get(AGENT_ID)
agent.attach_tool("pg_query")
```
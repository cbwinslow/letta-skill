# Letta Agents Guide

Comprehensive guide to deploying, managing, and using Letta agents with the letta-skill infrastructure management system.

## Table of Contents

- [Introduction](#introduction)
- [Quick Start](#quick-start)
- [Agent Concepts](#agent-concepts)
- [Agent Lifecycle](#agent-lifecycle)
- [Memory Management](#memory-management)
- [Tool Management](#tool-management)
- [Advanced Configuration](#advanced-configuration)
- [Deployment Patterns](#deployment-patterns)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)
- [Getting Help](#getting-help)
- [API Reference](#api-reference)

---

## Introduction

### What is a Letta Agent?

A Letta agent is an AI-powered entity that can:
- Maintain context across conversations
- Access and manipulate memory blocks
- Use tools to perform actions
- Interact with external systems
- Learn and adapt over time

### Why Use Letta Agents?

- **Persistent Memory**: Agents maintain state across sessions
- **Tool Integration**: Agents can call custom tools for complex tasks
- **Multi-Provider Support**: Works with OpenRouter, OpenAI, Anthropic, Ollama, and more
- **Scalable Architecture**: Self-hosted or cloud deployment options
- **Flexible Memory**: Core memory for immediate context, archival memory for long-term storage

### When to Use Agents

Consider using Letta agents when you need:
- Conversational AI with context retention
- Task automation with tool integration
- Knowledge base integration
- Multi-turn conversations
- Persistent user sessions
- Custom AI workflows

---

## Quick Start

### Prerequisites

- Letta server running (self-hosted or cloud)
- API key for Letta server
- LLM provider API key (OpenRouter, OpenAI, etc.)
- Bash shell with curl and jq

### Setup

```bash
# Clone the repository
git clone https://github.com/your-username/letta-skill.git
cd letta-skill

# Configure environment
cp .env.example .env
nano .env

# Set required variables
LETTA_BASE_URL=http://localhost:8283
LETTA_API_KEY=${LETTA_API_KEY}
LETTA_MODEL=OpenRouter/z-ai/glm-4.5-air:free
```

### Create Your First Agent

```bash
# Source helper scripts
source scripts/letta_client.sh
source scripts/letta_agents.sh

# Create a simple agent
AGENT_ID=$(letta_agents_create \
  "my-first-agent" \
  "A helpful assistant for answering questions" \
  "$LETTA_MODEL")

echo "Created agent with ID: $AGENT_ID"
```

### Send a Message

```bash
# Send a message to your agent
letta_agents_message "$AGENT_ID" "Hello! Can you help me?"
```

### List Messages

```bash
# View conversation history
letta_agents_list_messages "$AGENT_ID"
```

---

## Agent Concepts

### Agent Anatomy

A Letta agent consists of:

1. **Identity**
   - Name: Human-readable identifier
   - Description: Purpose and capabilities
   - Model: LLM to use for reasoning

2. **Memory Blocks**
   - Core Memory: Immediate context (persona, human, project)
   - Archival Memory: Long-term searchable storage

3. **Tools**
   - Built-in tools (memory_edit, conversation_search)
   - Custom tools (Python functions)
   - Tool permissions and constraints

4. **Configuration**
   - Temperature: Response randomness (0.0 - 1.0)
   - Max Tokens: Response length limit
   - Context Window: Total context size

### Memory Architecture

#### Core Memory

Core memory consists of labeled blocks with size limits:

- **persona**: Agent's personality and role (default: 2000 tokens)
- **human**: User context and preferences (default: 2000 tokens)
- **project**: Task-specific information (default: 4000 tokens)
- **custom**: Additional context blocks as needed

Core memory is always included in the agent's context window.

#### Archival Memory

Archival memory is a searchable long-term storage:
- Stores past conversations and important information
- Indexed for semantic search
- Retrieved based on relevance to current context
- Unlimited storage (limited only by database)

### Tool System

Tools are functions agents can call:
- **Built-in**: Provided by Letta (memory_edit, conversation_search)
- **Custom**: User-defined Python functions
- **Tool Calling**: Agent decides when to use tools
- **Tool Results**: Tool outputs are fed back to agent

---

## Agent Lifecycle

### 1. Create Agent

```bash
curl -s -X POST http://localhost:8283/v1/agents/ \
  -H "Authorization: Bearer $LETTA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "research-assistant",
    "model": "OpenRouter/z-ai/glm-4.5-air:free",
    "description": "AI assistant for research tasks",
    "memory_blocks": [
      {
        "label": "persona",
        "value": "You are a helpful research assistant with expertise in data analysis and academic writing.",
        "limit": 2000
      },
      {
        "label": "human",
        "value": "The user is a researcher working on machine learning projects.",
        "limit": 2000
      },
      {
        "label": "project",
        "value": "Current project: analyzing transformer architectures for NLP tasks.",
        "limit": 4000
      }
    ],
    "tools": ["memory_edit", "conversation_search"]
  }' | jq .
```

### 2. List Agents

```bash
# List all agents
curl -s http://localhost:8283/v1/agents \
  -H "Authorization: Bearer $LETTA_API_KEY" | jq .

# List with helper script
letta_agents_list | jq .
```

### 3. Retrieve Agent

```bash
# Get agent details
curl -s http://localhost:8283/v1/agents/AGENT_ID \
  -H "Authorization: Bearer $LETTA_API_KEY" | jq .

# With helper script
letta_agents_get "AGENT_ID" | jq .
```

### 4. Update Agent

```bash
# Update agent metadata
curl -s -X PATCH http://localhost:8283/v1/agents/AGENT_ID \
  -H "Authorization: Bearer $LETTA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "senior-research-assistant",
    "description": "Senior AI research assistant with deep expertise"
  }' | jq .
```

### 5. Send Message

```bash
# Send a message
curl -s -X POST http://localhost:8283/v1/agents/AGENT_ID/messages \
  -H "Authorization: Bearer $LETTA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [
      {
        "role": "user",
        "content": "What are the key components of a transformer model?"
      }
    ]
  }' | jq .
```

### 6. List Messages

```bash
# Get message history
curl -s "http://localhost:8283/v1/agents/AGENT_ID/messages?limit=20" \
  -H "Authorization: Bearer $LETTA_API_KEY" | jq .

# Search messages
curl -s "http://localhost:8283/v1/agents/AGENT_ID/messages/search?query=transformer" \
  -H "Authorization: Bearer $LETTA_API_KEY" | jq .
```

### 7. Delete Agent

```bash
# Delete an agent
curl -s -X DELETE http://localhost:8283/v1/agents/AGENT_ID \
  -H "Authorization: Bearer $LETTA_API_KEY" | jq .

# With helper script
letta_agents_delete "AGENT_ID"
```

---

## Memory Management

### Create Memory Block

```bash
# Create a new memory block
curl -s -X POST http://localhost:8283/v1/blocks/ \
  -H "Authorization: Bearer $LETTA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "label": "research_notes",
    "value": "Key findings: Attention mechanisms enable parallel processing, positional encodings capture sequence order.",
    "limit": 4000
  }' | jq .
```

### Attach Memory Block to Agent

```bash
# Attach block to agent
curl -s -X POST http://localhost:8283/v1/agents/AGENT_ID/memory \
  -H "Authorization: Bearer $LETTA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "blocks": ["BLOCK_ID"]
  }' | jq .
```

### Update Memory Block

```bash
# Update block value
curl -s -X PATCH http://localhost:8283/v1/blocks/BLOCK_ID \
  -H "Authorization: Bearer $LETTA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "value": "Updated research notes with new findings about layer normalization."
  }' | jq .
```

### Detach Memory Block

```bash
# Detach block from agent
curl -s -X DELETE http://localhost:8283/v1/agents/AGENT_ID/memory/BLOCK_ID \
  -H "Authorization: Bearer $LETTA_API_KEY" | jq .
```

### Search Archival Memory

```bash
# Search archival memory
curl -s -X POST http://localhost:8283/v1/agents/AGENT_ID/archival/memory/search \
  -H "Authorization: Bearer $LETTA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "transformer attention mechanism",
    "limit": 10
  }' | jq .
```

### Insert into Archival Memory

```bash
# Add to archival memory
curl -s -X POST http://localhost:8283/v1/agents/AGENT_ID/archival-memory \
  -H "Authorization: Bearer $LETTA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Self-attention allows each position to attend to all positions in the sequence.",
    "tags": ["source:research_paper", "date:2024-04-19"]
  }' | jq .
```

---

## Tool Management

### List Available Tools

```bash
# List all tools
curl -s http://localhost:8283/v1/tools \
  -H "Authorization: Bearer $LETTA_API_KEY" | jq .
```

### Create Custom Tool

```bash
# Create a custom Python tool
curl -s -X POST http://localhost:8283/v1/tools/ \
  -H "Authorization: Bearer $LETTA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "web_search",
    "description": "Search the web for information",
    "source_code": "import requests\n\ndef web_search(query: str) -> str:\n    \"\"\"\n    Search the web for information.\n    \n    Args:\n        query: Search query string\n    \n    Returns:\n        str: Search results\n    \"\"\"\n    # Implementation here\n    return f\"Search results for: {query}\"\n",
    "source_type": "python",
    "tags": ["search", "web"]
  }' | jq .
```

### Attach Tool to Agent

```bash
# Attach tool to agent
curl -s -X POST http://localhost:8283/v1/agents/AGENT_ID/tools \
  -H "Authorization: Bearer $LETTA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "tools": ["web_search"]
  }' | jq .
```

### Detach Tool from Agent

```bash
# Detach tool from agent
curl -s -X DELETE http://localhost:8283/v1/agents/AGENT_ID/tools/web_search \
  -H "Authorization: Bearer $LETTA_API_KEY" | jq .
```

---

## Advanced Configuration

### Model Configuration

```bash
# Create agent with specific model settings
curl -s -X POST http://localhost:8283/v1/agents/ \
  -H "Authorization: Bearer $LETTA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "configurable-agent",
    "model": "OpenRouter/z-ai/glm-4.5-air:free",
    "description": "Agent with custom model configuration",
    "llm_config": {
      "temperature": 0.7,
      "max_tokens": 2000,
      "top_p": 0.9,
      "frequency_penalty": 0.0,
      "presence_penalty": 0.0
    },
    "memory_blocks": [
      {"label": "persona", "value": "You are a configurable AI assistant.", "limit": 2000},
      {"label": "human", "value": "User preferences will be added here.", "limit": 2000}
    ]
  }' | jq .
```

### Embedding Configuration

```bash
# Create agent with custom embedding model
curl -s -X POST http://localhost:8283/v1/agents/ \
  -H "Authorization: Bearer $LETTA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "embedding-agent",
    "model": "OpenRouter/z-ai/glm-4.5-air:free",
    "description": "Agent with custom embedding model",
    "embedding_config": {
      "embedding_model": "text-embedding-3-small",
      "embedding_dim": 1536
    },
    "memory_blocks": [
      {"label": "persona", "value": "You are a search-optimized assistant.", "limit": 2000},
      {"label": "human", "value": "User context.", "limit": 2000}
    ]
  }' | jq .
```

### Agent Templates

```bash
# Create a reusable agent template
AGENT_TEMPLATE='{
  "model": "'"$LETTA_MODEL"'",
  "memory_blocks": [
    {"label": "persona", "value": "You are a helpful AI assistant.", "limit": 2000},
    {"label": "human", "value": "User context here.", "limit": 2000}
  ],
  "tools": ["memory_edit", "conversation_search"]
}'

# Use template for multiple agents
for name in "assistant-1" "assistant-2" "assistant-3"; do
  curl -s -X POST http://localhost:8283/v1/agents/ \
    -H "Authorization: Bearer $LETTA_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$AGENT_TEMPLATE" | jq .
done
```

---

## Deployment Patterns

### Single-Agent Deployment

Simple deployment for individual use cases:

```bash
# Create a single-purpose agent
AGENT_ID=$(letta_agents_create \
  "customer-support" \
  "Customer service assistant for handling inquiries" \
  "$LETTA_MODEL")

# Deploy with Docker
docker run -d \
  --name letta-support \
  -e LETTA_POSTGRES_URI=$LETTA_POSTGRES_URI \
  -e OPENROUTER_API_KEY=$OPENROUTER_API_KEY \
  -p 8283:8283 \
  letta/letta:latest
```

### Multi-Agent Deployment

Deploy multiple agents for different purposes:

```bash
# Create specialized agents
SUPPORT_AGENT=$(letta_agents_create "support" "Customer support" "$LETTA_MODEL")
SALES_AGENT=$(letta_agents_create "sales" "Sales assistance" "$LETTA_MODEL")
RESEARCH_AGENT=$(letta_agents_create "research" "Research assistant" "$LETTA_MODEL")

# Route requests based on intent
route_request() {
  local intent=$1
  case $intent in
    support) letta_agents_message "$SUPPORT_AGENT" "$2" ;;
    sales) letta_agents_message "$SALES_AGENT" "$2" ;;
    research) letta_agents_message "$RESEARCH_AGENT" "$2" ;;
  esac
}
```

### Agent Pool Deployment

Deploy a pool of identical agents for load balancing:

```bash
# Create agent pool
POOL_SIZE=5
AGENT_IDS=()

for i in $(seq 1 $POOL_SIZE); do
  AGENT_ID=$(letta_agents_create \
    "pool-agent-$i" \
    "Agent #$i in the processing pool" \
    "$LETTA_MODEL")
  AGENT_IDS+=("$AGENT_ID")
done

# Round-robin load balancing
CURRENT_INDEX=0

get_next_agent() {
  local agent_id=${AGENT_IDS[$CURRENT_INDEX]}
  CURRENT_INDEX=$(( (CURRENT_INDEX + 1) % POOL_SIZE ))
  echo "$agent_id"
}

process_request() {
  local agent_id=$(get_next_agent)
  letta_agents_message "$agent_id" "$1"
}
```

### Hierarchical Agent Deployment

Deploy agents in a hierarchical structure:

```bash
# Create supervisor agent
SUPERVISOR=$(letta_agents_create \
  "supervisor" \
  "Orchestrates tasks and delegates to specialist agents" \
  "$LETTA_MODEL")

# Create specialist agents
RESEARCHER=$(letta_agents_create "researcher" "Research specialist" "$LETTA_MODEL")
WRITER=$(letta_agents_create "writer" "Writing specialist" "$LETTA_MODEL")
ANALYST=$(letta_agents_create "analyst" "Data analysis specialist" "$LETTA_MODEL")

# Supervisor delegates tasks
delegate_to_specialist() {
  local task=$1
  local specialist
  
  case $task in
    research) specialist=$RESEARCHER ;;
    writing) specialist=$WRITER ;;
    analysis) specialist=$ANALYST ;;
  esac
  
  letta_agents_message "$specialist" "$task"
}
```

---

## Best Practices

### Memory Block Design

1. **Keep persona concise**: 200-500 tokens is usually sufficient
2. **Use descriptive labels**: Makes memory management easier
3. **Set appropriate limits**: Prevent context overflow
4. **Update regularly**: Keep memory blocks current
5. **Use project blocks**: For task-specific context

### Tool Design

1. **Single responsibility**: Each tool should do one thing well
2. **Clear descriptions**: Help agents understand when to use tools
3. **Error handling**: Return meaningful error messages
4. **Type hints**: Specify parameter types for clarity
5. **Documentation**: Include docstrings for all functions

### Agent Naming

1. **Use descriptive names**: `customer-support` not `agent-1`
2. **Include purpose**: `research-assistant` not `assistant`
3. **Version if needed**: `support-v2` for updated versions
4. **Avoid spaces**: Use hyphens or underscores
5. **Be consistent**: Follow naming conventions across your deployment

### Performance Optimization

1. **Limit message history**: Use appropriate `limit` parameter
2. **Cache frequently used data**: Store in memory blocks
3. **Optimize archival memory**: Regular cleanup of old data
4. **Use appropriate models**: Balance cost and performance
5. **Monitor token usage**: Track and optimize context usage

### Security Considerations

1. **Validate inputs**: Sanitize all user inputs
2. **Limit tool access**: Only attach necessary tools
3. **Audit agent actions**: Log important operations
4. **Use environment variables**: Never hardcode secrets
5. **Regular key rotation**: Update API keys periodically

---

## Troubleshooting

### Agent Creation Fails

**Symptom**: Agent creation returns error

**Possible Causes**:
- Invalid model format
- Missing required memory blocks
- API key authentication failure
- Database connection issue

**Solutions**:
```bash
# Verify model format
echo $LETTA_MODEL

# Check API key
letta_secrets_validate_letta_key

# Test database connection
psql $LETTA_POSTGRES_URI -c "SELECT 1;"

# Check server health
curl -s http://localhost:8283/v1/health | jq .
```

### Agent Not Responding

**Symptom**: Messages to agent timeout or fail

**Possible Causes**:
- Agent not found (wrong ID)
- LLM provider API down
- Context window exceeded
- Server overloaded

**Solutions**:
```bash
# Verify agent exists
letta_agents_get "$AGENT_ID" | jq .

# Check LLM provider status
curl -s https://openrouter.ai/api/v1/auth/key \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" | jq .

# Reduce memory block sizes
# Check server logs
docker logs letta-server
```

### Memory Issues

**Symptom**: Context overflow or memory errors

**Possible Causes**:
- Memory blocks too large
- Too many messages in history
- Archival memory too large
- Context window exceeded

**Solutions**:
```bash
# Check memory block sizes
letta_agents_get "$AGENT_ID" | jq '.memory_blocks'

# Reduce message history limit
letta_agents_list_messages "$AGENT_ID?limit=10"

# Clean up archival memory
# Adjust context window in agent configuration
```

### Tool Calling Fails

**Symptom**: Agent cannot call tools

**Possible Causes**:
- Tool not attached to agent
- Tool has errors
- Tool permissions issue
- Tool not in agent's context

**Solutions**:
```bash
# List agent tools
curl -s http://localhost:8283/v1/agents/AGENT_ID/tools \
  -H "Authorization: Bearer $LETTA_API_KEY" | jq .

# Reattach tool
curl -s -X POST http://localhost:8283/v1/agents/AGENT_ID/tools \
  -H "Authorization: Bearer $LETTA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"tools": ["tool_name"]}' | jq .

# Check tool definition
curl -s http://localhost:8283/v1/tools/tool_name \
  -H "Authorization: Bearer $LETTA_API_KEY" | jq .
```

---

## Getting Help

### Documentation

- **Main Documentation**: `SKILL.md` - Overview and quick start
- **Reference Docs**: `reference/` directory - Detailed API documentation
- **Deployment Guide**: `DEPLOYMENT.md` - Deployment instructions
- **Security Guide**: `SECURITY.md` - Security best practices

### Community Resources

- **Letta Documentation**: [docs.letta.com](https://docs.letta.com)
- **Letta GitHub**: [github.com/letta-ai/letta](https://github.com/letta-ai/letta)
- **Letta Discord**: [discord.gg/letta](https://discord.gg/letta)
- **Letta Forum**: [forum.letta.com](https://forum.letta.com)

### Support Channels

1. **GitHub Issues**: Report bugs and feature requests
2. **Discord**: Real-time community support
3. **Forum**: In-depth discussions and questions
4. **Email**: For security issues (see SECURITY.md)

### Debugging Tips

1. **Enable verbose logging**: Check server logs
2. **Use health checks**: `letta_secrets_validate_all`
3. **Test API directly**: Use curl to test endpoints
4. **Check environment**: Verify all variables are set
5. **Review documentation**: Reference docs have detailed examples

---

## API Reference

### Agent Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/v1/agents/` | Create new agent |
| GET | `/v1/agents/` | List all agents |
| GET | `/v1/agents/{id}` | Get agent details |
| PATCH | `/v1/agents/{id}` | Update agent |
| DELETE | `/v1/agents/{id}` | Delete agent |
| POST | `/v1/agents/{id}/messages` | Send message to agent |
| GET | `/v1/agents/{id}/messages` | List agent messages |
| GET | `/v1/agents/{id}/messages/search` | Search messages |

### Memory Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/v1/blocks/` | Create memory block |
| GET | `/v1/blocks/` | List all blocks |
| GET | `/v1/blocks/{id}` | Get block details |
| PATCH | `/v1/blocks/{id}` | Update block |
| DELETE | `/v1/blocks/{id}` | Delete block |
| POST | `/v1/agents/{id}/memory` | Attach block to agent |
| DELETE | `/v1/agents/{id}/memory/{block_id}` | Detach block from agent |

### Tool Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/v1/tools/` | Create tool |
| GET | `/v1/tools/` | List all tools |
| GET | `/v1/tools/{name}` | Get tool details |
| DELETE | `/v1/tools/{name}` | Delete tool |
| POST | `/v1/agents/{id}/tools` | Attach tool to agent |
| DELETE | `/v1/agents/{id}/tools/{name}` | Detach tool from agent |

### Archival Memory Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/v1/agents/{id}/archival/memory` | Insert into archival memory |
| GET | `/v1/agents/{id}/archival/memory` | List archival memory |
| POST | `/v1/agents/{id}/archival/memory/search` | Search archival memory |
| DELETE | `/v1/agents/{id}/archival/memory/{passage_id}` | Delete archival memory passage |

---

## Additional Resources

### Example Scripts

See `scripts/` directory for helper scripts:
- `letta_client.sh` - API client functions
- `letta_agents.sh` - Agent management
- `letta_memory.sh` - Memory management
- `letta_tools.sh` - Tool management
- `letta_secrets.sh` - Secret validation

### Reference Documentation

Detailed reference documentation in `reference/` and `workflows/`:
- `agents.md` - Agent management API
- `memory.md` - Memory management API
- `tools.md` - Tool management API
- `healthcheck.md` - Health check procedures
- `secrets.md` - Secret management
- `workflows/WORKFLOWS.md` - High-level orchestration scripts for common operations

### Tutorials

- Quick Start: See Quick Start section above
- Advanced Configuration: See Advanced Configuration section
- Deployment Patterns: See Deployment Patterns section

---

## License

This skill is licensed under the Apache License 2.0. See LICENSE file for details.

---

## Contributing

Contributions are welcome! See CONTRIBUTING.md for guidelines.

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
name: letta-folder-archive-manager
description: Create, list, update, delete, and manage Letta folders and files (MemFS). Use this skill for any task involving folder creation, file upload/download, folder organization, or managing the Memory Filesystem feature.
---

# Letta Folder & Archive Manager

## Environment
```bash
# Auto-load Letta environment

export LETTA_BASE_URL=${LETTA_BASE_URL:-http://localhost:8283}
export LETTA_API_KEY=${LETTA_API_KEY:?LETTA_API_KEY is required. Copy .env.example to .env and set your key.}
```

## FOLDERS

### List all folders
```bash
# Auto-load Letta environment
curl -s -L http://localhost:8283/v1/folders/ \
  -H "Authorization: Bearer $LETTA_API_KEY" | jq '.[] | {id, name}'
```

### Create a folder
```bash
# Auto-load Letta environment
curl -s -L -X POST http://localhost:8283/v1/folders/ \
  -H "Authorization: Bearer $LETTA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "FOLDER_NAME",
    "description": "FOLDER_DESCRIPTION",
    "embedding_config": {
      "embedding_endpoint_type": "openai",
      "embedding_model": "openai/text-embedding-3-small",
      "embedding_dim": 1536,
      "embedding_chunk_size": 300
    }
  }' | jq '{id, name}'
```

### Retrieve a specific folder
```bash
# Auto-load Letta environment
curl -s -L http://localhost:8283/v1/folders/FOLDER_ID \
  -H "Authorization: Bearer $LETTA_API_KEY" | jq .
```

### Update a folder
```bash
# Auto-load Letta environment
curl -s -L -X PATCH http://localhost:8283/v1/folders/FOLDER_ID \
  -H "Authorization: Bearer $LETTA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "NEW_FOLDER_NAME",
    "description": "NEW_FOLDER_DESCRIPTION"
  }'
```

### Delete a folder
```bash
# Auto-load Letta environment
curl -s -L -X DELETE http://localhost:8283/v1/folders/FOLDER_ID \
  -H "Authorization: Bearer $LETTA_API_KEY"
```

## FILES (within folders)

### List files in a folder
```bash
# Auto-load Letta environment
curl -s -L "http://localhost:8283/v1/folders/FOLDER_ID/files?limit=100" \
  -H "Authorization: Bearer $LETTA_API_KEY" | jq '.[] | {id, name, size}'
```

### Upload a file to a folder
```bash
# Auto-load Letta environment
curl -s -L -X POST "http://localhost:8283/v1/folders/FOLDER_ID/files" \
  -H "Authorization: Bearer $LETTA_API_KEY" \
  -F "file=@LOCAL_FILE_PATH" \
  -F "description=FILE_DESCRIPTION" | jq '{id, name}'
```

### Download a file from a folder
```bash
# Auto-load Letta environment
curl -s -L -X GET "http://localhost:8283/v1/folders/FOLDER_ID/files/FILE_ID" \
  -H "Authorization: Bearer $LETTA_API_KEY" \
  -o LOCAL_FILE_PATH
```

### Delete a file from a folder
```bash
# Auto-load Letta environment
curl -s -L -X DELETE "http://localhost:8283/v1/folders/FOLDER_ID/files/FILE_ID" \
  -H "Authorization: Bearer $LETTA_API_KEY"
```

## MEMFS (Memory Filesystem)

### Enable MemFS for an agent
```bash
# Auto-load Letta environment
curl -s -L -X PATCH http://localhost:8283/v1/agents/AGENT_ID \
  -H "Authorization: Bearer $LETTA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"memfs": true}'
```

### Check MemFS status for an agent
```bash
# Auto-load Letta environment
curl -s -L http://localhost:8283/v1/agents/AGENT_ID/memfs/status \
  -H "Authorization: Bearer $LETTA_API_KEY" | jq .
```

### Backup MemFS for an agent
```bash
# Auto-load Letta environment
curl -s -L -X POST http://localhost:8283/v1/agents/AGENT_ID/memfs/backup \
  -H "Authorization: Bearer $LETTA_API_KEY" | jq .
```

### Restore MemFS for an agent
```bash
# Auto-load Letta environment
curl -s -L -X POST http://localhost:8283/v1/agents/AGENT_ID/memfs/restore \
  -H "Authorization: Bearer $LETTA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"backup_id": "BACKUP_ID"}'
```

## Rules
- Folder names should be lowercase with hyphens or underscores
- Always verify folder/file IDs before performing update/delete operations
- Use descriptive names and descriptions for folders and files
- MemFS operations require the agent to have memfs enabled
- When uploading files, ensure you have read permissions on the local file
- For large files, consider using streaming uploads or breaking into smaller chunks

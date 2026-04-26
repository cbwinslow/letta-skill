#!/usr/bin/env python3
"""
Letta Skill — SDK-based Python library
Thin wrapper around the official letta-client SDK.
"""

import json
import os
import sys
from pathlib import Path
from typing import Optional, List, Dict, Any

from letta_client import Letta

# ─── Environment ──────────────────────────────────────────────────────────────

SKILL_DIR = Path(__file__).parent.parent.parent
DEFAULT_ENV_FILE = SKILL_DIR / ".env"


def load_env(env_file: Path = DEFAULT_ENV_FILE) -> None:
    """Load .env configuration into os.environ (if file exists)."""
    if env_file.exists():
        from dotenv import load_dotenv
        load_dotenv(env_file)


def get_client() -> Letta:
    """Create and return an authenticated Letta client."""
    load_env()
    return Letta(
        api_key=os.getenv("LETTA_API_KEY"),
        base_url=os.getenv("LETTA_BASE_URL", "http://localhost:8283"),
    )


# ─── HTTP Helper (for endpoints not yet in SDK) ───────────────────────────────

import httpx

def _get_headers() -> Dict[str, str]:
    api_key = os.getenv("LETTA_API_KEY", "")
    return {"Authorization": f"Bearer {api_key}"}


def _get_base_url() -> str:
    return os.getenv("LETTA_BASE_URL", "http://localhost:8283").rstrip("/")


def _request(method: str, path: str, **kwargs) -> Any:
    """Make an authenticated HTTP request to the Letta API."""
    load_env()  # ensure .env is loaded
    url = _get_base_url() + path
    headers = _get_headers()
    existing = kwargs.pop("headers", {})
    headers.update(existing)
    resp = httpx.request(method, url, headers=headers, follow_redirects=True, **kwargs)
    resp.raise_for_status()
    if resp.status_code == 204:
        return {}
    return resp.json()


# ─── Agents ───────────────────────────────────────────────────────────────────

def list_agents(limit: int = 100) -> List[Dict[str, Any]]:
    client = get_client()
    agents = list(getattr(client.agents, "list", lambda: [])())
    return [
        {
            "id": a.id,
            "name": a.name,
            "description": a.description,
            "model": a.model,
            "created_at": (
                a.created_at.isoformat() if hasattr(a.created_at, "isoformat") else str(a.created_at)
            ),
        }
        for a in agents[:limit]
    ]


def get_agent(agent_id: str) -> Dict[str, Any]:
    client = get_client()
    a = client.agents.retrieve(agent_id=agent_id, include=["agent.tools"])
    blocks = list_blocks(agent_id)
    tool_names = [t.name for t in (a.tools or [])]
    return {
        "id": a.id,
        "name": a.name,
        "description": a.description,
        "model": a.model,
        "created_at": (
            a.created_at.isoformat() if hasattr(a.created_at, "isoformat") else str(a.created_at)
        ),
        "memory_blocks": blocks,
        "tools": tool_names,
        "num_messages": getattr(a, "num_messages", None),
        "message_ids": getattr(a, "message_ids", []),
    }


def create_agent(
    name: str,
    description: str,
    model: str = "OpenRouter/z-ai/glm-4.5-air:free",
    persona: str = "You are a helpful AI assistant.",
    human: str = "The user is interacting with you for assistance.",
    project: str = "",
    tools: Optional[List[str]] = None,
) -> str:
    if tools is None:
        tools = []  # No default tools; attach explicitly as needed

    blocks = [
        {"label": "persona", "value": persona, "limit": 2000},
        {"label": "human", "value": human, "limit": 2000},
    ]
    if project:
        blocks.append({"label": "project", "value": project, "limit": 4000})

    client = get_client()
    agent = client.agents.create(
        name=name,
        description=description,
        model=model,
        memory_blocks=blocks,
        tools=tools,
    )
    return agent.id


def create_agent_with_blocks(
    name: str,
    description: str,
    model: str,
    blocks: List[Dict[str, Any]],
    tools: Optional[List[str]] = None,
) -> str:
    """Create an agent with explicit memory blocks (bypasses persona/human template)."""
    if tools is None:
        tools = []  # No default tools; attach explicitly as needed
    client = get_client()
    agent = client.agents.create(
        name=name,
        description=description,
        model=model,
        memory_blocks=blocks,
        tools=tools,
    )
    return agent.id


def delete_agent(agent_id: str) -> bool:
    client = get_client()
    client.agents.delete(agent_id=agent_id)
    return True


def send_message(agent_id: str, message: str) -> List[Dict[str, Any]]:
    client = get_client()
    response = client.agents.messages.create(agent_id=agent_id, input=message)
    return [_message_to_dict(m) for m in response.messages]


def list_messages(agent_id: str, limit: int = 20) -> List[Dict[str, Any]]:
    client = get_client()
    msgs = list(client.agents.messages.list(agent_id=agent_id))[:limit]
    return [_message_to_dict(m) for m in msgs]


def search_messages(agent_id: str, query: str, limit: int = 10) -> List[Dict[str, Any]]:
    client = get_client()
    response = client.agents.messages.search(agent_id=agent_id, query=query, top_k=limit)
    results = response.results if hasattr(response, "results") else []
    return [
        {
            "content": r.content,
            "created_at": (
                r.created_at.isoformat()
                if hasattr(r.created_at, "isoformat")
                else str(r.created_at)
            ),
        }
        for r in results
    ]


def attach_tool(agent_id: str, tool_id_or_name: str) -> bool:
    client = get_client()
    # Resolve tool name to ID if needed
    tool_id = tool_id_or_name
    if not tool_id.startswith("tool-"):
        # Look up tool by name
        tools = list_tools()
        match = next((t for t in tools if t.get("name") == tool_id_or_name), None)
        if not match:
            raise ValueError(f"Tool not found: {tool_id_or_name}")
        tool_id = match["id"]
    client.agents.tools.attach(agent_id=agent_id, tool_id=tool_id)
    return True


def detach_tool(agent_id: str, tool_id_or_name: str) -> bool:
    client = get_client()
    tool_id = tool_id_or_name
    if not tool_id.startswith("tool-"):
        tools = list_agent_tools(agent_id)
        match = next((t for t in tools if t.get("name") == tool_id_or_name), None)
        if not match:
            raise ValueError(f"Tool not found on agent: {tool_id_or_name}")
        tool_id = match["id"]
    client.agents.tools.detach(agent_id=agent_id, tool_id=tool_id)
    return True


# ─── FOLDERS ───────────────────────────────────────────────────────────────────

def list_agent_folders(agent_id: str) -> List[Dict[str, Any]]:
    """List folders attached to an agent."""
    data = _request("GET", f"/v1/agents/{agent_id}/folders")
    return [{"id": f.get("id"), "name": f.get("name")} for f in data]


def attach_folder(agent_id: str, folder_id: str) -> bool:
    """Attach a folder to an agent."""
    _request("POST", f"/v1/agents/{agent_id}/folders", json={"folder_ids": [folder_id]})
    return True


def detach_folder(agent_id: str, folder_id: str) -> bool:
    """Detach a folder from an agent."""
    _request("DELETE", f"/v1/agents/{agent_id}/folders/{folder_id}")
    return True


# ─── Memory Blocks ─────────────────────────────────────────────────────────────

def list_blocks(agent_id: str) -> List[Dict[str, Any]]:
    client = get_client()
    blocks = list(client.agents.blocks.list(agent_id=agent_id))
    return [
        {
            "id": b.id,
            "label": b.label,
            "value": b.value,
            "limit": getattr(b, "limit", None),
        }
        for b in blocks
    ]


def get_block(agent_id: str, block_label: str) -> Dict[str, Any]:
    client = get_client()
    b = client.agents.blocks.retrieve(agent_id=agent_id, block_label=block_label)
    return {"id": b.id, "label": b.label, "value": b.value, "limit": getattr(b, "limit", None)}


def update_block(block_id: str, value: str) -> None:
    client = get_client()
    client.blocks.patch(block_id=block_id, value=value)


def create_block(label: str, value: str, limit: int = 2000) -> str:
    client = get_client()
    b = client.blocks.create(label=label, value=value, limit=limit)
    return b.id


# ─── Archival Memory ────────────────────────────────────────────────────────────

def archival_search(agent_id: str, query: str, limit: int = 10) -> List[Dict[str, Any]]:
    client = get_client()
    response = client.agents.passages.search(agent_id=agent_id, query=query, top_k=limit)
    results = response.results if hasattr(response, "results") else []
    return [
        {
            "id": p.id,
            "content": p.content,
            "timestamp": str(p.timestamp) if p.timestamp else "",
            "tags": p.tags or [],
        }
        for p in results
    ]


def archival_insert(
    agent_id: str, text: str, tags: Optional[List[str]] = None
) -> str:
    if tags is None:
        tags = []
    client = get_client()
    result = client.agents.passages.create(agent_id=agent_id, text=text, tags=tags)
    passage = result[0] if isinstance(result, list) and result else result
    return str(passage.id)


def list_archival(agent_id: str, limit: int = 100) -> List[Dict[str, Any]]:
    client = get_client()
    passages = client.agents.passages.list(agent_id=agent_id, limit=limit)
    return [
        {
            "id": p.id,
            "content": p.text[:200] + ("..." if len(p.text) > 200 else ""),
            "full_content": p.text,
            "created_at": p.created_at.isoformat() if hasattr(p.created_at, "isoformat") else str(p.created_at),
            "tags": p.tags or [],
        }
        for p in passages
    ]


def delete_archival(agent_id: str, passage_id: str) -> bool:
    client = get_client()
    client.agents.passages.delete(agent_id=agent_id, passage_id=passage_id)
    return True


# ─── Tools ─────────────────────────────────────────────────────────────────────

def list_tools() -> List[Dict[str, Any]]:
    client = get_client()
    tools = list(client.tools.list())
    return [
        {
            "id": t.id,
            "name": t.name,
            "description": t.description,
            "source_type": t.source_type,
        }
        for t in tools
    ]


def list_agent_tools(agent_id: str) -> List[Dict[str, Any]]:
    client = get_client()
    tools = list(client.agents.tools.list(agent_id=agent_id))
    return [{"id": t.id, "name": t.name} for t in tools]


def create_tool(
    name: str,
    description: str,
    source_code: str,
    source_type: str = "python",
    tags: Optional[List[str]] = None,
) -> str:
    if tags is None:
        tags = []
    client = get_client()
    t = client.tools.create(
        name=name,
        description=description,
        source_code=source_code,
        source_type=source_type,
        tags=tags,
    )
    return t.id


def update_tool(tool_id: str, **kwargs) -> Dict[str, Any]:
    client = get_client()
    t = client.tools.patch(tool_id=tool_id, **kwargs)
    return {"id": t.id, "name": t.name, "description": t.description}


def delete_tool(tool_id: str) -> bool:
    client = get_client()
    client.tools.delete(tool_id=tool_id)
    return True


# ─── Conversations ─────────────────────────────────────────────────────────────

def create_conversation(
    agent_id: str,
    name: Optional[str] = None,
    first_message: Optional[str] = None,
) -> Dict[str, Any]:
    payload: Dict[str, Any] = {}
    if name:
        payload["title"] = name  # accepted or ignored by server
    if first_message:
        payload["messages"] = [{"role": "user", "content": first_message}]
    data = _request("POST", "/v1/conversations", params={"agent_id": agent_id}, json=payload)
    return {
        "conversation_id": data.get("id"),
        "agent_id": agent_id,
        "name": data.get("title") or data.get("name") or data.get("summary"),
        "created_at": data.get("created_at"),
    }


def send_conversation_message(conversation_id: str, message: str) -> Dict[str, Any]:
    """Send a message to a conversation and collect assistant responses via streaming."""
    import httpx
    import json

    load_env()
    url = f"{_get_base_url()}/v1/conversations/{conversation_id}/messages"
    headers = _get_headers()
    payload = {"messages": [{"role": "user", "content": message}], "stream": True}
    collected: List[Dict[str, Any]] = []
    with httpx.stream("POST", url, headers=headers, json=payload, follow_redirects=True, timeout=60.0) as resp:
        resp.raise_for_status()
        for line in resp.iter_lines():
            line = line.strip()
            if line.startswith("data:"):
                raw = line[5:].strip()
                if not raw:
                    continue
                try:
                    data = json.loads(raw)
                except json.JSONDecodeError:
                    continue
                # Identify assistant messages
                msg_type = data.get("message_type", "")
                if msg_type == "assistant_message":
                    collected.append({
                        "id": data.get("id", ""),
                        "role": "assistant",
                        "content": data.get("content", ""),
                        "created_at": data.get("date", ""),
                    })
                elif "role" in data:
                    # Fallback for events that already carry role
                    collected.append({
                        "id": data.get("id", ""),
                        "role": data.get("role", "unknown"),
                        "content": data.get("content", ""),
                        "created_at": data.get("date", ""),
                    })
    return {"messages": collected}


# ─── Identities ────────────────────────────────────────────────────────────────

def create_identity(identifier: str, name: str) -> str:
    payload = {
        "identifier_key": identifier,
        "name": name,
        "identity_type": "user",
    }
    data = _request("POST", "/v1/identities", json=payload)
    return str(data.get("id"))


def link_agent_to_identity(identity_id: str, agent_id: str) -> bool:
    client = get_client()
    client.agents.update(agent_id=agent_id, identity_ids=[identity_id])
    return True


# ─── Health ────────────────────────────────────────────────────────────────────

def check_health() -> Dict[str, Any]:
    client = get_client()
    try:
        resp = client.health()
        return {"status": "ok", "data": str(resp)}
    except Exception as e:
        return {"status": "unhealthy", "error": str(e)}


def check_env() -> Dict[str, Any]:
    required = ["LETTA_API_KEY", "LETTA_BASE_URL"]
    missing = [k for k in required if not os.getenv(k)]
    return {
        "required_vars": required,
        "missing": missing,
        "ok": len(missing) == 0,
        "sample_values": {
            "LETTA_BASE_URL": os.getenv("LETTA_BASE_URL"),
            "LETTA_MODEL": os.getenv("LETTA_MODEL"),
        },
    }


def full_health_check() -> Dict[str, Any]:
    import time
    start = time.time()
    return {
        "timestamp": __import__("datetime").datetime.now().isoformat(),
        "checks": {
            "environment": check_env(),
            "letta_server": check_health(),
        },
        "overall_status": "ok" if check_health().get("status") == "ok" else "unhealthy",
        "duration_seconds": time.time() - start,
    }


# ─── Helpers ──────────────────────────────────────────────────────────────────

def _agent_to_dict(a) -> Dict[str, Any]:
    return {
        "id": a.id,
        "name": a.name,
        "description": a.description,
        "model": a.model,
        "created_at": (
            a.created_at.isoformat() if hasattr(a.created_at, "isoformat") else str(a.created_at)
        ),
        "memory_blocks": [
            {
                "id": b.id,
                "label": b.label,
                "value": b.value,
                "limit": getattr(b, "limit", None),
            }
            for b in a.memory_blocks
        ],
        "tools": [t.name for t in (a.tools or [])],
        "num_messages": getattr(a, "num_messages", None),
    }


def _message_to_dict(m) -> Dict[str, Any]:
    # Determine role
    role = getattr(m, "role", None)
    if role is None:
        cls = type(m).__name__
        if "User" in cls:
            role = "user"
        elif "Assistant" in cls:
            role = "assistant"
        else:
            role = "unknown"
    content = getattr(m, "content", None) or getattr(m, "text", None) or ""
    created_at = getattr(m, "created_at", None)
    if created_at is not None and hasattr(created_at, "isoformat"):
        created_at = created_at.isoformat()
    else:
        created_at = str(created_at) if created_at else ""
    return {"role": role, "content": content, "created_at": created_at}


def json_output(data: Any) -> None:
    """Print data as JSON to stdout."""
    print(json.dumps(data, indent=2, default=str))


# ─── CLI ───────────────────────────────────────────────────────────────────────

def main() -> None:
    """Simple CLI dispatcher for quick shell usage."""
    if len(sys.argv) < 2:
        print("Usage: letta <command> [args...]", file=sys.stderr)
        print("\nCommands:", file=sys.stderr)
        print("  agents list", file=sys.stderr)
        print("  agents get <agent_id>", file=sys.stderr)
        print("  agents create <name> <desc> [model]  (or pipe blocks JSON to stdin)", file=sys.stderr)
        print("  agents delete <agent_id>", file=sys.stderr)
        print("  agents message <agent_id> <text>", file=sys.stderr)
        print("  agents attach-tool <agent_id> <tool_id>", file=sys.stderr)
        print("  agents detach-tool <agent_id> <tool_id>", file=sys.stderr)
        print("  agents attach-folder <agent_id> <folder_id>", file=sys.stderr)
        print("  agents detach-folder <agent_id> <folder_id>", file=sys.stderr)
        print("  messages list <agent_id> [limit]", file=sys.stderr)
        print("  messages search <agent_id> <query> [limit]", file=sys.stderr)
        print("  blocks list <agent_id>", file=sys.stderr)
        print("  blocks get <agent_id> <label>", file=sys.stderr)
        print("  blocks create <label> <value> [limit]", file=sys.stderr)
        print("  blocks update <block_id> <value>", file=sys.stderr)
        print("  archival search <agent_id> <query> [limit]", file=sys.stderr)
        print("  archival insert <agent_id> <text> [tags...]", file=sys.stderr)
        print("  archival list <agent_id> [limit]", file=sys.stderr)
        print("  archival delete <agent_id> <passage_id>", file=sys.stderr)
        print("  tools list", file=sys.stderr)
        print("  tools list-agent <agent_id>", file=sys.stderr)
        print("  tools create <name> <desc> <source_code> [tags...]", file=sys.stderr)
        print("  tools update <tool_id> [key=value ...]", file=sys.stderr)
        print("  tools delete <tool_id>", file=sys.stderr)
        print("  folders list <agent_id>", file=sys.stderr)
        print("  conversations start <agent_id> [name] [first_message]", file=sys.stderr)
        print("  conversations continue <conversation_id> <message>", file=sys.stderr)
        print("  identities create <identifier> <name>", file=sys.stderr)
        print("  identities link <identity_id> <agent_id>", file=sys.stderr)
        print("  health", file=sys.stderr)
        print("  health --full", file=sys.stderr)
        sys.exit(1)

    cmd = sys.argv[1]
    args = sys.argv[2:]

    try:
        if cmd == "agents" and args:
            sub = args[0]
            if sub == "list":
                json_output(list_agents())
            elif sub == "get" and args[1:]:
                json_output(get_agent(args[1]))
            elif sub == "create" and len(args) >= 3:
                name, desc = args[1], args[2]
                model = args[3] if len(args) > 3 else "OpenRouter/z-ai/glm-4.5-air:free"
                if not sys.stdin.isatty():
                    blocks = json.load(sys.stdin)
                    agent_id = create_agent_with_blocks(name, desc, model, blocks)
                else:
                    agent_id = create_agent(name, desc, model)
                print(agent_id)
            elif sub == "delete" and args[1:]:
                delete_agent(args[1])
                print("Deleted")
            elif sub == "message" and len(args) >= 3:
                turns = send_message(args[1], args[2])
                json_output(turns)
            elif sub == "attach-tool" and len(args) >= 3:
                attach_tool(args[1], args[2])
                print("Attached")
            elif sub == "detach-tool" and len(args) >= 3:
                detach_tool(args[1], args[2])
                print("Detached")
            elif sub == "attach-folder" and len(args) >= 3:
                attach_folder(args[1], args[2])
                print("Attached")
            elif sub == "detach-folder" and len(args) >= 3:
                detach_folder(args[1], args[2])
                print("Detached")
            else:
                raise ValueError(f"Unknown agents subcommand: {sub}")

        elif cmd == "messages" and args:
            sub = args[0]
            if sub == "list" and args[1:]:
                limit = int(args[2]) if len(args) > 2 else 20
                json_output(list_messages(args[1], limit))
            elif sub == "search" and len(args) >= 3:
                limit = int(args[3]) if len(args) > 3 else 10
                json_output(search_messages(args[1], args[2], limit))
            else:
                raise ValueError(f"Unknown messages subcommand: {sub}")

        elif cmd == "blocks" and args:
            sub = args[0]
            if sub == "list" and args[1:]:
                json_output(list_blocks(args[1]))
            elif sub == "get" and len(args) >= 3:
                json_output(get_block(args[1], args[2]))
            elif sub == "create" and len(args) >= 3:
                label, value = args[1], args[2]
                limit = int(args[3]) if len(args) > 3 else 2000
                block_id = create_block(label, value, limit)
                print(block_id)
            elif sub == "update" and len(args) >= 3:
                block_id, value = args[1], args[2]
                update_block(block_id, value)
                print("Updated")
            else:
                raise ValueError(f"Unknown blocks subcommand: {sub}")

        elif cmd == "archival" and args:
            sub = args[0]
            if sub == "search" and len(args) >= 3:
                agent_id, query = args[1], args[2]
                limit = int(args[3]) if len(args) > 3 else 10
                json_output(archival_search(agent_id, query, limit))
            elif sub == "insert" and len(args) >= 3:
                agent_id, text = args[1], args[2]
                tags = args[3:] if len(args) > 3 else []
                passage_id = archival_insert(agent_id, text, tags)
                print(passage_id)
            elif sub == "list" and args[1:]:
                agent_id = args[1]
                limit = int(args[2]) if len(args) > 2 else 100
                json_output(list_archival(agent_id, limit))
            elif sub == "delete" and len(args) >= 3:
                agent_id, passage_id = args[1], args[2]
                delete_archival(agent_id, passage_id)
                print("Deleted")
            else:
                raise ValueError(f"Unknown archival subcommand: {sub}")

        elif cmd == "tools" and args:
            sub = args[0]
            if sub == "list":
                json_output(list_tools())
            elif sub == "list-agent" and args[1:]:
                json_output(list_agent_tools(args[1]))
            elif sub == "create" and len(args) >= 3:
                name, desc = args[1], args[2]
                source_code = args[3] if len(args) > 3 else ""
                tags = args[4:] if len(args) > 4 else []
                tool_id = create_tool(name, desc, source_code, tags=tags)
                print(tool_id)
            elif sub == "update" and len(args) >= 2:
                tool_id = args[1]
                updates = {}
                for kv in args[2:]:
                    if "=" in kv:
                        k, v = kv.split("=", 1)
                        updates[k] = v
                if updates:
                    json_output(update_tool(tool_id, **updates))
                else:
                    print("No updates provided")
            elif sub == "delete" and args[1:]:
                tool_id = args[1]
                delete_tool(tool_id)
                print("Deleted")
            else:
                raise ValueError(f"Unknown tools subcommand: {sub}")

        elif cmd == "folders" and args:
            sub = args[0]
            if sub == "list" and args[1:]:
                json_output(list_agent_folders(args[1]))
            else:
                raise ValueError(f"Unknown folders subcommand: {sub}")

        elif cmd == "conversations" and args:
            sub = args[0]
            if sub == "start" and args[1:]:
                agent_id = args[1]
                name = args[2] if len(args) > 2 else None
                first_message = args[3] if len(args) > 3 else None
                json_output(create_conversation(agent_id, name, first_message))
            elif sub == "continue" and len(args) >= 3:
                conversation_id = args[1]
                message = args[2]
                json_output(send_conversation_message(conversation_id, message))
            else:
                raise ValueError(f"Unknown conversations subcommand: {sub}")

        elif cmd == "identities" and args:
            sub = args[0]
            if sub == "create" and len(args) >= 3:
                identifier, name = args[1], args[2]
                identity_id = create_identity(identifier, name)
                print(identity_id)
            elif sub == "link" and len(args) >= 3:
                identity_id, agent_id = args[1], args[2]
                link_agent_to_identity(identity_id, agent_id)
                print("Linked")
            else:
                raise ValueError(f"Unknown identities subcommand: {sub}")

        elif cmd == "health":
            if args and args[0] == "--full":
                json_output(full_health_check())
            else:
                json_output(check_health())

        else:
            raise ValueError(f"Unknown command: {cmd}")

    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()

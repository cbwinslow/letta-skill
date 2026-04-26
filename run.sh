#!/usr/bin/env bash
# =============================================================================
# run.sh — letta-skill unified entry point
#
# Usage:
#   ./run.sh <module> <command> [args...]
#   ./run.sh help
# =============================================================================
set -euo pipefail
# DEBUG: uncomment to trace execution
# set -x

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --------------------------------------------------------------------------
# Colors
# --------------------------------------------------------------------------
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${GREEN}[letta-skill]${NC} $*"; }
warn()  { echo -e "${YELLOW}[warn]${NC}  $*"; }
error() { echo -e "${RED}[error]${NC} $*" >&2; }
usage() { echo -e "${CYAN}$*${NC}"; }

# --------------------------------------------------------------------------
# Load .env
# --------------------------------------------------------------------------
if [[ -f "$SCRIPT_DIR/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/.env"
  set +a
else
  error ".env not found. Run ./setup.sh first."
  exit 1
fi

# Also source the centralized .env.letta if it exists (provides defaults)
if [[ -f "/home/cbwinslow/infra/letta/.env.letta" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "/home/cbwinslow/infra/letta/.env.letta"
  set +a
fi

# Validate minimum env
: "${LETTA_BASE_URL:?LETTA_BASE_URL not set in .env}"
: "${LETTA_API_KEY:?LETTA_API_KEY not set in .env}"

# --------------------------------------------------------------------------
# Source all helper scripts from the actual tools location
# --------------------------------------------------------------------------
HELPER_DIR="/home/cbwinslow/infra/letta/tools"

if [[ ! -d "$HELPER_DIR" ]]; then
  error "Helper scripts directory not found: $HELPER_DIR"
  exit 1
fi

for f in "$HELPER_DIR"/letta_*.sh; do
  if [[ -f "$f" ]]; then
    # shellcheck disable=SC1090
    source "$f"
  fi
done

# --------------------------------------------------------------------------
# Help text
# --------------------------------------------------------------------------
print_help() {
  echo ""
  echo -e "${CYAN}letta-skill — Unified Letta Server CLI${NC}"
  echo ""
  echo "Usage: ./run.sh <module> <command> [args...]"
  echo ""
  echo -e "${YELLOW}Modules & Commands:${NC}"
  echo ""
  echo "  health                            — Full system health check"
  echo ""
  echo "  agent  list                       — List all agents"
  echo "         get        <id>            — Get agent details"
  echo "         create     <name> <desc> [model]  — Create agent"
  echo "         update     <id> <name>     — Rename agent"
  echo "         delete     <id>            — Delete agent"
  echo "         message    <id> <text>     — Send message, get reply"
  echo "         messages   <id>            — Fetch message history"
  echo "         search     <id> <query>    — Search message history"
  echo ""
  echo "  memory list-blocks  <agent-id>   — List blocks attached to agent"
  echo "         list-all                  — List all blocks globally"
  echo "         get         <block-id>    — Get block content"
  echo "         update      <block-id> <content>  — Update block value"
  echo "         create      <label> <content> [agent-id]  — Create (+ optionally attach)"
  echo "         attach      <agent-id> <block-id>  — Attach block to agent"
  echo "         detach      <agent-id> <block-id>  — Detach block from agent"
  echo "         delete      <block-id>    — Delete block"
  echo "         archival-insert  <agent-id> <text>   — Insert into archival"
  echo "         archival-search  <agent-id> <query>  — Search archival"
  echo "         archival-delete  <agent-id> <passage-id>  — Delete archival passage"
  echo ""
  echo "  identity list                    — List all identities"
  echo "           get         <id>        — Get identity details"
  echo "           create      <name> <type> [project]  — Create identity"
  echo "           update      <id> <name> — Update identity"
  echo "           delete      <id>        — Delete identity"
  echo "           attach-agent <id> <agent-id>  — Attach agent to identity"
  echo "           detach-agent <id> <agent-id>  — Detach agent from identity"
  echo "           agents      <id>        — List agents for identity"
  echo "           memory      <id>        — Get core memory for identity"
  echo "           update-memory <id> <block-id> <content>  — Update memory block"
  echo "           archival    <id>        — Get archival memory for identity"
  echo "           archival-insert <id> <text>   — Insert into identity archival"
  echo "           message     <id> <text> — Send message via identity"
  echo ""
  echo "  folder list                      — List all folders"
  echo "         get          <id>         — Get folder details"
  echo "         create       <name>       — Create folder"
  echo "         update       <id> <name>  — Rename folder"
  echo "         delete       <id>         — Delete folder"
  echo "         files        <id>         — List files in folder"
  echo "         upload       <folder-id> <file-path>  — Upload file"
  echo "         download     <folder-id> <file-id> [dest]  — Download file"
  echo "         delete-file  <folder-id> <file-id>  — Delete file"
  echo "         memfs-enable  <agent-id>  — Enable MemFS for agent"
  echo "         memfs-status  <agent-id>  — Get MemFS status"
  echo "         memfs-backup  <agent-id>  — Backup MemFS"
  echo "         memfs-restore <agent-id> <backup-file>  — Restore MemFS"
  echo ""
  echo "  tool list                        — List all tools"
  echo "       list-attached  <agent-id>   — List tools on agent"
  echo "       get            <id>         — Get tool details"
  echo "       search         <query>      — Search tools by name"
  echo "       create         <name> <desc> <source-file>  — Register tool from file"
  echo "       attach         <agent-id> <tool-id>  — Attach tool to agent"
  echo "       detach         <agent-id> <tool-id>  — Detach tool from agent"
  echo "       update         <id> <source-file>    — Update tool source"
  echo "       delete         <id>         — Delete tool"
  echo ""
  echo "  secret list                      — List env vars letta-skill looks for"
  echo "         check        <VAR>        — Check if env var is set"
  echo "         validate-letta            — Test Letta server connectivity"
  echo "         validate-openrouter       — Test OpenRouter API key"
  echo "         validate-db               — Test PostgreSQL connectivity"
  echo "         validate-all              — Run all validation checks"
  echo ""
  echo -e "  ${YELLOW}help${NC}                             — Show this message"
  echo ""
}

# --------------------------------------------------------------------------
# Main dispatch
# --------------------------------------------------------------------------
MODULE="${1:-help}"
COMMAND="${2:-}"
shift 2 2>/dev/null || true   # remaining args in $@

case "$MODULE" in

  # ---- health --------------------------------------------------------------
  health)
    info "Running full health check..."
    letta_secrets_validate_all
    ;;

  # ---- agent ---------------------------------------------------------------
  agent|agents)
    case "$COMMAND" in
      list)           letta_agents_list | jq . ;;
      get)            letta_agents_get "$1" | jq . ;;
      create)         letta_agents_create "$1" "${2:-}" "${3:-${LETTA_MODEL:-}}" | jq . ;;
      update)         letta_agents_update "$1" "$2" | jq . ;;
      delete)         letta_agents_delete "$1" && info "Agent $1 deleted." ;;
      message)        letta_agents_message "$1" "$2" | jq . ;;
      messages)       letta_agents_messages "$1" | jq . ;;
      search)         letta_agents_messages_search "$1" "$2" | jq . ;;
      *)  error "Unknown agent command: $COMMAND"; print_help; exit 1 ;;
    esac
    ;;

  # ---- memory --------------------------------------------------------------
  memory|mem)
    case "$COMMAND" in
      list-blocks)       letta_memory_list_blocks "$1" | jq . ;;
      list-all)          letta_memory_list_all_blocks | jq . ;;
      get)               letta_memory_get_block "$1" | jq . ;;
      update)            letta_memory_update_block "$1" "$2" | jq . ;;
      create)            letta_memory_create_block "$1" "$2" "${3:-}" | jq . ;;
      attach)            letta_memory_attach_block "$1" "$2" && info "Block $2 attached to agent $1." ;;
      detach)            letta_memory_detach_block "$1" "$2" && info "Block $2 detached from agent $1." ;;
      delete)            letta_memory_delete_block "$1" && info "Block $1 deleted." ;;
      archival-insert)   letta_memory_archival_insert "$1" "$2" | jq . ;;
      archival-search)   letta_memory_archival_search "$1" "$2" | jq . ;;
      archival-delete)   letta_memory_archival_delete "$1" "$2" && info "Passage $2 deleted." ;;
      *)  error "Unknown memory command: $COMMAND"; print_help; exit 1 ;;
    esac
    ;;

  # ---- identity ------------------------------------------------------------
  identity|identities|id)
    case "$COMMAND" in
      list)           letta_identities_list | jq . ;;
      get)            letta_identities_get "$1" | jq . ;;
      create)         letta_identities_create "$1" "${2:-user}" "${3:-}" | jq . ;;
      update)         letta_identities_update "$1" "$2" | jq . ;;
      delete)         letta_identities_delete "$1" && info "Identity $1 deleted." ;;
      attach-agent)   letta_identities_attach_agent "$1" "$2" && info "Agent $2 attached to identity $1." ;;
      detach-agent)   letta_identities_detach_agent "$1" "$2" && info "Agent $2 detached from identity $1." ;;
      agents)         letta_identities_list_agents "$1" | jq . ;;
      memory)         letta_identities_get_core_memory "$1" | jq . ;;
      update-memory)  letta_identities_update_core_memory_block "$1" "$2" "$3" | jq . ;;
      archival)       letta_identities_get_archival_memory "$1" | jq . ;;
      archival-insert) letta_identities_archival_insert "$1" "$2" | jq . ;;
      message)        letta_identities_send_message "$1" "$2" | jq . ;;
      *)  error "Unknown identity command: $COMMAND"; print_help; exit 1 ;;
    esac
    ;;

  # ---- folder / MemFS ------------------------------------------------------
  folder|folders|fs)
    case "$COMMAND" in
      list)           letta_folders_list | jq . ;;
      get)            letta_folders_get "$1" | jq . ;;
      create)         letta_folders_create "$1" | jq . ;;
      update)         letta_folders_update "$1" "$2" | jq . ;;
      delete)         letta_folders_delete "$1" && info "Folder $1 deleted." ;;
      files)          letta_folders_list_files "$1" | jq . ;;
      upload)         letta_folders_upload_file "$1" "$2" | jq . ;;
      download)       letta_folders_download_file "$1" "$2" "${3:-}" ;;
      delete-file)    letta_folders_delete_file "$1" "$2" && info "File $2 deleted." ;;
      memfs-enable)   letta_folders_enable_memfs "$1" | jq . ;;
      memfs-status)   letta_folders_memfs_status "$1" | jq . ;;
      memfs-backup)   letta_folders_memfs_backup "$1" ;;
      memfs-restore)  letta_folders_memfs_restore "$1" "$2" ;;
      *)  error "Unknown folder command: $COMMAND"; print_help; exit 1 ;;
    esac
    ;;

  # ---- tool ----------------------------------------------------------------
  tool|tools)
    case "$COMMAND" in
      list)           letta_tools_list | jq . ;;
      list-attached)  letta_tools_list_attached "$1" | jq . ;;
      get)            letta_tools_get "$1" | jq . ;;
      search)         letta_tools_search "$1" | jq . ;;
      create)
        SOURCE=$(cat "$3")
        letta_tools_create "$1" "$2" "$SOURCE" | jq .
        ;;
      attach)         letta_tools_attach "$1" "$2" && info "Tool $2 attached to agent $1." ;;
      detach)         letta_tools_detach "$1" "$2" && info "Tool $2 detached from agent $1." ;;
      update)
        SOURCE=$(cat "$2")
        letta_tools_update "$1" "$SOURCE" | jq .
        ;;
      delete)         letta_tools_delete "$1" && info "Tool $1 deleted." ;;
      *)  error "Unknown tool command: $COMMAND"; print_help; exit 1 ;;
    esac
    ;;

  # ---- secret / env validation ---------------------------------------------
  secret|secrets|env)
    case "$COMMAND" in
      list)              letta_secrets_list_env ;;
      check)             letta_secrets_check_env "$1" ;;
      validate-letta)    letta_secrets_validate_letta_key && letta_secrets_test_letta ;;
      validate-openrouter) letta_secrets_validate_openrouter_key && letta_secrets_test_openrouter ;;
      validate-db)       letta_secrets_check_db_connectivity ;;
      validate-all)      letta_secrets_validate_all ;;
      *)  error "Unknown secret command: $COMMAND"; print_help; exit 1 ;;
    esac
    ;;

  # ---- help ----------------------------------------------------------------
  help|--help|-h|"")
    print_help
    ;;

  *)
    error "Unknown module: $MODULE"
    print_help
    exit 1
    ;;
esac

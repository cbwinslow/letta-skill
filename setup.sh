#!/usr/bin/env bash
# =============================================================================
# setup.sh — One-time setup for letta-skill
# Usage: ./setup.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${GREEN}[setup]${NC} $*"; }
warn()  { echo -e "${YELLOW}[warn]${NC}  $*"; }
error() { echo -e "${RED}[error]${NC} $*" >&2; }

# --------------------------------------------------------------------------
# 1. Check system dependencies
# --------------------------------------------------------------------------
info "Checking system dependencies..."
MISSING=()
for cmd in curl jq bash; do
  command -v "$cmd" &>/dev/null || MISSING+=("$cmd")
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
  error "Missing required dependencies: ${MISSING[*]}"
  echo "  Install with: sudo apt-get install -y ${MISSING[*]}"
  exit 1
fi
info "Dependencies OK (curl, jq, bash)"

# --------------------------------------------------------------------------
# 2. Create .env from .env.example if it doesn't exist
# --------------------------------------------------------------------------
if [[ ! -f "$SCRIPT_DIR/.env" ]]; then
  if [[ -f "$SCRIPT_DIR/.env.example" ]]; then
    cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"
    warn ".env not found — created from .env.example"
    warn "Please edit .env and add your credentials, then re-run setup.sh"
    echo ""
    echo "  Minimum required variables:"
    echo "    LETTA_BASE_URL     — URL to your Letta server (default: http://localhost:8283)"
    echo "    LETTA_API_KEY      — Your Letta server API key"
    echo "    OPENROUTER_API_KEY — (optional) If using OpenRouter models"
    echo ""
    exit 0
  else
    error ".env.example not found. Are you in the letta-skill directory?"
    exit 1
  fi
else
  info ".env already exists — skipping creation"
fi

# --------------------------------------------------------------------------
# 3. Validate .env has required keys set
# --------------------------------------------------------------------------
info "Validating .env configuration..."
source "$SCRIPT_DIR/.env" 2>/dev/null || true

REQUIRED_VARS=(LETTA_BASE_URL LETTA_API_KEY)
ENV_ERRORS=()
for var in "${REQUIRED_VARS[@]}"; do
  val="${!var:-}"
  if [[ -z "$val" || "$val" == *'${'* ]]; then
    ENV_ERRORS+=("$var is not set or still contains a placeholder")
  fi
done

if [[ ${#ENV_ERRORS[@]} -gt 0 ]]; then
  error "The following .env variables need to be configured:"
  for e in "${ENV_ERRORS[@]}"; do
    echo "    ✗ $e"
  done
  echo ""
  echo "  Edit .env and fill in real values, then re-run setup.sh"
  exit 1
fi
info ".env validation passed"

# --------------------------------------------------------------------------
# 4. Make all scripts executable
# --------------------------------------------------------------------------
info "Setting script permissions..."
chmod +x "$SCRIPT_DIR/run.sh" 2>/dev/null || true
find "$SCRIPT_DIR/scripts" -name "*.sh" -exec chmod +x {} \;
find "$SCRIPT_DIR/workflows" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
info "Permissions set"

# --------------------------------------------------------------------------
# 5. Source helper scripts and run health check
# --------------------------------------------------------------------------
info "Loading helper scripts and validating server connectivity..."
for f in "$SCRIPT_DIR/scripts/letta_"*.sh; do
  # shellcheck disable=SC1090
  source "$f"
done

# Test connectivity
if letta_secrets_validate_all; then
  info "All checks passed — letta-skill is ready!"
  echo ""
  echo "  Run skills with:  ./run.sh <command> [args]"
  echo "  List commands:    ./run.sh help"
else
  warn "Some checks failed. Review the errors above."
  warn "You can still use letta-skill but some features may not work."
fi

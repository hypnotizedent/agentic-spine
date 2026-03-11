#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# launch-agent.sh - Context-injecting agent launcher
# ═══════════════════════════════════════════════════════════════
#
# Usage: launch-agent.sh claude|opencode|codex
#
# What it does:
# 1. Generates fresh context from docs/reference/brain/
# 2. Prints context to terminal
# 3. Launches agent
#
# Called by: Hammerspoon Ctrl+0/2/3
# ═══════════════════════════════════════════════════════════════

set -eo pipefail

REPO="${SPINE_REPO:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
BRAIN="$REPO/docs/reference/brain"
AGENT="${1:-claude}"

source "$REPO/ops/lib/runtime-paths.sh"
spine_runtime_resolve_paths
CONTEXT_FILE="${SPINE_AGENT_CONTEXT_FILE:-$SPINE_RUNTIME_ROOT/context/agent-context.md}"

# Validate agent
case "$AGENT" in
  claude|opencode|codex) ;;
  *)
    echo "Usage: launch-agent.sh claude|opencode|codex"
    exit 1
    ;;
esac

# ─────────────────────────────────────────────────────────────────
# 1. Generate fresh context
# ─────────────────────────────────────────────────────────────────
if [[ -x "$BRAIN/generate-context.sh" ]]; then
  "$BRAIN/generate-context.sh" 2>/dev/null || true
fi

# ─────────────────────────────────────────────────────────────────
# 2. Set environment
# ─────────────────────────────────────────────────────────────────
export SPINE_REPO="$REPO"
export RONNY_OPS_SESSION_START="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
export RONNY_OPS_AGENT="$AGENT"

# ─────────────────────────────────────────────────────────────────
# 3. Change to repo
# ─────────────────────────────────────────────────────────────────
cd "$REPO"
source ~/.zshrc 2>/dev/null || true

# ─────────────────────────────────────────────────────────────────
# 4. Print context
# ─────────────────────────────────────────────────────────────────
echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  CONTEXT LOADED                                           ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

if [[ -f "$CONTEXT_FILE" ]]; then
  cat "$CONTEXT_FILE"
else
  # Fallback: just print rules
  cat "$BRAIN/rules.md" 2>/dev/null || echo "No context found. Run docs/reference/brain/generate-context.sh"
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo ""

# ─────────────────────────────────────────────────────────────────
# 5. Launch agent
# ─────────────────────────────────────────────────────────────────
case "$AGENT" in
  claude)
    claude
    ;;
  opencode)
    opencode
    ;;
  codex)
    codex --sandbox danger-full-access -a never
    ;;
esac

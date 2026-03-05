#!/usr/bin/env bash
# TRIAGE: Ensure AGENTS.md points to spine governance, not external sources.
set -euo pipefail

# D32: Codex Instruction Source Lock
# Ensures Codex global AGENTS source is spine-native.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CODEX_AGENTS="$HOME/.codex/AGENTS.md"
# Canonical spine runtime is fixed by contract; the D32 check must be worktree-safe.
CANONICAL_SPINE_ROOT="${SPINE_CANONICAL_ROOT:-$HOME/code/agentic-spine}"
SPINE_AGENTS="$CANONICAL_SPINE_ROOT/AGENTS.md"

fail() { echo "D32 FAIL: $*" >&2; exit 1; }

require_tool() {
  command -v "$1" >/dev/null 2>&1 || fail "required tool missing: $1"
}

require_tool rg

[[ -f "$SPINE_AGENTS" ]] || fail "missing spine AGENTS: $SPINE_AGENTS"
[[ -e "$CODEX_AGENTS" ]] || fail "missing codex AGENTS source: $CODEX_AGENTS"

resolve_canonical() {
  # Resolve to canonical path (handles symlinks and case differences on macOS)
  local p="$1"
  if [[ -L "$p" ]]; then
    local t
    t="$(readlink "$p")"
    if [[ "$t" != /* ]]; then
      t="$(cd "$(dirname "$p")" && cd "$(dirname "$t")" && pwd)/$(basename "$t")"
    fi
    # Use realpath for canonical form (handles case)
    realpath "$t" 2>/dev/null || echo "$t"
  else
    realpath "$p" 2>/dev/null || echo "$p"
  fi
}

# Compare using inode to handle macOS case-insensitive filesystem
SOURCE_PATH="$(resolve_canonical "$CODEX_AGENTS")"
CANONICAL_SPINE="$(resolve_canonical "$SPINE_AGENTS")"

# Primary check: inode comparison (filesystem identity)
SOURCE_INODE="$(stat -f %i "$SOURCE_PATH" 2>/dev/null || stat -c %i "$SOURCE_PATH" 2>/dev/null || echo "0")"
SPINE_INODE="$(stat -f %i "$SPINE_AGENTS" 2>/dev/null || stat -c %i "$SPINE_AGENTS" 2>/dev/null || echo "1")"

if [[ "$SOURCE_INODE" != "$SPINE_INODE" ]] && [[ "$SOURCE_PATH" != "$CANONICAL_SPINE" ]]; then
  fail "codex AGENTS source is not spine-native: $SOURCE_PATH (expected: $CANONICAL_SPINE)"
fi

if rg -n --pcre2 "(ronny-ops|00_CLAUDE\.md|NO GITHUB ISSUE = NO WORK)" "$SOURCE_PATH" >/dev/null 2>&1; then
  fail "spine AGENTS still contains legacy directives"
fi

# Parse latest session metadata as advisory context.
LATEST_SESSION="$(find "$HOME/.codex/sessions" -type f -name '*.jsonl' 2>/dev/null | sort | tail -n 1 || true)"
if [[ -n "${LATEST_SESSION:-}" ]] && rg -q '"user_instructions":"# AGENTS.md - ronny-ops Repository Instructions' "$LATEST_SESSION"; then
  echo "D32 WARN: latest recorded session was seeded by legacy AGENTS (pre-cutover)" >&2
fi

echo "D32 PASS: codex instruction source locked to spine"

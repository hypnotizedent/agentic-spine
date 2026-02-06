#!/usr/bin/env bash
set -euo pipefail

# D32: Codex Instruction Source Lock
# Ensures Codex global AGENTS source is spine-native.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CODEX_AGENTS="$HOME/.codex/AGENTS.md"
SPINE_AGENTS="$ROOT/AGENTS.md"

fail() { echo "D32 FAIL: $*" >&2; exit 1; }

require_tool() {
  command -v "$1" >/dev/null 2>&1 || fail "required tool missing: $1"
}

require_tool rg

[[ -f "$SPINE_AGENTS" ]] || fail "missing spine AGENTS: $SPINE_AGENTS"
[[ -e "$CODEX_AGENTS" ]] || fail "missing codex AGENTS source: $CODEX_AGENTS"

resolve_path() {
  local p="$1"
  if [[ -L "$p" ]]; then
    local t
    t="$(readlink "$p")"
    if [[ "$t" != /* ]]; then
      t="$(cd "$(dirname "$p")" && cd "$(dirname "$t")" && pwd)/$(basename "$t")"
    fi
    echo "$t"
  else
    echo "$p"
  fi
}

SOURCE_PATH="$(resolve_path "$CODEX_AGENTS")"
[[ "$SOURCE_PATH" == "$SPINE_AGENTS" ]] || fail "codex AGENTS source is not spine-native: $SOURCE_PATH"

if rg -n --pcre2 "(ronny-ops|00_CLAUDE\.md|NO GITHUB ISSUE = NO WORK)" "$SOURCE_PATH" >/dev/null 2>&1; then
  fail "spine AGENTS still contains legacy directives"
fi

# Parse latest session metadata as advisory context.
LATEST_SESSION="$(find "$HOME/.codex/sessions" -type f -name '*.jsonl' 2>/dev/null | sort | tail -n 1 || true)"
if [[ -n "${LATEST_SESSION:-}" ]] && rg -q '"user_instructions":"# AGENTS.md - ronny-ops Repository Instructions' "$LATEST_SESSION"; then
  echo "D32 WARN: latest recorded session was seeded by legacy AGENTS (pre-cutover)" >&2
fi

echo "D32 PASS: codex instruction source locked to spine"

#!/usr/bin/env bash
# D367: multi-agent-proposal-trailer-lock
# Ensure commit-msg hook enforces Proposal-Id when SPINE_MULTI_AGENT=true.
set -euo pipefail

resolve_root() {
  if [[ -n "${SPINE_ROOT:-}" && -f "${SPINE_ROOT}/ops/capabilities.yaml" ]]; then
    printf '%s\n' "$SPINE_ROOT"
    return 0
  fi
  local detected_root=""
  detected_root="$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || true)"
  if [[ -n "$detected_root" && -f "$detected_root/ops/capabilities.yaml" ]]; then
    printf '%s\n' "$detected_root"
    return 0
  fi
  printf '%s\n' "$HOME/code/agentic-spine"
}

ROOT="$(resolve_root)"
HOOK="$ROOT/.githooks/commit-msg"

fail() {
  echo "D367 FAIL: $*" >&2
  exit 1
}

[[ -f "$HOOK" ]] || fail "missing commit-msg hook: $HOOK"
grep -q 'SPINE_MULTI_AGENT' "$HOOK" || fail "commit-msg hook missing SPINE_MULTI_AGENT guard"
grep -q 'Proposal-Id:' "$HOOK" || fail "commit-msg hook missing Proposal-Id trailer enforcement"

echo "D367 PASS: multi-agent Proposal-Id trailer enforcement present in commit-msg hook"

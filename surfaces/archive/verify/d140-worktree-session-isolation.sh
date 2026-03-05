#!/usr/bin/env bash
# D140: Worktree session isolation enforcement
# TRIAGE: non-main sessions must carry explicit identity + managed worktree placement
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
STATUS_SCRIPT="$ROOT/ops/plugins/ops/bin/worktree-session-status"
CONTRACT="$ROOT/ops/bindings/worktree.session.isolation.yaml"

if [[ ! -f "$CONTRACT" ]]; then
  echo "D140 FAIL: missing contract $CONTRACT" >&2
  exit 1
fi

if [[ ! -x "$STATUS_SCRIPT" ]]; then
  echo "D140 FAIL: missing status capability script $STATUS_SCRIPT" >&2
  exit 1
fi

if out="$($STATUS_SCRIPT --enforce --brief 2>&1)"; then
  echo "D140 PASS: $out"
  exit 0
fi

echo "D140 FAIL: $out" >&2
exit 1

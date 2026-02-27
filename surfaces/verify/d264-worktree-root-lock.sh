#!/usr/bin/env bash
# TRIAGE: Keep worktree lifecycle rooted at ~/.wt with no legacy .worktrees/waves fallback.
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CONTRACT="$ROOT/ops/bindings/worktree.lifecycle.contract.yaml"
WAVE_CONTRACT="$ROOT/ops/bindings/wave.lifecycle.yaml"
ISOLATION_CONTRACT="$ROOT/ops/bindings/worktree.session.isolation.yaml"
WAVE_CMD="$ROOT/ops/commands/wave.sh"

fail() { echo "D264 FAIL: $*" >&2; exit 1; }

command -v yq >/dev/null 2>&1 || fail "required tool missing: yq"
[[ -f "$CONTRACT" ]] || fail "missing contract: $CONTRACT"
[[ -f "$WAVE_CONTRACT" ]] || fail "missing contract: $WAVE_CONTRACT"
[[ -f "$ISOLATION_CONTRACT" ]] || fail "missing contract: $ISOLATION_CONTRACT"
[[ -f "$WAVE_CMD" ]] || fail "missing command: $WAVE_CMD"

root_policy="$(yq e -r '.policy.canonical_worktree_root // ""' "$CONTRACT")"
[[ "$root_policy" == "~/.wt" ]] || fail "canonical_worktree_root must be ~/.wt (got: $root_policy)"

wave_root="$(yq e -r '.workspace.worktree_root // ""' "$WAVE_CONTRACT")"
[[ "$wave_root" == "~/.wt/<repo>/<WAVE_ID>" ]] || fail "wave lifecycle worktree_root must be ~/.wt/<repo>/<WAVE_ID> (got: $wave_root)"

isolation_prefix="$(yq e -r '.policy.managed_worktree_prefix // ""' "$ISOLATION_CONTRACT")"
[[ "$isolation_prefix" == "~/.wt/agentic-spine/" ]] || fail "managed_worktree_prefix must be ~/.wt/agentic-spine/ (got: $isolation_prefix)"

if rg -n "\.worktrees/waves/" "$WAVE_CMD" >/dev/null 2>&1; then
  fail "wave.sh still references legacy .worktrees/waves root"
fi

rg -n "canonical_worktree_root" "$WAVE_CMD" >/dev/null 2>&1 || fail "wave.sh missing canonical_worktree_root contract read"

echo "D264 PASS: canonical worktree root lock enforced"

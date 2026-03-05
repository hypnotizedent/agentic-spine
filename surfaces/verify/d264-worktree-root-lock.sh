#!/usr/bin/env bash
# TRIAGE: Keep worktree lifecycle rooted at /Users/ronnyworks/code/.wt/agentic-spine with no legacy .worktrees/waves fallback.
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CONTRACT="$ROOT/ops/bindings/worktree.lifecycle.contract.yaml"
WAVE_CONTRACT="$ROOT/ops/bindings/wave.lifecycle.yaml"
ISOLATION_CONTRACT="$ROOT/ops/bindings/worktree.session.isolation.yaml"
WAVE_CMD="$ROOT/ops/commands/wave.sh"
CAP_CMD="$ROOT/ops/commands/cap.sh"
SESSION_HOOK="$ROOT/ops/hooks/session-entry-hook.sh"
SESSION_STATUS_CMD="$ROOT/ops/plugins/ops/bin/worktree-session-status"
KICKOFF_CMD="$ROOT/ops/plugins/orchestration/bin/orchestration-wave-kickoff"
REHYDRATE_CMD="$ROOT/ops/plugins/ops/bin/worktree-lifecycle-rehydrate"
ENTRY_CMD="$ROOT/ops/plugins/orchestration/bin/orchestration-terminal-entry"

fail() { echo "D264 FAIL: $*" >&2; exit 1; }

command -v yq >/dev/null 2>&1 || fail "required tool missing: yq"
[[ -f "$CONTRACT" ]] || fail "missing contract: $CONTRACT"
[[ -f "$WAVE_CONTRACT" ]] || fail "missing contract: $WAVE_CONTRACT"
[[ -f "$ISOLATION_CONTRACT" ]] || fail "missing contract: $ISOLATION_CONTRACT"
[[ -f "$WAVE_CMD" ]] || fail "missing command: $WAVE_CMD"
[[ -f "$CAP_CMD" ]] || fail "missing command: $CAP_CMD"
[[ -f "$SESSION_HOOK" ]] || fail "missing command: $SESSION_HOOK"
[[ -f "$SESSION_STATUS_CMD" ]] || fail "missing command: $SESSION_STATUS_CMD"
[[ -f "$KICKOFF_CMD" ]] || fail "missing command: $KICKOFF_CMD"
[[ -f "$REHYDRATE_CMD" ]] || fail "missing command: $REHYDRATE_CMD"
[[ -f "$ENTRY_CMD" ]] || fail "missing command: $ENTRY_CMD"

root_policy="$(yq e -r '.policy.canonical_worktree_root // ""' "$CONTRACT")"
[[ "$root_policy" == "/Users/ronnyworks/code/.wt" ]] || fail "canonical_worktree_root must be /Users/ronnyworks/code/.wt (got: $root_policy)"

wave_root="$(yq e -r '.workspace.worktree_root // ""' "$WAVE_CONTRACT")"
[[ "$wave_root" == "/Users/ronnyworks/code/.wt/agentic-spine/<WAVE_ID>" ]] || fail "wave lifecycle worktree_root must be /Users/ronnyworks/code/.wt/agentic-spine/<WAVE_ID> (got: $wave_root)"

isolation_prefix="$(yq e -r '.policy.managed_worktree_prefix // ""' "$ISOLATION_CONTRACT")"
[[ "$isolation_prefix" == "/Users/ronnyworks/code/.wt/agentic-spine/" ]] || fail "managed_worktree_prefix must be /Users/ronnyworks/code/.wt/agentic-spine/ (got: $isolation_prefix)"

if rg -n "\.worktrees/waves/" "$WAVE_CMD" >/dev/null 2>&1; then
  fail "wave.sh still references legacy .worktrees/waves root"
fi

rg -n "canonical_worktree_root" "$WAVE_CMD" >/dev/null 2>&1 || fail "wave.sh missing canonical_worktree_root contract read"
rg -n "WORKTREE PATH POLICY BLOCK" "$WAVE_CMD" >/dev/null 2>&1 || fail "wave.sh missing hard path policy block text"
rg -n "WORKTREE PATH POLICY BLOCK" "$KICKOFF_CMD" >/dev/null 2>&1 || fail "orchestration-wave-kickoff missing hard path policy block text"
rg -n "WORKTREE PATH POLICY BLOCK" "$REHYDRATE_CMD" >/dev/null 2>&1 || fail "worktree-lifecycle-rehydrate missing hard path policy block text"
rg -n "WORKTREE PATH POLICY BLOCK" "$ENTRY_CMD" >/dev/null 2>&1 || fail "orchestration-terminal-entry missing hard path policy block text"

# Bypass-dependence guard: bypass env usage must require packet ref + friction ref linkage.
rg -n "OPS_WORKTREE_ISOLATION_BYPASS_FRICTION_REF" "$CAP_CMD" >/dev/null 2>&1 || fail "cap.sh missing OPS_WORKTREE_ISOLATION_BYPASS_FRICTION_REF handling"
rg -n "SPINE_ORCH_MUTATION_GUARD_BYPASS_FRICTION_REF" "$CAP_CMD" >/dev/null 2>&1 || fail "cap.sh missing SPINE_ORCH_MUTATION_GUARD_BYPASS_FRICTION_REF handling"
rg -n "missing friction linkage" "$CAP_CMD" >/dev/null 2>&1 || fail "cap.sh must block bypass without friction linkage"
rg -n "packet_ref=.*friction_ref=" "$CAP_CMD" >/dev/null 2>&1 || fail "cap.sh bypass warning must emit packet_ref + friction_ref evidence"

rg -n "WSI_BYPASS_FRICTION_REF_ENV_VAR" "$SESSION_HOOK" >/dev/null 2>&1 || fail "session-entry-hook missing bypass friction env contract binding"
rg -n "missing '.*WSI_BYPASS_FRICTION_REF_ENV_VAR'" "$SESSION_HOOK" >/dev/null 2>&1 || fail "session-entry-hook must block bypass without friction linkage"

rg -n "bypass_friction_ref_env_var" "$SESSION_STATUS_CMD" >/dev/null 2>&1 || fail "worktree-session-status missing bypass friction linkage field"
rg -n "missing '.*bypass_friction_ref_env_var'" "$SESSION_STATUS_CMD" >/dev/null 2>&1 || fail "worktree-session-status must report missing friction linkage on bypass"

echo "D264 PASS: canonical worktree root lock enforced"

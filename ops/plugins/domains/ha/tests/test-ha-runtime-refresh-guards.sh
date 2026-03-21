#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$ROOT}"
source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init
BASELINE_REFRESH="$ROOT/ops/plugins/core/bin/ha-baseline-refresh.sh"
HA_REFRESH="$ROOT/ops/plugins/domains/ha/bin/ha-refresh"
SYNC_AGENT="$ROOT/ops/plugins/domains/ha/bin/ha-sync-agent"
SYNC_CONFIG="$ROOT/ops/bindings/ha.sync.config.yaml"
HA_BASELINE_PLIST="$ROOT/ops/plugins/infra/host/launchd/com.ronny.ha-baseline-refresh.plist"
SNAPSHOT_APPLY="$ROOT/ops/plugins/core/snapshot/bin/snapshot-projection-apply"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

assert_file_contains() {
  local file="$1"
  local needle="$2"
  local label="$3"
  if grep -Fq -- "$needle" "$file"; then
    pass "$label"
  else
    fail "$label (missing: $needle)"
  fi
}

assert_file_not_contains() {
  local file="$1"
  local needle="$2"
  local label="$3"
  if grep -Fq -- "$needle" "$file"; then
    fail "$label (unexpected: $needle)"
  else
    pass "$label"
  fi
}

echo "ha runtime refresh guard tests"
echo "════════════════════════════════════════"

echo ""
echo "── T1: baseline refresh uses managed runtime worktree ──"
assert_file_contains "$BASELINE_REFRESH" 'source "${CONTROL_ROOT}/ops/lib/runtime-managed-worktree.sh"' "baseline refresh sources managed worktree helper"
assert_file_contains "$BASELINE_REFRESH" 'RUNTIME_ROOT="$(spine_runtime_prepare_managed_worktree "$CONTROL_ROOT")"' "baseline refresh resolves runtime worktree"
assert_file_contains "$BASELINE_REFRESH" 'cap run "$cap" -- --check' "baseline refresh runs snapshots in explicit check mode"
assert_file_contains "$BASELINE_REFRESH" 'snapshot.projection.apply or per-capability --apply' "baseline refresh points operators at explicit promotion"
assert_file_not_contains "$BASELINE_REFRESH" 'git push origin main' "baseline refresh no longer pushes main"
assert_file_not_contains "$BASELINE_REFRESH" 'git diff --name-only ops/bindings/ha.*.yaml' "baseline refresh no longer reasons over tracked binding git diffs"

echo ""
echo "── T2: sync agent runs in runtime worktree and defaults to manual promotion ──"
assert_file_contains "$SYNC_AGENT" 'source "$SPINE_CODE/ops/lib/runtime-managed-worktree.sh"' "sync agent sources managed worktree helper"
assert_file_contains "$SYNC_AGENT" 'RUNTIME_ROOT="$(spine_runtime_prepare_managed_worktree "$CONTROL_ROOT")"' "sync agent resolves runtime worktree"
assert_file_contains "$SYNC_AGENT" 'export SPINE_TARGET_REPO="$RUNTIME_ROOT"' "sync agent targets the runtime worktree explicitly"
assert_file_contains "$SYNC_AGENT" 'cap run "$snapshot_cap" -- --check' "sync agent runs snapshots in explicit check mode"
assert_file_contains "$SYNC_AGENT" 'Tracked promotion remains manual via snapshot.projection.apply or per-capability --apply' "sync agent reports manual promotion"
assert_file_not_contains "$SYNC_AGENT" 'git push origin main' "sync agent no longer pushes main"
assert_file_contains "$SYNC_AGENT" 'git push origin "$current_branch"' "sync agent pushes current branch only when explicitly enabled"

echo ""
echo "── T3: snapshot orchestrators stay runtime-first by default ──"
assert_file_contains "$HA_REFRESH" 'cap run "$cap" -- --check' "ha-refresh runs component snapshots in check mode"
assert_file_contains "$HA_REFRESH" 'snapshot.projection.apply or per-capability --apply' "ha-refresh points operators at explicit promotion"
assert_file_contains "$SNAPSHOT_APPLY" '"ha.addons.yaml"' "snapshot apply governs ha.addons tracked promotion"
assert_file_contains "$SNAPSHOT_APPLY" '"ha.ssot.baseline.yaml"' "snapshot apply governs ha.ssot baseline promotion"

echo ""
echo "── T4: shipped defaults keep promotion disabled ──"
assert_file_contains "$SYNC_CONFIG" 'auto_commit: false' "sync config disables auto commit"
assert_file_contains "$SYNC_CONFIG" 'auto_push: false' "sync config disables auto push"

echo ""
echo "── T5: launchd wiring advertises the managed runtime worktree ──"
assert_file_contains "$HA_BASELINE_PLIST" '<key>SPINE_RUNTIME_WORKTREE</key>' "plist exports runtime worktree path"
assert_file_contains "$HA_BASELINE_PLIST" '<key>SPINE_RUNTIME_WORKTREE_BRANCH</key>' "plist exports runtime worktree branch"
assert_file_contains "$HA_BASELINE_PLIST" '<string>runtime/scheduler-projection</string>' "plist pins runtime worktree branch to runtime scheduler lane"
assert_file_contains "$HA_BASELINE_PLIST" '<key>OPS_WORKTREE_IDENTITY</key>' "plist exports runtime worktree identity"

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"

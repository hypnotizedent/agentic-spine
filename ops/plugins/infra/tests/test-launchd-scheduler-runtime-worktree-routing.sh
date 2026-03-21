#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
source "${ROOT}/ops/lib/spine-paths.sh"
spine_paths_init

CONTRACT="${ROOT}/ops/bindings/launchd.runtime.contract.yaml"
HELPER="${ROOT}/ops/lib/runtime-managed-worktree.sh"
HEALTH_CHECK="${ROOT}/ops/plugins/core/bin/launchd-health-check.sh"

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

assert_plist_runtime_env() {
  local plist="$1"
  local label="$2"
  assert_file_contains "$plist" '<key>SPINE_RUNTIME_WORKTREE</key>' "$label exports runtime worktree"
  assert_file_contains "$plist" '<key>SPINE_RUNTIME_WORKTREE_BRANCH</key>' "$label exports runtime worktree branch"
  assert_file_contains "$plist" '<key>OPS_WORKTREE_IDENTITY</key>' "$label exports worktree identity"
}

echo "launchd scheduler runtime worktree routing tests"
echo "════════════════════════════════════════"

echo ""
echo "── T1: helper exposes parent-shell runtime activation ──"
assert_file_contains "$HELPER" 'spine_runtime_activate_managed_worktree()' "managed runtime activation helper exists"
assert_file_contains "$HELPER" 'export SPINE_RUNTIME_ACTIVE_ROOT="$runtime_root"' "helper exports active runtime root"
assert_file_contains "$HELPER" 'export SPINE_TARGET_REPO="$runtime_root"' "helper exports target repo"
assert_file_contains "$HELPER" 'cd "$runtime_root"' "helper changes into runtime worktree"

echo ""
echo "── T2: scheduled mutator wrappers activate runtime worktree ──"
for script in \
  "$ROOT/ops/plugins/core/bin/domain-inventory-refresh-daily.sh" \
  "$ROOT/ops/plugins/core/bin/extension-index-refresh-daily.sh" \
  "$ROOT/ops/plugins/core/bin/freshness-critical-daily.sh" \
  "$ROOT/ops/plugins/core/bin/operator-hygiene-daily.sh" \
  "$ROOT/ops/plugins/core/bin/receipts-archive-reconcile-daily.sh" \
  "$ROOT/ops/plugins/core/bin/spine-daily-briefing.sh" \
  "$ROOT/ops/plugins/core/bin/cc-benefits-refresh-daily.sh" \
  "$ROOT/ops/plugins/core/bin/cc-benefits-reminder-dispatch-daily.sh"
do
  base="$(basename "$script")"
  assert_file_contains "$script" 'spine_runtime_activate_managed_worktree "$CONTROL_ROOT"' "$base activates runtime worktree"
  assert_file_contains "$script" 'RUNTIME_ROOT="${SPINE_RUNTIME_ACTIVE_ROOT}"' "$base records runtime root"
done

echo ""
echo "── T3: launchd contract governs the expanded managed-runtime set ──"
for label in \
  "com.ronny.domain-inventory-refresh-daily" \
  "com.ronny.extension-index-refresh-daily" \
  "com.ronny.freshness-critical-daily" \
  "com.ronny.operator-hygiene-daily" \
  "com.ronny.receipts-archive-reconcile-daily" \
  "com.ronny.spine-daily-briefing" \
  "com.ronny.cc-benefits-refresh-daily" \
  "com.ronny.cc-benefits-reminder-dispatch-daily"
do
  assert_file_contains "$CONTRACT" "    - $label" "$label listed in managed runtime contract"
done

echo ""
echo "── T4: matching launchd templates export runtime-worktree env ──"
assert_plist_runtime_env "$ROOT/ops/plugins/infra/host/launchd/com.ronny.domain-inventory-refresh-daily.plist" "domain-inventory plist"
assert_plist_runtime_env "$ROOT/ops/plugins/infra/host/launchd/com.ronny.extension-index-refresh-daily.plist" "extension-index plist"
assert_plist_runtime_env "$ROOT/ops/plugins/infra/host/launchd/com.ronny.freshness-critical-daily.plist" "freshness-critical plist"
assert_plist_runtime_env "$ROOT/ops/plugins/infra/host/launchd/com.ronny.operator-hygiene-daily.plist" "operator-hygiene plist"
assert_plist_runtime_env "$ROOT/ops/plugins/infra/host/launchd/com.ronny.receipts-archive-reconcile-daily.plist" "receipts-archive plist"
assert_plist_runtime_env "$ROOT/ops/plugins/infra/host/launchd/com.ronny.spine-daily-briefing.plist" "spine-daily-briefing plist"
assert_plist_runtime_env "$ROOT/ops/plugins/infra/host/launchd/com.ronny.cc-benefits-refresh-daily.plist" "cc-benefits-refresh plist"
assert_plist_runtime_env "$ROOT/ops/plugins/infra/host/launchd/com.ronny.cc-benefits-reminder-dispatch-daily.plist" "cc-benefits-reminder plist"

echo ""
echo "── T5: launchd health-check excludes its own previous failure from residue count ──"
assert_file_contains "$HEALTH_CHECK" 'map(select(. != "com.ronny.launchd-health-check"))' "health-check filters self from failed labels"
assert_file_contains "$HEALTH_CHECK" 'scheduler_status=${scheduler_status}' "health-check prints explicit scheduler summary"

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"

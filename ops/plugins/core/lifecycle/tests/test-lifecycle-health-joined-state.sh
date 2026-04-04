#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
BIN="$ROOT/ops/plugins/core/lifecycle/bin/lifecycle-health"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

assert_contains() {
  local file="$1" needle="$2" label="$3"
  if rg -Fq -- "$needle" "$file"; then
    pass "$label"
  else
    fail "$label"
  fi
}

echo "lifecycle health joined-state tests"
echo "═══════════════════════════════════"

TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

STATE="$TMPDIR_BASE/state"
RUNTIME="$TMPDIR_BASE/runtime"
RECEIPTS="$TMPDIR_BASE/receipts"
GAPS_FILE="$TMPDIR_BASE/operational.gaps.yaml"
OUT="$TMPDIR_BASE/out.txt"

mkdir -p \
  "$STATE/loop-scopes" \
  "$STATE/handoffs" \
  "$RUNTIME/waves/WAVE-TEST-20260403-01" \
  "$RECEIPTS/RCAP-20260403-TEST__verify.run__Rhealth123"

cat > "$STATE/loop-scopes/LOOP-TEST-JOINED-20260403.scope.md" <<'EOF'
---
loop_id: LOOP-TEST-JOINED-20260403
created: 2026-04-03
status: active
owner: "@test"
scope: spine
priority: high
objective: Joined-state dashboard fixture.
next_action: keep_readers_aligned
evidence_refs: []
---
EOF

cat > "$STATE/handoffs/HO-TEST-20260403.yaml" <<'EOF'
state: active
loop_id: LOOP-TEST-JOINED-20260403
expires_at_utc: 2026-04-04T00:00:00Z
EOF

cat > "$GAPS_FILE" <<'EOF'
gaps:
  - id: GAP-TEST-LIFECYCLE-20260403
    status: open
    severity: high
    parent_loop: LOOP-TEST-JOINED-20260403
    description: Joined-state dashboard should read this directly.
EOF

cat > "$RUNTIME/waves/WAVE-TEST-20260403-01/state.json" <<'EOF'
{
  "wave_id": "WAVE-TEST-20260403-01",
  "status": "active",
  "lifecycle_state": "active",
  "objective": "Joined-state dashboard fixture.",
  "created_at": "2026-04-03T12:00:00Z",
  "dispatches": [],
  "watcher_checks": [],
  "packet": {
    "loop_id": "LOOP-TEST-JOINED-20260403",
    "current_role": "researcher",
    "next_role": "worker"
  },
  "role_flow": {
    "current_role": "researcher",
    "next_role": "worker"
  },
  "workspace": {
    "enabled": true,
    "repo": "/tmp/fixture-repo",
    "worktree": "/tmp/fixture-worktree",
    "branch": "codex/WAVE-TEST-20260403-01",
    "lifecycle_state": "active"
  }
}
EOF

cat > "$RECEIPTS/RCAP-20260403-TEST__verify.run__Rhealth123/receipt.md" <<'EOF'
# Receipt: CAP-20260403-TEST__verify.run__Rhealth123

| Field | Value |
|-------|-------|
| Capability | `verify.run` |
EOF

cat > "$RECEIPTS/RCAP-20260403-TEST__verify.run__Rhealth123/receipt.exec.json" <<'EOF'
{
  "task_id": "verify.run",
  "status": "done",
  "run_keys": [
    "CAP-20260403-TEST__verify.run__Rhealth123"
  ]
}
EOF

cat > "$RECEIPTS/RCAP-20260403-TEST__verify.run__Rhealth123/output.txt" <<'EOF'
{
  "scope": "fast",
  "wrapper": {
    "total": 5,
    "pass": 5,
    "fail": 0,
    "warn": 0
  },
  "blocking_fail_ids": [],
  "warning_gate_ids": []
}
EOF

env \
  SPINE_STATE="$STATE" \
  SPINE_RUNTIME_ROOT="$RUNTIME" \
  SPINE_RECEIPTS="$RECEIPTS" \
  SPINE_GAPS_FILE="$GAPS_FILE" \
  GAPS_YAML_PATH="$GAPS_FILE" \
  "$BIN" > "$OUT"

assert_contains "$OUT" "SPINE_ENGINE_JOINED_STATE.yaml" "lifecycle-health reports joined-state surface path"
assert_contains "$OUT" "Open gaps: 1" "lifecycle-health reads joined-state gap count"
assert_contains "$OUT" "Count: 1" "lifecycle-health reports joined-state loop/handoff counts"
assert_contains "$OUT" "WAVE-TEST-20260403-01 loop=LOOP-TEST-JOINED-20260403" "lifecycle-health reports active wave from joined state"
assert_contains "$OUT" "Latest fast verify: pass" "lifecycle-health reports joined-state verify summary"

if [[ -f "$STATE/domain-state/spine/SPINE_ENGINE_JOINED_STATE.yaml" ]]; then
  pass "lifecycle-health writes joined-state runtime surface"
else
  fail "lifecycle-health writes joined-state runtime surface"
fi

DEGRADED_STATE="$TMPDIR_BASE/degraded-state"
DEGRADED_RUNTIME="$TMPDIR_BASE/degraded-runtime"
DEGRADED_RECEIPTS="$TMPDIR_BASE/degraded-receipts"
DEGRADED_OUT="$TMPDIR_BASE/degraded-out.txt"
mkdir -p \
  "$DEGRADED_STATE/loop-scopes" \
  "$DEGRADED_RUNTIME/waves" \
  "$DEGRADED_RECEIPTS"

env \
  SPINE_STATE="$DEGRADED_STATE" \
  SPINE_RUNTIME_ROOT="$DEGRADED_RUNTIME" \
  SPINE_RECEIPTS="$DEGRADED_RECEIPTS" \
  GAPS_DB_PATH="$TMPDIR_BASE/degraded.db" \
  GAPS_YAML_PATH="$TMPDIR_BASE/missing.gaps.yaml" \
  "$BIN" > "$DEGRADED_OUT"

assert_contains "$DEGRADED_OUT" "Open gaps: unknown (authority degraded)" "lifecycle-health reports unknown when gap authority is degraded"
assert_contains "$DEGRADED_OUT" "Gap authority: degraded -" "lifecycle-health surfaces the degradation reason"
assert_contains "$DEGRADED_OUT" "Summary: unknown (authority degraded)" "aging advisory degrades to unknown instead of conflicting count"

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"

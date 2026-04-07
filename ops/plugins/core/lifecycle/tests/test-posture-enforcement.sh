#!/usr/bin/env bash
set -euo pipefail

# Test: Execution Posture Contract Enforcement
#
# Validates:
#   1. discover posture allows gap creation (bridge upsert)
#   2. converge posture rejects gap creation (bridge upsert)
#   3. discover posture allows loop creation (bridge upsert)
#   4. converge posture rejects loop creation (bridge upsert)
#   5. converge still allows closing an existing gap
#   6. posture override works with SPINE_POSTURE_OVERRIDE_REASON
#   7. posture-guard.sh rejects growth during converge
#   8. posture-guard.sh allows growth during discover
#   9. non-degraded lane does not silently degrade (converge rejection is loud)
#
# Uses OPS_TEST_MODE=1 to suppress passive friction filing.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
GAPS_BRIDGE="$ROOT/ops/plugins/core/lifecycle/bin/gaps-authority-bridge"
LOOPS_BRIDGE="$ROOT/ops/plugins/core/lifecycle/bin/loops-authority-bridge"
POSTURE_GUARD_LIB="$ROOT/ops/lib/posture-guard.sh"

export OPS_TEST_MODE=1
export SPINE_CAP_RUN_KEY="CAP-TEST-POSTURE-$(date +%s)"
export OPS_TERMINAL_ROLE="SPINE-CONTROL-01"

PASS=0
FAIL=0
TOTAL=0

check() {
  local label="$1"
  local expected_rc="$2"
  shift 2
  TOTAL=$((TOTAL + 1))
  local rc=0
  "$@" >/dev/null 2>/dev/null || rc=$?
  if [[ "$rc" -eq "$expected_rc" ]]; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label (expected rc=$expected_rc, got rc=$rc)"
    FAIL=$((FAIL + 1))
  fi
}

check_stderr_contains() {
  local label="$1"
  local pattern="$2"
  shift 2
  TOTAL=$((TOTAL + 1))
  local stderr_output
  stderr_output="$("$@" 2>&1 >/dev/null || true)"
  if echo "$stderr_output" | grep -q "$pattern"; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label (stderr did not contain '$pattern')"
    echo "    stderr: ${stderr_output:0:200}"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Test: Execution Posture Contract Enforcement ==="
echo ""

# --- Test 1: discover posture allows gap upsert ---
echo "--- Gap bridge posture tests ---"
check "discover allows gap upsert" 0 \
  env SPINE_EXECUTION_POSTURE=discover \
  python3 "$GAPS_BRIDGE" upsert \
    --json '{"id":"GAP-OP-99999","title":"posture-test","severity":"low","status":"open","description":"test"}' \
    --actor "test-posture"

# --- Test 2: converge posture rejects gap upsert ---
check "converge rejects gap upsert" 1 \
  env SPINE_EXECUTION_POSTURE=converge \
  python3 "$GAPS_BRIDGE" upsert \
    --json '{"id":"GAP-OP-99998","title":"posture-test-blocked","severity":"low","status":"open","description":"test"}' \
    --actor "test-posture"

# --- Test 3: converge rejection message is loud and structured ---
check_stderr_contains "converge rejection is loud" "POSTURE BLOCKED" \
  env SPINE_EXECUTION_POSTURE=converge \
  python3 "$GAPS_BRIDGE" upsert \
    --json '{"id":"GAP-OP-99997","title":"test","severity":"low","status":"open","description":"test"}' \
    --actor "test-posture"

# --- Test 4: converge still allows gap close ---
check "converge allows gap close" 0 \
  env SPINE_EXECUTION_POSTURE=converge \
  python3 "$GAPS_BRIDGE" close \
    --id GAP-OP-99999 --status closed --defer-sync \
    --actor "test-posture"

# --- Test 5: converge with override allows gap upsert ---
check "converge with override allows gap upsert" 0 \
  env SPINE_EXECUTION_POSTURE=converge SPINE_POSTURE_OVERRIDE_REASON="test override" \
  python3 "$GAPS_BRIDGE" upsert \
    --json '{"id":"GAP-OP-99996","title":"override-test","severity":"low","status":"open","description":"test"}' \
    --actor "test-posture"

echo ""
echo "--- Loop bridge posture tests ---"

# --- Test 6: discover posture allows loop upsert ---
check "discover allows loop upsert" 0 \
  env SPINE_EXECUTION_POSTURE=discover \
  python3 "$LOOPS_BRIDGE" upsert \
    --json '{"loop_id":"LOOP-POSTURE-TEST-99999","status":"planned","objective":"test"}' \
    --actor "test-posture"

# --- Test 7: converge posture rejects loop upsert ---
check "converge rejects loop upsert" 1 \
  env SPINE_EXECUTION_POSTURE=converge \
  python3 "$LOOPS_BRIDGE" upsert \
    --json '{"loop_id":"LOOP-POSTURE-TEST-99998","status":"planned","objective":"test"}' \
    --actor "test-posture"

# --- Test 8: converge still allows loop close ---
check "converge allows loop close" 0 \
  env SPINE_EXECUTION_POSTURE=converge \
  python3 "$LOOPS_BRIDGE" close \
    --id LOOP-POSTURE-TEST-99999 --status closed \
    --actor "test-posture"

echo ""
echo "--- Shell posture-guard.sh tests ---"

# --- Test 9: shell guard allows growth in discover ---
check "shell guard allows growth in discover" 0 \
  env SPINE_EXECUTION_POSTURE=discover \
  bash -c "source '$POSTURE_GUARD_LIB' && posture_guard_reject_growth 'test-caller'"

# --- Test 10: shell guard rejects growth in converge ---
check "shell guard rejects growth in converge" 1 \
  env SPINE_EXECUTION_POSTURE=converge \
  bash -c "source '$POSTURE_GUARD_LIB' && posture_guard_reject_growth 'test-caller'"

# --- Test 11: shell guard allows growth in converge with override ---
check "shell guard allows growth with override" 0 \
  env SPINE_EXECUTION_POSTURE=converge SPINE_POSTURE_OVERRIDE_REASON="test" \
  bash -c "source '$POSTURE_GUARD_LIB' && posture_guard_reject_growth 'test-caller'"

# --- Test 12: default posture (unset) allows growth ---
check "default posture (unset) allows growth" 0 \
  env -u SPINE_EXECUTION_POSTURE \
  bash -c "source '$POSTURE_GUARD_LIB' && posture_guard_reject_growth 'test-caller'"

echo ""
echo "--- Posture contract file tests ---"

# --- Test 13: posture contract exists ---
TOTAL=$((TOTAL + 1))
if [[ -f "$ROOT/ops/bindings/execution.posture.contract.yaml" ]]; then
  echo "  PASS: posture contract file exists"
  PASS=$((PASS + 1))
else
  echo "  FAIL: posture contract file missing"
  FAIL=$((FAIL + 1))
fi

# --- Test 14: posture vocab wired into admission contract ---
TOTAL=$((TOTAL + 1))
if grep -q "execution.posture.contract.yaml" "$ROOT/ops/bindings/session.admission.contract.yaml" 2>/dev/null; then
  echo "  PASS: posture contract referenced in admission contract"
  PASS=$((PASS + 1))
else
  echo "  FAIL: posture contract not referenced in admission contract"
  FAIL=$((FAIL + 1))
fi

# --- Test 15: posture field in dispatch envelope contract ---
TOTAL=$((TOTAL + 1))
if grep -q "execution_posture" "$ROOT/ops/bindings/dispatch.envelope.contract.yaml" 2>/dev/null; then
  echo "  PASS: execution_posture in dispatch envelope contract"
  PASS=$((PASS + 1))
else
  echo "  FAIL: execution_posture not in dispatch envelope contract"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "=== Results: $PASS/$TOTAL passed, $FAIL failed ==="

# Cleanup test gaps/loops from SQLite (best-effort)
for test_id in GAP-OP-99999 GAP-OP-99998 GAP-OP-99997 GAP-OP-99996; do
  env SPINE_EXECUTION_POSTURE=discover \
    python3 "$GAPS_BRIDGE" close --id "$test_id" --status closed --defer-sync --actor "test-cleanup" 2>/dev/null || true
done
env SPINE_EXECUTION_POSTURE=discover \
  python3 "$LOOPS_BRIDGE" close --id LOOP-POSTURE-TEST-99999 --status closed --actor "test-cleanup" 2>/dev/null || true
env SPINE_EXECUTION_POSTURE=discover \
  python3 "$LOOPS_BRIDGE" close --id LOOP-POSTURE-TEST-99998 --status closed --actor "test-cleanup" 2>/dev/null || true

[[ "$FAIL" -eq 0 ]] || exit 1

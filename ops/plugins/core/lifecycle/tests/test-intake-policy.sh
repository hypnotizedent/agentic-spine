#!/usr/bin/env bash
set -euo pipefail

# Test: Intake Policy — friction observe-by-default + verify allowlist
#
# Validates:
#   1. friction.reconcile without --auto-file marks unmatched items as 'observed'
#   2. friction.reconcile with --auto-file reports auto_file=true in payload
#   3. verify allowlist function rejects unlisted gate (empty allowlist)
#   4. verify allowlist function accepts listed gate
#   5. VERIFY_AUTOFILE_ALL=1 bypasses allowlist
#   6. verify.autofile.allowlist file exists

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
FRICTION_RECONCILE="$ROOT/ops/plugins/core/lifecycle/bin/friction-reconcile"
ALLOWLIST="$ROOT/ops/bindings/verify.autofile.allowlist"

export OPS_TEST_MODE=1

PASS=0
FAIL=0
TOTAL=0

# The allowlist function from verify-response-loop, extracted here because
# the script has top-level execution code and cannot be sourced safely.
GATE_FN='
gate_on_autofile_allowlist() {
  local gate_id="$1"
  [[ "$AUTOFILE_ALL" == "1" ]] && return 0
  [[ -f "$AUTOFILE_ALLOWLIST_FILE" ]] || return 1
  grep -qxF "$gate_id" "$AUTOFILE_ALLOWLIST_FILE" 2>/dev/null
}
'

echo "=== Test: Intake Policy ==="
echo ""

# --- friction.reconcile observe-by-default ---
echo "--- friction.reconcile intake tests ---"

# Create a temp friction queue with one queued item
TMPQUEUE="$(mktemp)"
TMPLOCK="$(mktemp)"
cat > "$TMPQUEUE" <<'JSON'
{"friction_id":"FR-TEST-001","capability":"test.cap","expected":"a","actual":"b","severity":"low","fingerprint":"test001","status":"queued","first_seen_utc":"2026-04-06T00:00:00Z","hit_count":1}
JSON

# Test 1: without --auto-file, item should become 'observed'
TOTAL=$((TOTAL + 1))
result="$(python3 "$FRICTION_RECONCILE" \
  --queue "$TMPQUEUE" --lock-file "$TMPLOCK" \
  --loop-id LOOP-SPINE-POST-V3-HYGIENE-20260403 \
  --json 2>/dev/null || true)"
if echo "$result" | python3 -c "
import json, sys
d = json.load(sys.stdin)
if d.get('observed', 0) > 0 and d.get('filed', 0) == 0:
    sys.exit(0)
sys.exit(1)
" 2>/dev/null; then
  echo "  PASS: without --auto-file, unmatched item is observed (not filed)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: without --auto-file, item should be observed"
  FAIL=$((FAIL + 1))
fi

# Reset queue for next test
cat > "$TMPQUEUE" <<'JSON'
{"friction_id":"FR-TEST-002","capability":"test.cap2","expected":"c","actual":"d","severity":"low","fingerprint":"test002","status":"queued","first_seen_utc":"2026-04-06T00:00:00Z","hit_count":1}
JSON

# Test 2: with --auto-file (dry-run), payload should have auto_file=true
TOTAL=$((TOTAL + 1))
result="$(python3 "$FRICTION_RECONCILE" \
  --queue "$TMPQUEUE" --lock-file "$TMPLOCK" \
  --loop-id LOOP-SPINE-POST-V3-HYGIENE-20260403 \
  --auto-file --dry-run --json 2>/dev/null || true)"
if echo "$result" | python3 -c "
import json, sys
d = json.load(sys.stdin)
if d.get('auto_file') is True:
    sys.exit(0)
sys.exit(1)
" 2>/dev/null; then
  echo "  PASS: with --auto-file (dry-run), auto_file=true in payload"
  PASS=$((PASS + 1))
else
  echo "  FAIL: --auto-file should set auto_file=true in payload"
  FAIL=$((FAIL + 1))
fi

rm -f "$TMPQUEUE" "$TMPLOCK"

echo ""
echo "--- verify allowlist function tests ---"

# Test 3: unlisted gate rejected by empty allowlist
TOTAL=$((TOTAL + 1))
if bash -c "
  $GATE_FN
  AUTOFILE_ALLOWLIST_FILE='$ALLOWLIST'
  AUTOFILE_ALL=0
  gate_on_autofile_allowlist D999
" 2>/dev/null; then
  echo "  FAIL: unlisted gate should be rejected by empty allowlist"
  FAIL=$((FAIL + 1))
else
  echo "  PASS: unlisted gate rejected by empty allowlist"
  PASS=$((PASS + 1))
fi

# Test 4: listed gate accepted by allowlist
TMPAL="$(mktemp)"
echo "D67" > "$TMPAL"
TOTAL=$((TOTAL + 1))
if bash -c "
  $GATE_FN
  AUTOFILE_ALLOWLIST_FILE='$TMPAL'
  AUTOFILE_ALL=0
  gate_on_autofile_allowlist D67
" 2>/dev/null; then
  echo "  PASS: listed gate accepted by allowlist"
  PASS=$((PASS + 1))
else
  echo "  FAIL: listed gate should be accepted"
  FAIL=$((FAIL + 1))
fi
rm -f "$TMPAL"

# Test 5: AUTOFILE_ALL=1 bypasses allowlist
TOTAL=$((TOTAL + 1))
if bash -c "
  $GATE_FN
  AUTOFILE_ALLOWLIST_FILE='$ALLOWLIST'
  AUTOFILE_ALL=1
  gate_on_autofile_allowlist D999
" 2>/dev/null; then
  echo "  PASS: AUTOFILE_ALL=1 bypasses allowlist"
  PASS=$((PASS + 1))
else
  echo "  FAIL: AUTOFILE_ALL=1 should bypass allowlist"
  FAIL=$((FAIL + 1))
fi

# Test 6: allowlist file exists
TOTAL=$((TOTAL + 1))
if [[ -f "$ALLOWLIST" ]]; then
  echo "  PASS: verify.autofile.allowlist exists"
  PASS=$((PASS + 1))
else
  echo "  FAIL: verify.autofile.allowlist missing"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "=== Results: $PASS/$TOTAL passed, $FAIL failed ==="
[[ "$FAIL" -eq 0 ]] || exit 1

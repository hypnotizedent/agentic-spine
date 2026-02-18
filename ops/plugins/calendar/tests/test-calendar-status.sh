#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
GEN="$ROOT/ops/plugins/calendar/bin/calendar-generate"
STATUS="$ROOT/ops/plugins/calendar/bin/calendar-status"
export SPINE_CODE="$ROOT"
export SPINE_REPO="$ROOT"
export SPINE_ROOT="$ROOT"

PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1" >&2; FAIL=$((FAIL + 1)); }

echo "calendar-status tests"
echo "════════════════════════════════════════"

TMP="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP"
}
trap cleanup EXIT

"$GEN" --out-dir "$TMP" >/dev/null

echo ""
echo "T1: status reports OK after generation"
(
  out="$("$STATUS" --out-dir "$TMP" --max-age-minutes 1440 2>&1)"
  echo "$out" | grep -q "binding_valid: true"
  echo "$out" | grep -q "missing_files: 0"
  echo "$out" | grep -q "status: OK"
) && pass "status OK when artifacts are present/fresh" || fail "status OK when artifacts are present/fresh"

echo ""
echo "T2: status reports WARN when artifacts are stale"
(
  python3 - <<PY
import os, time
root = "$TMP"
old = time.time() - (3 * 24 * 60 * 60)
for name in os.listdir(root):
    path = os.path.join(root, name)
    os.utime(path, (old, old))
PY

  set +e
  out="$("$STATUS" --out-dir "$TMP" --max-age-minutes 5 2>&1)"
  rc=$?
  set -e
  [[ $rc -ne 0 ]]
  echo "$out" | grep -q "stale_files:"
  echo "$out" | grep -q "status: WARN"
) && pass "status WARN on stale artifacts" || fail "status WARN on stale artifacts"

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed (of $((PASS + FAIL)))"
exit "$FAIL"

#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
GEN="$ROOT/ops/plugins/calendar/bin/calendar-generate"
export SPINE_CODE="$ROOT"
export SPINE_REPO="$ROOT"
export SPINE_ROOT="$ROOT"

PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1" >&2; FAIL=$((FAIL + 1)); }

echo "calendar-generate tests"
echo "════════════════════════════════════════"

TMP1="$(mktemp -d)"
TMP2="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP1" "$TMP2"
}
trap cleanup EXIT

echo ""
echo "T1: generator emits merged + per-layer ICS artifacts"
(
  if ! "$GEN" --out-dir "$TMP1" >/tmp/calendar-generate-test.out; then
    exit 1
  fi
  [[ -f "$TMP1/calendar-global.ics" ]]
  for layer in infrastructure automation identity personal spine life; do
    [[ -f "$TMP1/calendar-${layer}.ics" ]]
  done
  [[ -f "$TMP1/calendar-index.json" ]]
) && pass "artifacts generated" || fail "artifacts generated"

echo ""
echo "T2: deterministic output contract (same binding => same merged hash)"
(
  if ! "$GEN" --out-dir "$TMP1" >/dev/null; then
    exit 1
  fi
  if ! "$GEN" --out-dir "$TMP2" >/dev/null; then
    exit 1
  fi
  [[ -f "$TMP1/calendar-global.ics" ]]
  [[ -f "$TMP2/calendar-global.ics" ]]
  h1="$(shasum -a 256 "$TMP1/calendar-global.ics" 2>/dev/null | awk '{print $1}')"
  h2="$(shasum -a 256 "$TMP2/calendar-global.ics" 2>/dev/null | awk '{print $1}')"
  [[ -n "$h1" && -n "$h2" ]]
  [[ "$h1" == "$h2" ]]
) && pass "deterministic merged ICS hash" || fail "deterministic merged ICS hash"

echo ""
echo "T3: merged ICS contains deterministic DTSTAMP and layer markers"
(
  grep -q "DTSTAMP:20260217T000000Z" "$TMP1/calendar-global.ics"
  grep -q "X-SPINE-LAYER:infrastructure" "$TMP1/calendar-global.ics"
  grep -q "X-SPINE-LAYER:identity" "$TMP1/calendar-global.ics"
) && pass "DTSTAMP + layer markers present" || fail "DTSTAMP + layer markers present"

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed (of $((PASS + FAIL)))"
exit "$FAIL"

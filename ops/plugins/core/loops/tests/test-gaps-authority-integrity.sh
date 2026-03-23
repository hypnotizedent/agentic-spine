#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
BRIDGE="$ROOT/ops/plugins/core/lifecycle/bin/gaps-authority-bridge"
STATUS_BIN="$ROOT/ops/plugins/core/loops/bin/gaps-status"

PASS=0
FAIL=0
TOTAL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1" >&2; FAIL=$((FAIL + 1)); }

TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

STATE="$TEST_DIR/state"
SCOPES="$STATE/loop-scopes"
mkdir -p "$SCOPES"

export SPINE_ROOT="$ROOT"
export SPINE_STATE="$STATE"
export GAPS_DB_PATH="$STATE/shared_authority.db"
export GAPS_YAML_PATH="$TEST_DIR/operational.gaps.yaml"

cat > "$GAPS_YAML_PATH" <<'YAML'
version: 1
updated: "2026-03-23T00:00:00Z"
gaps:
  - id: GAP-OP-9990
    title: Test open gap
    discovered_by: test
    discovered_at: '2026-03-23'
    type: missing-entry
    classification: missing-entry
    doc: test
    description: Test open gap
    severity: low
    status: open
    notes: created for integrity test
    parent_loop: LOOP-TEST-GAPS-AUTHORITY-INTEGRITY
  - id: GAP-OP-9991
    title: Test close gap
    discovered_by: test
    discovered_at: '2026-03-23'
    type: missing-entry
    classification: missing-entry
    doc: test
    description: Test gap that should close through authority
    severity: low
    status: open
    notes: created for integrity test
    parent_loop: LOOP-TEST-GAPS-AUTHORITY-INTEGRITY
YAML

cat > "$SCOPES/LOOP-TEST-GAPS-AUTHORITY-INTEGRITY.scope.md" <<'MD'
---
loop_id: LOOP-TEST-GAPS-AUTHORITY-INTEGRITY
created: 2026-03-23
status: active
owner: "@test"
scope: test
priority: low
---
MD

echo "== gaps authority integrity =="

python3 "$BRIDGE" bootstrap >/dev/null

TOTAL=$((TOTAL + 1))
BEFORE_STATUS="$("$STATUS_BIN")"
if echo "$BEFORE_STATUS" | grep -q "Gaps: 2 total | 2 open | 0 fixed | 0 closed"; then
  pass "gaps.status reads SQLite authority bootstrap state"
else
  fail "gaps.status did not report expected pre-close counts"
fi

SPINE_CAP_RUN_KEY="CAP-TEST-GAPS-CLOSE-R1" python3 "$BRIDGE" close \
  --id GAP-OP-9991 \
  --status fixed \
  --fixed-in TEST-SHA \
  --notes "authority integrity test" \
  --regression-lock-id test-gaps-authority-integrity.sh >/dev/null

TOTAL=$((TOTAL + 1))
DB_ROW="$(sqlite3 "$GAPS_DB_PATH" "select status || '|' || ifnull(fixed_in,'') from gaps where gap_id='GAP-OP-9991';")"
if [[ "$DB_ROW" == "fixed|TEST-SHA" ]]; then
  pass "SQLite truth changes on close"
else
  fail "SQLite truth did not change on close (got '$DB_ROW')"
fi

TOTAL=$((TOTAL + 1))
MID_PARITY="$(python3 "$BRIDGE" parity)"
if echo "$MID_PARITY" | grep -q '"match": false'; then
  pass "parity reports YAML stale before projection"
else
  fail "parity should report stale projection before project"
fi

TOTAL=$((TOTAL + 1))
AFTER_STATUS="$("$STATUS_BIN")"
if echo "$AFTER_STATUS" | grep -q "Gaps: 2 total | 1 open | 1 fixed | 0 closed" && \
   ! echo "$AFTER_STATUS" | grep -q "GAP-OP-9991"; then
  pass "gaps.status sees authority close immediately"
else
  fail "gaps.status did not reflect authority close immediately"
fi

python3 "$BRIDGE" project >/dev/null

TOTAL=$((TOTAL + 1))
PROJECTED_STATUS="$(python3 - <<'PY'
import yaml, os
with open(os.environ["GAPS_YAML_PATH"], "r", encoding="utf-8") as fh:
    doc = yaml.safe_load(fh)
for gap in doc["gaps"]:
    if gap["id"] == "GAP-OP-9991":
        print(f'{gap["status"]}|{gap.get("fixed_in","")}')
        break
PY
)"
if [[ "$PROJECTED_STATUS" == "fixed|TEST-SHA" ]]; then
  pass "YAML projection matches authority after project"
else
  fail "YAML projection did not match authority after project (got '$PROJECTED_STATUS')"
fi

TOTAL=$((TOTAL + 1))
FINAL_PARITY="$(python3 "$BRIDGE" parity)"
if echo "$FINAL_PARITY" | grep -q '"match": true'; then
  pass "parity reports projection aligned after project"
else
  fail "parity should match after projection"
fi

echo ""
echo "== Results: $PASS/$TOTAL passed, $FAIL failed =="

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi

#!/usr/bin/env bash
set -euo pipefail

# Test: gaps-authority-bridge mutation ceremony enforcement
#
# Validates:
#   1. Mutating commands (upsert, close, reparent) are BLOCKED without SPINE_CAP_RUN_KEY
#   2. Mutating commands PASS with SPINE_CAP_RUN_KEY set
#   3. Override mechanism works with --ungoverned-override + --reason
#   4. Override without --reason is BLOCKED
#   5. Read commands (query, project, parity) are always allowed
#   6. Audit fields (run_key, mutation_source) are recorded in gap_events

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
BRIDGE="$ROOT/ops/plugins/core/lifecycle/bin/gaps-authority-bridge"

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
  local stderr_out
  stderr_out="$("$@" 2>&1 >/dev/null || true)"
  if echo "$stderr_out" | grep -q "$pattern"; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label (pattern '$pattern' not found in stderr)"
    FAIL=$((FAIL + 1))
  fi
}

# Set up isolated test environment
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

export GAPS_DB_PATH="$TEST_DIR/test_authority.db"
export GAPS_YAML_PATH="$TEST_DIR/test_gaps.yaml"
export SPINE_ROOT="$ROOT"

# Create a minimal gaps YAML for bootstrap
cat > "$GAPS_YAML_PATH" <<'YAML'
version: 1
updated: "2026-03-23T00:00:00Z"
gaps:
  - id: GAP-OP-9990
    type: agent-behavior
    severity: low
    status: open
    description: "Test gap for ceremony validation"
    discovered_by: test-harness
    discovered_at: "2026-03-23"
    parent_loop: LOOP-TEST-CEREMONY
  - id: GAP-OP-9991
    type: agent-behavior
    severity: low
    status: open
    description: "Test gap for close ceremony"
    discovered_by: test-harness
    discovered_at: "2026-03-23"
    parent_loop: LOOP-TEST-CEREMONY
YAML

echo "== gaps-authority-bridge mutation ceremony tests =="
echo ""

# ── Test 1: Read commands always pass (no SPINE_CAP_RUN_KEY) ──
echo "-- Read commands (ungoverned) --"
unset SPINE_CAP_RUN_KEY 2>/dev/null || true

check "query without SPINE_CAP_RUN_KEY succeeds" 0 \
  python3 "$BRIDGE" query --id GAP-OP-9990

check "project without SPINE_CAP_RUN_KEY succeeds" 0 \
  python3 "$BRIDGE" project

check "parity without SPINE_CAP_RUN_KEY succeeds" 0 \
  python3 "$BRIDGE" parity

check "next-id without SPINE_CAP_RUN_KEY succeeds" 0 \
  python3 "$BRIDGE" next-id

check "bootstrap without SPINE_CAP_RUN_KEY succeeds" 0 \
  python3 "$BRIDGE" bootstrap

echo ""

# ── Test 2: Mutating commands blocked without SPINE_CAP_RUN_KEY ──
echo "-- Mutating commands blocked (ungoverned) --"
unset SPINE_CAP_RUN_KEY 2>/dev/null || true

check "upsert BLOCKED without SPINE_CAP_RUN_KEY" 1 \
  python3 "$BRIDGE" upsert --json '{"id":"GAP-OP-9999","status":"open","severity":"low"}'

check_stderr_contains "upsert prints MUTATION BLOCKED" "MUTATION BLOCKED" \
  python3 "$BRIDGE" upsert --json '{"id":"GAP-OP-9999","status":"open","severity":"low"}'

check "close BLOCKED without SPINE_CAP_RUN_KEY" 1 \
  python3 "$BRIDGE" close --id GAP-OP-9991 --status fixed

check_stderr_contains "close prints MUTATION BLOCKED" "MUTATION BLOCKED" \
  python3 "$BRIDGE" close --id GAP-OP-9991 --status fixed

check "reparent BLOCKED without SPINE_CAP_RUN_KEY" 1 \
  python3 "$BRIDGE" reparent --id GAP-OP-9990 --parent-loop LOOP-NEW

echo ""

# ── Test 3: Mutating commands pass with SPINE_CAP_RUN_KEY ──
echo "-- Mutating commands governed --"
export SPINE_CAP_RUN_KEY="CAP-20260323T120000Z__gaps.file__Rtest"

check "upsert succeeds with SPINE_CAP_RUN_KEY" 0 \
  python3 "$BRIDGE" upsert --json '{"id":"GAP-OP-9992","status":"open","severity":"low","type":"agent-behavior","description":"governed test","discovered_by":"test","parent_loop":"LOOP-TEST"}'

check_stderr_contains "upsert logs governed ceremony" "mutation-ceremony: governed" \
  python3 "$BRIDGE" upsert --json '{"id":"GAP-OP-9993","status":"open","severity":"low","type":"agent-behavior","description":"governed test 2","discovered_by":"test","parent_loop":"LOOP-TEST"}'

check "close succeeds with SPINE_CAP_RUN_KEY" 0 \
  python3 "$BRIDGE" close --id GAP-OP-9991 --status fixed

check "reparent succeeds with SPINE_CAP_RUN_KEY" 0 \
  python3 "$BRIDGE" reparent --id GAP-OP-9990 --parent-loop LOOP-REPARENTED

echo ""

# ── Test 4: Override mechanism ──
echo "-- Override mechanism --"
unset SPINE_CAP_RUN_KEY 2>/dev/null || true

check "override with --reason succeeds" 0 \
  python3 "$BRIDGE" upsert --json '{"id":"GAP-OP-9994","status":"open","severity":"low","type":"agent-behavior","description":"override test","discovered_by":"test","parent_loop":"LOOP-TEST"}' \
    --ungoverned-override --reason "emergency bootstrap test"

check_stderr_contains "override logs ceremony override" "mutation-ceremony: override" \
  python3 "$BRIDGE" upsert --json '{"id":"GAP-OP-9995","status":"open","severity":"low","type":"agent-behavior","description":"override test 2","discovered_by":"test","parent_loop":"LOOP-TEST"}' \
    --ungoverned-override --reason "emergency test"

check "override WITHOUT --reason is blocked" 1 \
  python3 "$BRIDGE" upsert --json '{"id":"GAP-OP-9996","status":"open","severity":"low"}' \
    --ungoverned-override

echo ""

# ── Test 5: Audit fields in gap_events ──
echo "-- Audit fields --"

# Query the SQLite DB directly to check audit columns
AUDIT_CHECK="$(python3 -c "
import sqlite3, json
conn = sqlite3.connect('$GAPS_DB_PATH')
conn.row_factory = sqlite3.Row
rows = conn.execute('SELECT gap_id, event_type, run_key, mutation_source FROM gap_events ORDER BY id').fetchall()
for r in rows:
    print(json.dumps({
        'gap_id': r['gap_id'],
        'event_type': r['event_type'],
        'run_key': r['run_key'],
        'mutation_source': r['mutation_source'],
    }))
conn.close()
" 2>/dev/null || echo "QUERY_FAILED")"

TOTAL=$((TOTAL + 1))
if echo "$AUDIT_CHECK" | grep -q '"mutation_source": "governed"'; then
  echo "  PASS: governed mutations recorded with mutation_source=governed"
  PASS=$((PASS + 1))
else
  echo "  FAIL: no governed mutation_source found in gap_events"
  FAIL=$((FAIL + 1))
fi

TOTAL=$((TOTAL + 1))
if echo "$AUDIT_CHECK" | grep -q '"run_key": "CAP-20260323T120000Z__gaps.file__Rtest"'; then
  echo "  PASS: run_key recorded in gap_events"
  PASS=$((PASS + 1))
else
  echo "  FAIL: run_key not found in gap_events"
  FAIL=$((FAIL + 1))
fi

TOTAL=$((TOTAL + 1))
if echo "$AUDIT_CHECK" | grep -q '"mutation_source": "override"'; then
  echo "  PASS: override mutations recorded with mutation_source=override"
  PASS=$((PASS + 1))
else
  echo "  FAIL: no override mutation_source found in gap_events"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "== Results: $PASS/$TOTAL passed, $FAIL failed =="

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi

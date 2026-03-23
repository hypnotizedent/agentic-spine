#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$ROOT}"
source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init
SCRIPT="$ROOT/ops/plugins/core/session/bin/session-execution-lane-closeout"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

assert_eq() {
  local actual="$1" expected="$2" label="$3"
  if [[ "$actual" == "$expected" ]]; then
    pass "$label"
  else
    fail "$label (expected='$expected', got='$actual')"
  fi
}

assert_true() {
  local actual="$1" label="$2"
  if [[ "$actual" == "True" ]]; then
    pass "$label"
  else
    fail "$label"
  fi
}

json_eval() {
  local json_file="$1" expr="$2"
  python3 - "$json_file" "$expr" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
expr = sys.argv[2]
print(eval(expr, {"payload": payload}))
PY
}

yaml_eval() {
  local yaml_file="$1" expr="$2"
  python3 - "$yaml_file" "$expr" <<'PY'
import sys
import yaml

payload = yaml.safe_load(open(sys.argv[1], encoding="utf-8"))
expr = sys.argv[2]
print(eval(expr, {"payload": payload}))
PY
}

echo "session execution lane closeout tests"
echo "════════════════════════════════════════"

TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

STATE="$TMPDIR_BASE/state"
EVIDENCE="$TMPDIR_BASE/evidence"
mkdir -p "$STATE/execution-lanes" "$STATE/plans" "$STATE/loop-scopes" "$EVIDENCE"

cat > "$STATE/plans/index.yaml" <<'EOF'
version: "1.0"
updated_at: "2026-03-23"
plans: []
EOF

cat > "$STATE/execution-lanes/LANE-TEST.yaml" <<'EOF'
lane_id: "LANE-TEST"
type: "fix"
created_at: "2026-03-23T00:00:00Z"
created_by: "@ronny"
branch: "codex/loop-plan-binding-20260322"
worktree_path: "/tmp/fake-lane-worktree"
origin_commit: "deadbeef"
status: "active"
EOF

JSON_OUT="$TMPDIR_BASE/closeout.json"
env -u SPINE_TARGET_REPO -u SPINE_REPO -u SPINE_CODE \
  SPINE_STATE="$STATE" \
  SPINE_EVIDENCE_ROOT="$EVIDENCE" \
  PLANS_DB_PATH="$STATE/shared_authority.db" \
  PLANS_INDEX_PATH="$STATE/plans/index.yaml" \
  PLANS_DIR_PATH="$STATE/plans" \
  "$SCRIPT" \
    --lane-id LANE-TEST \
    --status deferred \
    --reason "Need governed deferred memory." \
    --json > "$JSON_OUT"

TODAY_UTC="$(date -u +%Y%m%d)"
EXPECTED_LOOP_ID="LOOP-PLAN-BINDING-$TODAY_UTC"
LANE_FILE="$STATE/execution-lanes/LANE-TEST.yaml"
RECEIPT_FILE="$(json_eval "$JSON_OUT" "payload['receipt']")"

assert_eq "$(yaml_eval "$LANE_FILE" "payload['deferred_loop_id']")" "$EXPECTED_LOOP_ID" "closeout stores canonical loop id from loops-create result"
assert_true "$(yaml_eval "$LANE_FILE" "payload['deferred_loop_id'].startswith('LOOP-LOOP-') is False")" "closeout no longer persists guessed double-prefix loop id"
assert_true "$(yaml_eval "$LANE_FILE" "payload['deferred_loop_id'].endswith('20260322') is False")" "closeout no longer persists guessed stale-date loop id"
assert_true "$(yaml_eval "$LANE_FILE" "payload['status'] == 'deferred'")" "lane state transitions to deferred"
assert_true "$(test -f "$STATE/loop-scopes/$EXPECTED_LOOP_ID.scope.md" && printf 'True' || printf 'False')" "closeout creates real runtime scope file"
assert_eq "$(yaml_eval "$LANE_FILE" "payload['deferred_plan_id']")" "PLAN-LOOP-PLAN-BINDING-20260322" "closeout preserves deterministic deferred plan id"
assert_eq "$(yaml_eval "$RECEIPT_FILE" "payload['deferred_loop_id']")" "$EXPECTED_LOOP_ID" "receipt carries canonical deferred loop id"
assert_eq "$(
  python3 - "$STATE/shared_authority.db" <<'PY'
import sqlite3
import sys

conn = sqlite3.connect(sys.argv[1])
row = conn.execute("SELECT source_loop_id FROM plans WHERE plan_id = 'PLAN-LOOP-PLAN-BINDING-20260322'").fetchone()
print(row[0] if row else "")
PY
)" "$EXPECTED_LOOP_ID" "deferred plan authority row binds to canonical loop id"

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"

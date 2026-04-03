#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
BRIDGE="$ROOT/ops/plugins/core/lifecycle/bin/loops-authority-bridge"

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

assert_file_exists() {
  local file="$1" label="$2"
  if [[ -f "$file" ]]; then
    pass "$label"
  else
    fail "$label"
  fi
}

assert_not_exists() {
  local file="$1" label="$2"
  if [[ ! -e "$file" ]]; then
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

echo "loops authority archives closed scopes"
echo "════════════════════════════════════"

TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT
STATE="$TMPDIR_BASE/state"
LOOP_ID="LOOP-TEST-PROJECTION-ARCHIVE-20260403"
ACTIVE_SCOPE="$STATE/loop-scopes/${LOOP_ID}.scope.md"
ARCHIVED_SCOPE="$STATE/archive/closed-loop-scopes/${LOOP_ID}.scope.md"

mkdir -p "$STATE/loop-scopes"

cat > "$ACTIVE_SCOPE" <<EOF
---
loop_id: $LOOP_ID
created: 2026-04-03
status: active
owner: "@ronny"
scope: spine
priority: high
horizon: now
execution_readiness: runnable
execution_mode: single_worker
objective: Ensure closed loops project into archive and stay drained from live scope surfaces.
next_action: archive_me
evidence_refs: []
---

# Loop Scope: $LOOP_ID
EOF

CLOSE_JSON="$TMPDIR_BASE/close.json"
env \
  SPINE_STATE="$STATE" \
  SPINE_CAP_RUN_KEY="CAP-20260403-TEST__loops.authority.close__Rarchive01" \
  OPS_TERMINAL_ROLE="SPINE-CONTROL-01" \
  python3 "$BRIDGE" close \
    --id "$LOOP_ID" \
    --status closed \
    --disposition landed \
    --reason "fixture archive projection" > "$CLOSE_JSON"

assert_eq "$(json_eval "$CLOSE_JSON" "payload['ok']")" "True" "bridge close succeeds"
assert_not_exists "$ACTIVE_SCOPE" "closed loop leaves active scope surface"
assert_file_exists "$ARCHIVED_SCOPE" "closed loop projects into archive surface"

PROJECT_JSON="$TMPDIR_BASE/project.json"
env SPINE_STATE="$STATE" python3 "$BRIDGE" project > "$PROJECT_JSON"
assert_eq "$(json_eval "$PROJECT_JSON" "payload['ok']")" "True" "project succeeds after archival close"
assert_not_exists "$ACTIVE_SCOPE" "project does not resurrect archived closed scope"
assert_file_exists "$ARCHIVED_SCOPE" "project preserves archived closed scope"

PARITY_JSON="$TMPDIR_BASE/parity.json"
env SPINE_STATE="$STATE" python3 "$BRIDGE" parity > "$PARITY_JSON"
assert_eq "$(json_eval "$PARITY_JSON" "payload['match']")" "True" "parity includes archived closed scope"
assert_eq "$(json_eval "$PARITY_JSON" "'$LOOP_ID' in payload['in_db_not_fs']")" "False" "archived closed scope is visible to parity"

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"

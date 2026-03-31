#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
BRIDGE="$ROOT/ops/plugins/core/lifecycle/bin/loops-authority-bridge"
LIB_DIR="$ROOT/ops/plugins/core/lifecycle/lib"

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

echo "loops authority bootstrap missing-loop repair"
echo "════════════════════════════════════════════"

TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT
STATE="$TMPDIR_BASE/state"
mkdir -p "$STATE/loop-scopes"

cat > "$STATE/loop-scopes/LOOP-TEST-BOOTSTRAP-REPAIR-20260330.scope.md" <<'EOF'
---
loop_id: LOOP-TEST-BOOTSTRAP-REPAIR-20260330
created: 2026-03-30
status: active
owner: "@ronny"
scope: spine
priority: high
horizon: now
execution_readiness: runnable
execution_mode: orchestrator_subagents
objective: Phase A: ensure bootstrap repairs missing SQLite loops even with unchanged watermark.
next_action: close_me
evidence_refs: []
---

# Loop Scope: LOOP-TEST-BOOTSTRAP-REPAIR-20260330
EOF

python3 - "$STATE" "$LIB_DIR" <<'PY'
import hashlib
import os
import sqlite3
import sys
from pathlib import Path

state = Path(sys.argv[1])
lib_dir = Path(sys.argv[2])
sys.path.insert(0, str(lib_dir))
import loops_sql_authority as lsa

db_path = state / "shared_authority.db"
scopes_dir = state / "loop-scopes"

conn = lsa.connect(db_path)
lsa.ensure_schema(conn)

combined = ""
for sf in sorted(scopes_dir.glob("LOOP-*.scope.md")):
    combined += sf.read_text(encoding="utf-8")
combined_hash = hashlib.sha256(combined.encode("utf-8")).hexdigest()

lsa.update_watermark(conn, "scope_files", combined_hash)
conn.commit()
conn.close()
PY

BOOTSTRAP_JSON="$TMPDIR_BASE/bootstrap.json"
env SPINE_STATE="$STATE" python3 "$BRIDGE" bootstrap > "$BOOTSTRAP_JSON"

assert_eq "$(json_eval "$BOOTSTRAP_JSON" "payload['ok']")" "True" "bootstrap completes"
assert_eq "$(json_eval "$BOOTSTRAP_JSON" "payload['imported']")" "1" "bootstrap repairs missing loop despite unchanged watermark"
assert_eq "$(json_eval "$BOOTSTRAP_JSON" "payload['total']")" "1" "bootstrap results in one loop in authority"

QUERY_JSON="$TMPDIR_BASE/query.json"
env SPINE_STATE="$STATE" python3 "$BRIDGE" query --id LOOP-TEST-BOOTSTRAP-REPAIR-20260330 > "$QUERY_JSON"
assert_eq "$(json_eval "$QUERY_JSON" "payload['exists']")" "True" "query sees repaired loop"
assert_eq "$(json_eval "$QUERY_JSON" "payload['next_action']")" "close_me" "repaired loop retains scope-backed fields"

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"

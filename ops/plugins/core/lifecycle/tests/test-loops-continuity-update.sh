#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
UPDATE="$ROOT/ops/plugins/core/lifecycle/bin/loops-continuity-update"
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

scope_frontmatter_eval() {
  local scope_file="$1" expr="$2"
  python3 - "$scope_file" "$expr" <<'PY'
import sys
import yaml
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
lines = text.splitlines()
payload = {}
if lines and lines[0].strip() == "---":
    end_idx = None
    for idx in range(1, len(lines)):
        if lines[idx].strip() == "---":
            end_idx = idx
            break
    if end_idx is not None:
        payload = yaml.safe_load("\n".join(lines[1:end_idx])) or {}
expr = sys.argv[2]
print(eval(expr, {"payload": payload}))
PY
}

echo "loop continuity update tests"
echo "════════════════════════════"

TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT
STATE="$TMPDIR_BASE/state"
mkdir -p "$STATE/loop-scopes"

cat > "$STATE/loop-scopes/LOOP-TEST-CONTINUITY-20260330.scope.md" <<'EOF'
---
loop_id: LOOP-TEST-CONTINUITY-20260330
created: 2026-03-30
status: active
owner: "@ronny"
scope: spine
priority: high
horizon: now
execution_readiness: runnable
execution_mode: orchestrator_subagents
objective: Preserve continuity on an active loop.
next_action: ""
evidence_refs: []
---

# Loop Scope: LOOP-TEST-CONTINUITY-20260330
EOF

cat > "$STATE/loop-scopes/LOOP-TEST-MALFORMED-20260330.scope.md" <<'EOF'
---
loop_id: LOOP-TEST-MALFORMED-20260330
created: 2026-03-30
status: active
owner: "@ronny"
scope: spine
priority: medium
horizon: now
execution_readiness: runnable
execution_mode: orchestrator_subagents
objective: Secondary loop for bootstrap drift testing.
next_action: ""
evidence_refs: []
---

# Loop Scope: LOOP-TEST-MALFORMED-20260330
EOF

UPDATE_JSON="$TMPDIR_BASE/update.json"
env \
  SPINE_STATE="$STATE" \
  SPINE_CAP_RUN_KEY="CAP-20260330-TEST__loops.continuity.update__Rloop123" \
  OPS_TERMINAL_ROLE="SPINE-CONTROL-01" \
  "$UPDATE" \
    --loop-id LOOP-TEST-CONTINUITY-20260330 \
    --next-action "Resume the proof from loop continuity, not chat memory." \
    --evidence-ref /tmp/continuity-proof.md \
    --json > "$UPDATE_JSON"

assert_eq "$(json_eval "$UPDATE_JSON" "payload['loop_id']")" "LOOP-TEST-CONTINUITY-20260330" "continuity update returns loop id"
assert_eq "$(json_eval "$UPDATE_JSON" "payload['next_action']")" "Resume the proof from loop continuity, not chat memory." "continuity update returns next_action"
assert_eq "$(scope_frontmatter_eval "$STATE/loop-scopes/LOOP-TEST-CONTINUITY-20260330.scope.md" "payload['next_action']")" "Resume the proof from loop continuity, not chat memory." "projected scope stores next_action"
assert_eq "$(scope_frontmatter_eval "$STATE/loop-scopes/LOOP-TEST-CONTINUITY-20260330.scope.md" "'/tmp/continuity-proof.md' in payload['evidence_refs']")" "True" "projected scope stores evidence ref"

printf 'malformed scope payload\n' > "$STATE/loop-scopes/LOOP-TEST-MALFORMED-20260330.scope.md"

BOOTSTRAP_JSON="$TMPDIR_BASE/bootstrap.json"
env SPINE_STATE="$STATE" python3 "$BRIDGE" bootstrap > "$BOOTSTRAP_JSON"
assert_eq "$(json_eval "$BOOTSTRAP_JSON" "payload['ok']")" "True" "bootstrap tolerates malformed unrelated scope file"

QUERY_JSON="$TMPDIR_BASE/query.json"
env SPINE_STATE="$STATE" python3 "$BRIDGE" query --id LOOP-TEST-CONTINUITY-20260330 > "$QUERY_JSON"
assert_eq "$(json_eval "$QUERY_JSON" "payload['next_action']")" "Resume the proof from loop continuity, not chat memory." "bootstrap preserves existing continuity state"
assert_eq "$(json_eval "$QUERY_JSON" "'/tmp/continuity-proof.md' in payload['evidence_refs']")" "True" "bootstrap preserves existing evidence refs"

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"

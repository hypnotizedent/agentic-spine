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

scope_current_state_eval() {
  local scope_file="$1" expr="$2"
  python3 - "$scope_file" "$expr" <<'PY'
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
match = re.search(r"(?ms)^## Current State\s*\n+(?P<section>.*?)(?=^## |\Z)", text)
payload = {}
if match:
    labels = {
        "- Blocker:": "blocker",
        "- Next action:": "next_action",
        "- Time budget:": "time_budget",
        "- Required continuity output:": "required_continuity_output",
    }
    for raw_line in match.group("section").splitlines():
        stripped = raw_line.strip()
        if not stripped:
            continue
        for prefix, key in labels.items():
            if stripped.startswith(prefix):
                payload[key] = stripped[len(prefix):].strip()
                break
expr = sys.argv[2]
print(eval(expr, {"payload": payload}))
PY
}

echo "loop continuity update tests"
echo "════════════════════════════"

TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT
STATE="$TMPDIR_BASE/state"
RUNTIME="$TMPDIR_BASE/runtime"
RECEIPTS="$TMPDIR_BASE/receipts"
GAPS_FILE="$TMPDIR_BASE/operational.gaps.yaml"
mkdir -p "$STATE/loop-scopes"
mkdir -p "$RUNTIME/waves/WAVE-TEST-CONTEXT-20260403" "$RECEIPTS/RCAP-20260403-TEST__verify.run__Rjoin123"

cat > "$GAPS_FILE" <<'EOF'
gaps:
  - id: GAP-TEST-JOINED-20260403
    status: open
    severity: high
    parent_loop: LOOP-TEST-CONTINUITY-20260330
    description: Joined-state continuity should surface this residue.
EOF

cat > "$RUNTIME/waves/WAVE-TEST-CONTEXT-20260403/state.json" <<'EOF'
{
  "wave_id": "WAVE-TEST-CONTEXT-20260403",
  "status": "active",
  "lifecycle_state": "active",
  "objective": "Controller-only continuity fixture.",
  "created_at": "2026-04-03T12:00:00Z",
  "dispatches": [],
  "watcher_checks": [],
  "packet": {
    "loop_id": "LOOP-TEST-CONTINUITY-20260330",
    "current_role": "researcher",
    "next_role": "worker"
  },
  "role_flow": {
    "current_role": "researcher",
    "next_role": "worker"
  },
  "workspace": {
    "enabled": true,
    "repo": "/tmp/fixture-repo",
    "worktree": "/tmp/fixture-worktree",
    "branch": "codex/WAVE-TEST-CONTEXT-20260403",
    "lifecycle_state": "active"
  }
}
EOF

cat > "$RECEIPTS/RCAP-20260403-TEST__verify.run__Rjoin123/receipt.md" <<'EOF'
# Receipt: CAP-20260403-TEST__verify.run__Rjoin123

| Field | Value |
|-------|-------|
| Capability | `verify.run` |
EOF

cat > "$RECEIPTS/RCAP-20260403-TEST__verify.run__Rjoin123/receipt.exec.json" <<'EOF'
{
  "task_id": "verify.run",
  "status": "done",
  "run_keys": [
    "CAP-20260403-TEST__verify.run__Rjoin123"
  ]
}
EOF

cat > "$RECEIPTS/RCAP-20260403-TEST__verify.run__Rjoin123/output.txt" <<'EOF'
{
  "scope": "fast",
  "wrapper": {
    "total": 4,
    "pass": 4,
    "fail": 0,
    "warn": 0
  },
  "blocking_fail_ids": [],
  "warning_gate_ids": []
}
EOF

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

## Objective

Preserve continuity on an active loop.

## Current State

- Blocker: none.
- Next action: `stale_continuity_pointer`
- Time budget: `1 session`
- Required continuity output: `.evidence/spine/reports/finalization/fixture.md`
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
  SPINE_RUNTIME_ROOT="$RUNTIME" \
  SPINE_RECEIPTS="$RECEIPTS" \
  SPINE_GAPS_FILE="$GAPS_FILE" \
  SPINE_CAP_RUN_KEY="CAP-20260330-TEST__loops.continuity.update__Rloop123" \
  OPS_TERMINAL_ROLE="SPINE-CONTROL-01" \
  "$UPDATE" \
    --loop-id LOOP-TEST-CONTINUITY-20260330 \
    --next-action "Resume the proof from loop continuity, not chat memory." \
    --evidence-ref /tmp/continuity-proof.md \
    --json > "$UPDATE_JSON"

assert_eq "$(json_eval "$UPDATE_JSON" "payload['loop_id']")" "LOOP-TEST-CONTINUITY-20260330" "continuity update returns loop id"
assert_eq "$(json_eval "$UPDATE_JSON" "payload['next_action']")" "Resume the proof from loop continuity, not chat memory." "continuity update returns next_action"
assert_eq "$(json_eval "$UPDATE_JSON" "payload['joined_state_summary']['open_gap_count']")" "1" "continuity update includes joined-state open gap count"
assert_eq "$(json_eval "$UPDATE_JSON" "payload['joined_state_summary']['active_wave_count']")" "1" "continuity update includes joined-state active wave count"
assert_eq "$(json_eval "$UPDATE_JSON" "'SPINE_ENGINE_JOINED_STATE.yaml' in payload['joined_state_path']")" "True" "continuity update returns joined-state path"
assert_eq "$(json_eval "$UPDATE_JSON" "any('SPINE_ENGINE_JOINED_STATE.yaml' in ref for ref in payload['evidence_refs'])")" "True" "continuity update appends joined-state evidence"
assert_eq "$(json_eval "$UPDATE_JSON" "any('RCAP-20260403-TEST__verify.run__Rjoin123/receipt.md' in ref for ref in payload['evidence_refs'])")" "True" "continuity update appends joined-state verify evidence"
assert_eq "$(scope_frontmatter_eval "$STATE/loop-scopes/LOOP-TEST-CONTINUITY-20260330.scope.md" "payload['next_action']")" "Resume the proof from loop continuity, not chat memory." "projected scope stores next_action"
assert_eq "$(scope_frontmatter_eval "$STATE/loop-scopes/LOOP-TEST-CONTINUITY-20260330.scope.md" "'/tmp/continuity-proof.md' in payload['evidence_refs']")" "True" "projected scope stores evidence ref"
assert_eq "$(scope_frontmatter_eval "$STATE/loop-scopes/LOOP-TEST-CONTINUITY-20260330.scope.md" "any('SPINE_ENGINE_JOINED_STATE.yaml' in ref for ref in payload['evidence_refs'])")" "True" "projected scope stores joined-state evidence"
assert_eq "$(scope_current_state_eval "$STATE/loop-scopes/LOOP-TEST-CONTINUITY-20260330.scope.md" "payload['next_action']")" '`Resume the proof from loop continuity, not chat memory.`' "projected scope body updates Current State next_action"
assert_eq "$(scope_current_state_eval "$STATE/loop-scopes/LOOP-TEST-CONTINUITY-20260330.scope.md" "payload['time_budget']")" '`1 session`' "projected scope body preserves Current State time budget"
assert_eq "$(scope_current_state_eval "$STATE/loop-scopes/LOOP-TEST-CONTINUITY-20260330.scope.md" "payload['required_continuity_output']")" '`.evidence/spine/reports/finalization/fixture.md`' "projected scope body preserves continuity output"

printf 'malformed scope payload\n' > "$STATE/loop-scopes/LOOP-TEST-MALFORMED-20260330.scope.md"

BOOTSTRAP_JSON="$TMPDIR_BASE/bootstrap.json"
env SPINE_STATE="$STATE" python3 "$BRIDGE" bootstrap > "$BOOTSTRAP_JSON"
assert_eq "$(json_eval "$BOOTSTRAP_JSON" "payload['ok']")" "True" "bootstrap tolerates malformed unrelated scope file"

QUERY_JSON="$TMPDIR_BASE/query.json"
env SPINE_STATE="$STATE" python3 "$BRIDGE" query --id LOOP-TEST-CONTINUITY-20260330 > "$QUERY_JSON"
assert_eq "$(json_eval "$QUERY_JSON" "payload['next_action']")" "Resume the proof from loop continuity, not chat memory." "bootstrap preserves existing continuity state"
assert_eq "$(json_eval "$QUERY_JSON" "'/tmp/continuity-proof.md' in payload['evidence_refs']")" "True" "bootstrap preserves existing evidence refs"

FALLBACK_JSON="$TMPDIR_BASE/fallback.json"
env \
  SPINE_STATE="$STATE" \
  SPINE_RUNTIME_ROOT="$RUNTIME" \
  SPINE_RECEIPTS="$RECEIPTS" \
  SPINE_GAPS_FILE="$GAPS_FILE" \
  SPINE_CAP_RUN_KEY="CAP-20260330-TEST__loops.continuity.update__Rloop456" \
  "$UPDATE" \
    --loop-id LOOP-TEST-CONTINUITY-20260330 \
    --next-action "Fallback controller role still allows governed continuity." \
    --json > "$FALLBACK_JSON"

assert_eq "$(json_eval "$FALLBACK_JSON" "payload['loop_id']")" "LOOP-TEST-CONTINUITY-20260330" "continuity update succeeds with controller-role fallback"
assert_eq "$(json_eval "$FALLBACK_JSON" "payload['next_action']")" "Fallback controller role still allows governed continuity." "controller-role fallback preserves continuity mutation"

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"

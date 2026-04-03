#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
FINALIZE="$ROOT/ops/plugins/core/loops/bin/loop-closeout-finalize"

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

assert_file_contains() {
  local file="$1" needle="$2" label="$3"
  if rg -Fq -- "$needle" "$file"; then
    pass "$label"
  else
    fail "$label"
  fi
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

yq_eval() {
  local file="$1" expr="$2"
  yq e -r "$expr" "$file"
}

echo "loop closeout manifest parity tests"
echo "══════════════════════════════════════"

TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

STATE="$TMPDIR_BASE/state"
RUNTIME="$TMPDIR_BASE/runtime"
LOOP_ID="LOOP-TEST-MANIFEST-PARITY-20260403"
SCOPE_FILE="$STATE/loop-scopes/${LOOP_ID}.scope.md"
MANIFEST_DIR="$STATE/orchestration/$LOOP_ID"
MANIFEST_FILE="$MANIFEST_DIR/manifest.yaml"
RECEIPT_FILE="$TMPDIR_BASE/closeout.md"

mkdir -p "$STATE/loop-scopes" "$MANIFEST_DIR" "$RUNTIME"

cat > "$SCOPE_FILE" <<EOF
---
loop_id: $LOOP_ID
created: 2026-04-03
status: active
owner: "@ronny"
scope: spine
priority: high
horizon: now
execution_readiness: runnable
execution_mode: orchestrator_subagents
objective: Keep scope and orchestration terminal state aligned on closeout.
next_action: start_day6_operator_offload_drill
evidence_refs: []
---

# Loop Scope: $LOOP_ID

## Objective

Keep scope and orchestration terminal state aligned on closeout.

## Current State

- Blocker: none.
- Next action: \`continue_day1_real_work_after_passed_entry_smoke\`
EOF

cat > "$MANIFEST_FILE" <<EOF
loop_id: $LOOP_ID
repo: "$ROOT"
related_repos: []
base_sha: $(git -C "$ROOT" rev-parse HEAD)
apply_owner: "SPINE-CONTROL-01"
status: open
lanes:
  EXECUTION:
    id: EXECUTION
    status: entry-ready
    depends_on: []
    worker: "Test Worker"
    branch: "fixture/execution"
    agent: ""
    route_target: ""
    produces: []
    consumes: []
  AUDIT:
    id: AUDIT
    status: integrated
    depends_on: []
    worker: "Test Auditor"
    branch: "fixture/audit"
    agent: ""
    route_target: ""
    produces: []
    consumes: []
allow: {}
forbid: []
checks: {}
sequence:
  - EXECUTION
  - AUDIT
sequence_mode: strict
created_at: 2026-04-03T00:00:00Z
updated_at: 2026-04-03T00:00:00Z
EOF

if env \
  SPINE_STATE="$STATE" \
  SPINE_RUNTIME_ROOT="$RUNTIME" \
  SPINE_CAP_RUN_KEY="CAP-20260403-TEST__loop.closeout.finalize__Rmanifest01" \
  OPS_TERMINAL_ROLE="SPINE-CONTROL-01" \
  "$FINALIZE" \
    --loop-id "$LOOP_ID" \
    --disposition landed \
    --completion-level loop_complete \
    --lightweight \
    --reason "fixture manifest parity" \
    --no-close-linked-gaps \
    --receipt-path "$RECEIPT_FILE" > "$TMPDIR_BASE/finalize.out"; then
  pass "loop-closeout-finalize closes active loop with manifest parity fixture"
else
  fail "loop-closeout-finalize closes active loop with manifest parity fixture"
fi

assert_eq "$(scope_frontmatter_eval "$SCOPE_FILE" "payload['status']")" "closed" "scope frontmatter moves to closed"
assert_eq "$(scope_current_state_eval "$SCOPE_FILE" "payload['next_action']")" '`start_day6_operator_offload_drill`' "scope body Current State next_action follows authority"
assert_file_contains "$SCOPE_FILE" "Loop is closed (landed, loop_complete)." "scope body states terminal closure"
assert_eq "$(yq_eval "$MANIFEST_FILE" '.status')" "closed" "manifest status moves to closed"
assert_eq "$(yq_eval "$MANIFEST_FILE" '.lanes.EXECUTION.status')" "closed" "non-terminal manifest lane is closed"
assert_eq "$(yq_eval "$MANIFEST_FILE" '.lanes.AUDIT.status')" "integrated" "integrated manifest lane remains integrated"
assert_file_contains "$MANIFEST_DIR/closed.yaml" 'status: closed' "orchestration closed marker is written"
assert_file_contains "$MANIFEST_DIR/closed.yaml" '"EXECUTION"' "orchestration closed marker records missing non-integrated lane"
assert_file_contains "$RECEIPT_FILE" "orchestration_manifest:" "closeout receipt records orchestration manifest path"

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"

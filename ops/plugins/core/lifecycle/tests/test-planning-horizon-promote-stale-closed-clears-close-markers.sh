#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
HORIZON_SET="$ROOT/ops/plugins/core/lifecycle/bin/planning-horizon-set"
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

echo "planning horizon stale-closed promotion clears close markers"
echo "══════════════════════════════════════════════════════════════"

TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT
STATE="$TMPDIR_BASE/state"
mkdir -p "$STATE/loop-scopes"

SCOPE_FILE="$STATE/loop-scopes/LOOP-TEST-STALE-CLOSED-20260401.scope.md"
cat > "$SCOPE_FILE" <<'EOF'
---
loop_id: LOOP-TEST-STALE-CLOSED-20260401
created: '2026-04-01'
status: closed
owner: "@ronny"
scope: spine
priority: high
horizon: later
execution_readiness: blocked
execution_mode: orchestrator_subagents
objective: Reopened proof loops must not keep stale close markers.
next_action: rerun_proof
evidence_refs: []
closed_at: '2026-04-01T20:07:42Z'
disposition: landed
completion_level: slice_complete
---

# Loop Scope: LOOP-TEST-STALE-CLOSED-20260401
EOF

YQ_STUB_DIR="$TMPDIR_BASE/bin"
mkdir -p "$YQ_STUB_DIR"
cat > "$YQ_STUB_DIR/yq" <<EOF
#!/usr/bin/env bash
set -euo pipefail
if [[ "\${*: -1}" == "$ROOT/ops/bindings/operational.gaps.yaml" ]]; then
  echo 1
  exit 0
fi
exec /opt/homebrew/bin/yq "\$@"
EOF
chmod +x "$YQ_STUB_DIR/yq"

env \
  PATH="$YQ_STUB_DIR:$PATH" \
  SPINE_STATE="$STATE" \
  SPINE_CAP_RUN_KEY="CAP-20260401-TEST__planning.horizon.set__Rstale001" \
  OPS_TERMINAL_ROLE="SPINE-CONTROL-01" \
  "$HORIZON_SET" \
    --loop LOOP-TEST-STALE-CLOSED-20260401 \
    --horizon now \
    --readiness runnable \
    --promote-stale-closed > "$TMPDIR_BASE/horizon.out"

assert_eq "$(scope_frontmatter_eval "$SCOPE_FILE" "payload['status']")" "active" "promotion reactivates stale closed loop"
assert_eq "$(scope_frontmatter_eval "$SCOPE_FILE" "'closed_at' in payload")" "False" "promotion clears closed_at from scope frontmatter"
assert_eq "$(scope_frontmatter_eval "$SCOPE_FILE" "'disposition' in payload")" "False" "promotion clears disposition from scope frontmatter"
assert_eq "$(scope_frontmatter_eval "$SCOPE_FILE" "'completion_level' in payload")" "False" "promotion clears completion level from scope frontmatter"

QUERY_JSON="$TMPDIR_BASE/query.json"
env SPINE_STATE="$STATE" python3 "$BRIDGE" query --id LOOP-TEST-STALE-CLOSED-20260401 > "$QUERY_JSON"
assert_eq "$(json_eval "$QUERY_JSON" "payload['status']")" "active" "shared authority sees reopened active status"
assert_eq "$(json_eval "$QUERY_JSON" "'closed_at' in payload")" "False" "shared authority clears closed_at on reopen"
assert_eq "$(json_eval "$QUERY_JSON" "'disposition' in payload")" "False" "shared authority clears disposition on reopen"
assert_eq "$(json_eval "$QUERY_JSON" "'completion_level' in payload")" "False" "shared authority clears completion level on reopen"

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"

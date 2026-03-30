#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
CREATE="$ROOT/ops/plugins/core/handoff/bin/session-handoff-create"
GET="$ROOT/ops/plugins/core/handoff/bin/session-handoff-get"
LIST="$ROOT/ops/plugins/core/handoff/bin/session-handoff-list"
STATUS="$ROOT/ops/plugins/core/handoff/bin/session-handoff-status"
CLOSE="$ROOT/ops/plugins/core/handoff/bin/session-handoff-close"
EXPIRE="$ROOT/ops/plugins/core/handoff/bin/session-handoff-expire"

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

echo "session handoff parked lane tests"
echo "════════════════════════════════════════"

TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT
STATE="$TMPDIR_BASE/state"
mkdir -p "$STATE" "$STATE/loop-scopes"
cat > "$STATE/loop-scopes/LOOP-SPINE-V3-CONVERGENCE-HARDENING-20260323.scope.md" <<'EOF'
---
loop_id: LOOP-SPINE-V3-CONVERGENCE-HARDENING-20260323
created: 2026-03-23
status: active
owner: "@ronny"
scope: spine
priority: high
horizon: now
execution_readiness: runnable
execution_mode: orchestrator_subagents
objective: Preserve parked lane memory durably.
next_action: ""
evidence_refs: []
---

# Loop Scope: LOOP-SPINE-V3-CONVERGENCE-HARDENING-20260323
EOF

CREATE_JSON="$TMPDIR_BASE/create.json"
SPINE_STATE="$STATE" \
SPINE_CAP_RUN_KEY="CAP-20260330-TEST__session.handoff.create__Rhandoff123" \
OPS_TERMINAL_ROLE="SPINE-CONTROL-01" \
"$CREATE" \
  --summary "Park preserved branch memory in mailroom state." \
  --loops LOOP-SPINE-V3-CONVERGENCE-HARDENING-20260323 \
  --kind parked_lane \
  --review-date 2026-03-30 \
  --branch-refs codex/preserve-example \
  --tracking-refs origin/codex/preserve-example \
  --worktree-paths /tmp/preserve-example \
  --preserved-commits deadbeef \
  --file-refs ops/bindings/example.yaml,ops/plugins/example.sh \
  --plan-refs PLAN-PRESERVE-EXAMPLE \
  --loop-next-action "Resume parked lane from governed handoff memory." \
  --loop-evidence-ref /tmp/parked-proof.md \
  --json > "$CREATE_JSON"

HANDOFF_ID="$(json_eval "$CREATE_JSON" "payload['id']")"
HANDOFF_FILE="$(json_eval "$CREATE_JSON" "payload['file']")"

assert_eq "$(json_eval "$CREATE_JSON" "payload['kind']")" "parked_lane" "create emits parked handoff kind"
assert_eq "$(json_eval "$CREATE_JSON" "payload['state']")" "parked" "parked lane starts in parked state"
assert_eq "$(python3 - "$HANDOFF_FILE" <<'PY'
from pathlib import Path
import yaml
import sys
doc = yaml.safe_load(Path(sys.argv[1]).read_text())
print(doc['parking']['review_date'])
PY
)" "2026-03-30" "handoff file stores review date"
assert_eq "$(json_eval "$CREATE_JSON" "payload['continuity']['updates'][0]['loop_id']")" "LOOP-SPINE-V3-CONVERGENCE-HARDENING-20260323" "create reports loop continuity update"
HANDOFF_SCOPE_NEXT_ACTION_OK="$(scope_frontmatter_eval "$STATE/loop-scopes/LOOP-SPINE-V3-CONVERGENCE-HARDENING-20260323.scope.md" "payload['next_action'] == 'Resume parked lane from governed handoff memory.'")"
assert_eq "$HANDOFF_SCOPE_NEXT_ACTION_OK" "True" "parent loop scope stores handoff next_action"
assert_eq "$(scope_frontmatter_eval "$STATE/loop-scopes/LOOP-SPINE-V3-CONVERGENCE-HARDENING-20260323.scope.md" "'/tmp/parked-proof.md' in payload['evidence_refs']")" "True" "parent loop scope stores provided handoff evidence ref"

GET_JSON="$TMPDIR_BASE/get.json"
SPINE_STATE="$STATE" "$GET" --id "$HANDOFF_ID" --json > "$GET_JSON"
assert_eq "$(json_eval "$GET_JSON" "payload['continuity']['next_action']")" "Resume parked lane from governed handoff memory." "handoff.get returns continuity block"

LIST_JSON="$TMPDIR_BASE/list.json"
SPINE_STATE="$STATE" "$LIST" --state parked --json > "$LIST_JSON"
assert_eq "$(json_eval "$LIST_JSON" "len(payload['handoffs'])")" "1" "parked list returns parked record"
assert_eq "$(json_eval "$LIST_JSON" "payload['handoffs'][0]['kind']")" "parked_lane" "parked list exposes kind"

STATUS_JSON="$TMPDIR_BASE/status.json"
SPINE_STATE="$STATE" "$STATUS" --json > "$STATUS_JSON"
assert_eq "$(json_eval "$STATUS_JSON" "payload['parked']")" "1" "status counts parked handoffs separately"

SPINE_STATE="$STATE" "$CLOSE" --id "$HANDOFF_ID" --note "reviewed and resolved" >/dev/null
STATUS_AFTER_CLOSE="$TMPDIR_BASE/status-after-close.json"
SPINE_STATE="$STATE" "$STATUS" --json > "$STATUS_AFTER_CLOSE"
assert_eq "$(json_eval "$STATUS_AFTER_CLOSE" "payload['parked']")" "0" "parked count clears after close"
assert_eq "$(json_eval "$STATUS_AFTER_CLOSE" "payload['closed']")" "1" "closed count increments after close"

CREATE_EXPIRE_JSON="$TMPDIR_BASE/create-expire.json"
SPINE_STATE="$STATE" \
"$CREATE" \
  --summary "Expire parked branch memory once TTL elapses." \
  --loops LOOP-SPINE-V3-CONVERGENCE-HARDENING-20260323 \
  --kind parked_lane \
  --review-date 2026-03-31 \
  --branch-refs codex/preserve-expire \
  --json > "$CREATE_EXPIRE_JSON"

EXPIRE_FILE="$(json_eval "$CREATE_EXPIRE_JSON" "payload['file']")"
python3 - "$EXPIRE_FILE" <<'PY'
from pathlib import Path
import yaml
import sys
path = Path(sys.argv[1])
doc = yaml.safe_load(path.read_text())
doc["expires_at_utc"] = "2000-01-01T00:00:00Z"
path.write_text(yaml.safe_dump(doc, sort_keys=False), encoding="utf-8")
PY

EXPIRE_JSON="$TMPDIR_BASE/expire.json"
SPINE_STATE="$STATE" "$EXPIRE" --json > "$EXPIRE_JSON"
assert_eq "$(json_eval "$EXPIRE_JSON" "payload['expired']")" "1" "expire transitions parked handoffs once TTL passes"

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"

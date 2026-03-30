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

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    pass "$label"
  else
    fail "$label (missing '$needle')"
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

jsonl_eval() {
  local jsonl_file="$1" expr="$2"
  python3 - "$jsonl_file" "$expr" <<'PY'
import json
import sys

rows = []
with open(sys.argv[1], encoding="utf-8") as fh:
    for raw in fh:
        line = raw.strip()
        if not line:
            continue
        rows.append(json.loads(line))
expr = sys.argv[2]
print(eval(expr, {"rows": rows}))
PY
}

write_lane_state() {
  local lane_file="$1"
  local lane_id="$2"
  local lane_type="$3"
  local branch="$4"
  local worktree_path="$5"
  local parent_loop="${6:-}"
  cat > "$lane_file" <<EOF
lane_id: "$lane_id"
type: "$lane_type"
created_at: "2026-03-30T00:00:00Z"
created_by: "@ronny"
branch: "$branch"
worktree_path: "$worktree_path"
origin_commit: "deadbeef"
status: "active"
parent_loop: "${parent_loop}"
EOF
}

make_fake_friction_ingest() {
  local stub_path="$1"
  local log_path="$2"
  cat > "$stub_path" <<'PY'
#!/usr/bin/env python3
from datetime import datetime, timezone
import hashlib
import json
import os
import sys
from pathlib import Path

queue_path = Path(os.environ["SPINE_STATE"]) / "friction-queue.ndjson"
log_path = Path(os.environ["FRICTION_CALL_LOG"])

source = "manual"
auto_reconcile = False
loop_id = ""
want_json = False
items = []

argv = sys.argv[1:]
i = 0
while i < len(argv):
    arg = argv[i]
    if arg == "--item-json":
        items.append(json.loads(argv[i + 1]))
        i += 2
    elif arg == "--input":
        with open(argv[i + 1], encoding="utf-8") as fh:
            for raw in fh:
                line = raw.strip()
                if not line:
                    continue
                items.append(json.loads(line))
        i += 2
    elif arg == "--source":
        source = argv[i + 1]
        i += 2
    elif arg == "--auto-reconcile":
        auto_reconcile = True
        i += 1
    elif arg == "--loop-id":
        loop_id = argv[i + 1]
        i += 2
    elif arg == "--json":
        want_json = True
        i += 1
    else:
        i += 1

if not items:
    print("missing friction input", file=sys.stderr)
    raise SystemExit(1)

def normalize_space(value):
    return " ".join(str(value or "").strip().split())

rows = []
if queue_path.exists():
    for raw in queue_path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw.strip()
        if not line:
            continue
        rows.append(json.loads(line))

created = 0
deduped = 0
call_id = f"CALL-{datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%f')}"
stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
created_index = 0
logged_rows = []

for item in items:
    severity = normalize_space(item.get("severity", "medium")).lower() or "medium"
    if severity not in {"low", "medium", "high", "critical"}:
        severity = "medium"

    canonical = {
        "capability": normalize_space(item.get("capability", "")),
        "expected": normalize_space(item.get("expected", "")),
        "actual": normalize_space(item.get("actual", "")),
        "severity": severity,
        "source": normalize_space(source) or "manual",
    }
    fingerprint = hashlib.sha256(
        json.dumps(canonical, sort_keys=True, separators=(",", ":")).encode("utf-8")
    ).hexdigest()

    match = None
    for row in rows:
        if str(row.get("fingerprint", "")) == fingerprint:
            match = row
            break

    created_item = False
    deduped_item = False
    if match is None:
        created_index += 1
        match = {
            "friction_id": f"FR-STUB-{stamp}-{created_index:04d}",
            "fingerprint": fingerprint,
            "capability": canonical["capability"],
            "expected": canonical["expected"],
            "actual": canonical["actual"],
            "severity": canonical["severity"],
            "status": "queued",
        }
        rows.append(match)
        created += 1
        created_item = True
    else:
        deduped += 1
        deduped_item = True

    logged_rows.append(
        {
            "call_id": call_id,
            "capability": canonical["capability"],
            "source": canonical["source"],
            "loop_id": loop_id,
            "requested_auto_reconcile": auto_reconcile,
            "created": created_item,
            "deduped": deduped_item,
            "friction_id": match["friction_id"],
        }
    )

queue_path.parent.mkdir(parents=True, exist_ok=True)
with open(queue_path, "w", encoding="utf-8") as fh:
    for row in rows:
        fh.write(json.dumps(row, sort_keys=True))
        fh.write("\n")

log_path.parent.mkdir(parents=True, exist_ok=True)
with open(log_path, "a", encoding="utf-8") as fh:
    for row in logged_rows:
        fh.write(json.dumps(row, sort_keys=True))
        fh.write("\n")

payload = {
    "capability": "friction.ingest",
    "status": "ok",
    "authority": "ndjson",
    "queue": str(queue_path),
    "ingested": 1,
    "created": created,
    "deduped": deduped,
    "queue_total": len(rows),
    "auto_reconcile": auto_reconcile,
    "loop_id": loop_id or None,
    "reconcile": {"status": "stubbed", "loop_id": loop_id} if auto_reconcile else None,
}

if want_json:
    print(json.dumps(payload, indent=2))
else:
    print("friction.ingest")
PY
  chmod +x "$stub_path"
}

seed_friction_queue_row() {
  local queue_file="$1"
  local capability="$2"
  local expected="$3"
  local actual="$4"
  local severity="$5"
  local source="$6"
  local friction_id="$7"
  python3 - "$queue_file" "$capability" "$expected" "$actual" "$severity" "$source" "$friction_id" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

queue_file = Path(sys.argv[1])
capability, expected, actual, severity, source, friction_id = sys.argv[2:8]
canonical = {
    "capability": capability,
    "expected": expected,
    "actual": actual,
    "severity": severity,
    "source": source,
}
fingerprint = hashlib.sha256(
    json.dumps(canonical, sort_keys=True, separators=(",", ":")).encode("utf-8")
).hexdigest()
queue_file.parent.mkdir(parents=True, exist_ok=True)
with open(queue_file, "a", encoding="utf-8") as fh:
    fh.write(
        json.dumps(
            {
                "friction_id": friction_id,
                "fingerprint": fingerprint,
                "capability": capability,
                "expected": expected,
                "actual": actual,
                "severity": severity,
                "status": "queued",
            },
            sort_keys=True,
        )
    )
    fh.write("\n")
PY
}

echo "session execution lane closeout friction tests"
echo "════════════════════════════════════════"

TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

echo "── T1: closeout without friction input remains unchanged ──"
T1_STATE="$TMPDIR_BASE/t1-state"
T1_EVIDENCE="$TMPDIR_BASE/t1-evidence"
mkdir -p "$T1_STATE/execution-lanes" "$T1_EVIDENCE"
write_lane_state "$T1_STATE/execution-lanes/LANE-NO-FRICTION.yaml" "LANE-NO-FRICTION" "fix" "codex/no-friction" "/tmp/no-friction-worktree" ""
T1_JSON="$TMPDIR_BASE/t1-closeout.json"
env -u SPINE_TARGET_REPO -u SPINE_REPO -u SPINE_CODE \
  SPINE_STATE="$T1_STATE" \
  SPINE_EVIDENCE_ROOT="$T1_EVIDENCE" \
  "$SCRIPT" \
    --lane-id LANE-NO-FRICTION \
    --status blocked \
    --reason "Need follow-up." \
    --json > "$T1_JSON"
T1_RECEIPT="$(json_eval "$T1_JSON" "payload['receipt']")"
assert_eq "$(json_eval "$T1_JSON" "sorted(payload.keys())")" "['lane_id', 'receipt', 'status']" "closeout without friction input keeps JSON shape"
assert_true "$(yaml_eval "$T1_STATE/execution-lanes/LANE-NO-FRICTION.yaml" "payload['status'] == 'blocked'")" "closeout without friction input still closes lane"
assert_true "$(yaml_eval "$T1_RECEIPT" "payload.get('friction_ingest') is None")" "receipt stays unchanged when friction input is omitted"

echo "── T2: mixed friction input ingests and reconciles correctly ──"
T2_STATE="$TMPDIR_BASE/t2-state"
T2_EVIDENCE="$TMPDIR_BASE/t2-evidence"
mkdir -p "$T2_STATE/execution-lanes" "$T2_EVIDENCE"
write_lane_state "$T2_STATE/execution-lanes/LANE-FRICTION.yaml" "LANE-FRICTION" "fix" "codex/friction-proof" "/tmp/friction-proof-worktree" "LOOP-TEST-FRICTION"
seed_friction_queue_row \
  "$T2_STATE/friction-queue.ndjson" \
  "media.health.check" \
  "media health should pass cleanly" \
  "download-node-exporter still failing" \
  "medium" \
  "media-pass" \
  "FR-STUB-SEEDED-0001"
FRICTION_STUB="$TMPDIR_BASE/fake-friction-ingest.py"
FRICTION_CALL_LOG="$TMPDIR_BASE/fake-friction-calls.jsonl"
make_fake_friction_ingest "$FRICTION_STUB" "$FRICTION_CALL_LOG"
FRICTION_INPUT="$TMPDIR_BASE/friction-input.jsonl"
cat > "$FRICTION_INPUT" <<'EOF'
{"capability":"wave.execute.close","expected":"dispatch lane should be ackable/closable","actual":"dispatch D1 recorded on lane worker but ack rejects worker","severity":"high","auto_reconcile":true,"evidence_ref":"/tmp/media-wave-closeout.md","source":"media-pass"}
{"capability":"media.queue.reconcile.sonarr","expected":"justified apply should complete cleanly","actual":"partial apply removed=7 remove_errors=3","severity":"medium","auto_reconcile":false,"evidence_ref":"/tmp/media-sonarr-apply.md","source":"media-pass"}
{"capability":"media.health.check","expected":"media health should pass cleanly","actual":"download-node-exporter still failing","severity":"medium","auto_reconcile":false,"evidence_ref":"/tmp/media-health.md","source":"media-pass"}
EOF
T2_JSON="$TMPDIR_BASE/t2-closeout.json"
env -u SPINE_TARGET_REPO -u SPINE_REPO -u SPINE_CODE \
  SPINE_STATE="$T2_STATE" \
  SPINE_EVIDENCE_ROOT="$T2_EVIDENCE" \
  SPINE_FRICTION_INGEST_BIN="$FRICTION_STUB" \
  FRICTION_CALL_LOG="$FRICTION_CALL_LOG" \
  "$SCRIPT" \
    --lane-id LANE-FRICTION \
    --status blocked \
    --reason "Proof residue captured." \
    --friction-input "$FRICTION_INPUT" \
    --json > "$T2_JSON"
T2_RECEIPT="$(json_eval "$T2_JSON" "payload['receipt']")"
assert_eq "$(json_eval "$T2_JSON" "payload['friction_ingest']['provided']")" "3" "closeout ingests all provided friction items"
assert_eq "$(json_eval "$T2_JSON" "payload['friction_ingest']['created']")" "2" "closeout reports created friction items"
assert_eq "$(json_eval "$T2_JSON" "payload['friction_ingest']['deduped']")" "1" "closeout reports deduped friction items"
assert_eq "$(json_eval "$T2_JSON" "payload['friction_ingest']['auto_reconcile_items']")" "1" "closeout routes one item through auto-reconcile"
assert_eq "$(json_eval "$T2_JSON" "len(payload['friction_ingest']['friction_ids'])")" "3" "closeout output includes all friction ids"
assert_eq "$(json_eval "$T2_JSON" "payload['friction_ingest']['items'][0]['auto_reconcile']")" "True" "engine residue item requests auto-reconcile"
assert_eq "$(json_eval "$T2_JSON" "payload['friction_ingest']['items'][1]['auto_reconcile']")" "False" "domain residue item stays manual"
assert_eq "$(yaml_eval "$T2_RECEIPT" "payload['friction_ingest']['created']")" "2" "receipt stores created friction count"
assert_eq "$(yaml_eval "$T2_RECEIPT" "len(payload['friction_ingest']['deduped_ids'])")" "1" "receipt stores deduped friction ids"
assert_eq "$(yaml_eval "$T2_RECEIPT" "len(payload['friction_ingest']['auto_reconcile_ids'])")" "1" "receipt stores auto-reconcile friction ids"
assert_eq "$(jsonl_eval "$FRICTION_CALL_LOG" "len(rows)")" "3" "closeout hands all three items to friction ingest"
assert_eq "$(jsonl_eval "$FRICTION_CALL_LOG" "len({row['call_id'] for row in rows})")" "2" "closeout batches compatible friction items into two ingest calls"
assert_eq "$(jsonl_eval "$FRICTION_CALL_LOG" "sum(1 for row in rows if row['requested_auto_reconcile'])")" "1" "exactly one ingest call requests auto-reconcile"
assert_eq "$(jsonl_eval "$FRICTION_CALL_LOG" "next(row['loop_id'] for row in rows if row['capability'] == 'wave.execute.close')")" "LOOP-TEST-FRICTION" "auto-reconcile item reuses lane parent loop"
assert_true "$(jsonl_eval "$FRICTION_CALL_LOG" "next(row['deduped'] for row in rows if row['capability'] == 'media.health.check')")" "preseeded residue dedupes instead of creating a duplicate"

echo "── T3: malformed friction input fails clearly ──"
T3_STATE="$TMPDIR_BASE/t3-state"
T3_EVIDENCE="$TMPDIR_BASE/t3-evidence"
mkdir -p "$T3_STATE/execution-lanes" "$T3_EVIDENCE"
write_lane_state "$T3_STATE/execution-lanes/LANE-BAD-FRICTION.yaml" "LANE-BAD-FRICTION" "fix" "codex/bad-friction" "/tmp/bad-friction-worktree" "LOOP-TEST-FRICTION"
BAD_INPUT="$TMPDIR_BASE/bad-friction.jsonl"
cat > "$BAD_INPUT" <<'EOF'
{"capability":"wave.execute.close","expected":"dispatch lane should be ackable/closable","actual":"dispatch D1 recorded on lane worker but ack rejects worker","severity":"high","auto_reconcile":true}
{"capability":
EOF
BAD_STDERR="$TMPDIR_BASE/bad-friction.stderr"
if env -u SPINE_TARGET_REPO -u SPINE_REPO -u SPINE_CODE \
  SPINE_STATE="$T3_STATE" \
  SPINE_EVIDENCE_ROOT="$T3_EVIDENCE" \
  SPINE_FRICTION_INGEST_BIN="$FRICTION_STUB" \
  FRICTION_CALL_LOG="$FRICTION_CALL_LOG" \
  "$SCRIPT" \
    --lane-id LANE-BAD-FRICTION \
    --status blocked \
    --reason "Should fail." \
    --friction-input "$BAD_INPUT" \
    --json > /dev/null 2> "$BAD_STDERR"; then
  fail "malformed friction input should fail"
else
  assert_contains "$(cat "$BAD_STDERR")" "malformed friction input line 2" "malformed friction input fails clearly"
  assert_true "$(yaml_eval "$T3_STATE/execution-lanes/LANE-BAD-FRICTION.yaml" "payload['status'] == 'active'")" "malformed friction input does not mutate lane state"
fi

echo "── T4: auto-reconcile without parent loop fails truthfully ──"
T4_STATE="$TMPDIR_BASE/t4-state"
T4_EVIDENCE="$TMPDIR_BASE/t4-evidence"
mkdir -p "$T4_STATE/execution-lanes" "$T4_EVIDENCE"
write_lane_state "$T4_STATE/execution-lanes/LANE-NO-LOOP.yaml" "LANE-NO-LOOP" "fix" "codex/no-loop" "/tmp/no-loop-worktree" ""
T4_INPUT="$TMPDIR_BASE/no-loop-friction.jsonl"
cat > "$T4_INPUT" <<'EOF'
{"capability":"wave.execute.close","expected":"dispatch lane should be ackable/closable","actual":"dispatch D1 recorded on lane worker but ack rejects worker","severity":"high","auto_reconcile":true}
EOF
T4_STDERR="$TMPDIR_BASE/no-loop.stderr"
if env -u SPINE_TARGET_REPO -u SPINE_REPO -u SPINE_CODE \
  SPINE_STATE="$T4_STATE" \
  SPINE_EVIDENCE_ROOT="$T4_EVIDENCE" \
  SPINE_FRICTION_INGEST_BIN="$FRICTION_STUB" \
  FRICTION_CALL_LOG="$FRICTION_CALL_LOG" \
  "$SCRIPT" \
    --lane-id LANE-NO-LOOP \
    --status blocked \
    --reason "Should fail." \
    --friction-input "$T4_INPUT" \
    --json > /dev/null 2> "$T4_STDERR"; then
  fail "auto-reconcile without parent loop should fail"
else
  assert_contains "$(cat "$T4_STDERR")" "has no parent_loop" "missing parent loop fails truthfully"
  assert_true "$(yaml_eval "$T4_STATE/execution-lanes/LANE-NO-LOOP.yaml" "payload['status'] == 'active'")" "missing parent loop does not mutate lane state"
fi

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"

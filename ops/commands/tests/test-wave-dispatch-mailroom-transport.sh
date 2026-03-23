#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
WAVE_SCRIPT="$ROOT/ops/commands/wave.sh"
TASK_WORKER="$ROOT/ops/plugins/infra/mailroom-bridge/bin/mailroom-task-worker"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  if grep -Fq -- "$needle" <<<"$haystack"; then
    pass "$label"
  else
    fail "$label (expected: $needle)"
  fi
}

assert_not_exists() {
  local path="$1" label="$2"
  if [[ ! -e "$path" ]]; then
    pass "$label"
  else
    fail "$label (found: $path)"
  fi
}

extract_json() {
  python3 -c 'import json,sys
text=sys.stdin.read()
dec=json.JSONDecoder()
for i,ch in enumerate(text):
    if ch != "{":
        continue
    try:
        obj,_ = dec.raw_decode(text[i:])
    except json.JSONDecodeError:
        continue
    print(json.dumps(obj))
    sys.exit(0)
sys.exit(1)'
}

echo "wave dispatch mailroom transport tests"
echo "════════════════════════════════════════"

command -v yq >/dev/null 2>&1 || { echo "FAIL: yq required" >&2; exit 1; }

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

refs_dir="$tmpdir/refs"
mkdir -p "$refs_dir"
brief_ref="$refs_dir/research-brief.md"
scope_ref="$refs_dir/scope.md"
plan_ref="$refs_dir/execution-plan.md"
accept_ref="$refs_dir/acceptance.md"
printf '%s\n' "# research brief" > "$brief_ref"
printf '%s\n' "# scope" > "$scope_ref"
printf '%s\n' "# execution plan" > "$plan_ref"
printf '%s\n' "# acceptance" > "$accept_ref"

runtime_op="$tmpdir/runtime-operational"
mkdir -p "$runtime_op/state" "$runtime_op/waves/WAVE-DISPATCH-OP"
cat > "$runtime_op/waves/WAVE-DISPATCH-OP/state.json" <<'JSON'
{
  "wave_id": "WAVE-DISPATCH-OP",
  "status": "active",
  "objective": "operational mailroom dispatch",
  "created_at": "2026-03-23T00:00:00Z",
  "dispatches": [],
  "packet": {
    "wave_id": "WAVE-DISPATCH-OP",
    "loop_id": "LOOP-DISPATCH-OP",
    "owner_terminal": "SPINE-CONTROL-01",
    "current_role": "researcher",
    "next_role": "worker",
    "deadline_utc": "2099-01-01T00:00:00Z",
    "horizon": "now",
    "execution_readiness": "runnable",
    "claimed_paths": ["ops/commands/wave.sh"],
    "execution_mode": "operational",
    "transport": "mailroom",
    "stub_matrix": [],
    "lane_outcomes": []
  },
  "wave_packet": {
    "wave_id": "WAVE-DISPATCH-OP",
    "loop_id": "LOOP-DISPATCH-OP",
    "owner_terminal": "SPINE-CONTROL-01",
    "current_role": "researcher",
    "next_role": "worker",
    "deadline_utc": "2099-01-01T00:00:00Z",
    "horizon": "now",
    "execution_readiness": "runnable",
    "claimed_paths": ["ops/commands/wave.sh"],
    "execution_mode": "operational",
    "transport": "mailroom",
    "stub_matrix": [],
    "lane_outcomes": []
  },
  "role_flow": {
    "current_role": "researcher",
    "next_role": "worker"
  },
  "workspace": {}
}
JSON

operational_out="$(
  env \
    SPINE_REPO="$ROOT" \
    SPINE_RUNTIME_ROOT="$runtime_op" \
    SPINE_STATE="$runtime_op/state" \
    bash "$WAVE_SCRIPT" dispatch WAVE-DISPATCH-OP \
      --lane execution \
      --task "investigate automation workflow drift" \
      --input-refs "research_brief_ref=$brief_ref,scope_ref=$scope_ref" \
      --output-refs "execution_plan_ref=$plan_ref,acceptance_criteria_ref=$accept_ref" 2>&1
)"
assert_contains "$operational_out" "Transport: mailroom" "operational dispatch reports mailroom transport"
assert_contains "$operational_out" "Mailroom Task:" "operational dispatch reports queued task identity"

queue_dir="$runtime_op/state/agent-tasks/queued"
queued_file="$(find "$queue_dir" -name '*.yaml' | head -n1)"
if [[ -n "$queued_file" && -f "$queued_file" ]]; then
  pass "operational dispatch enqueues a real mailroom task"
else
  fail "operational dispatch enqueues a real mailroom task"
fi

python3 - <<'PY' "$queued_file" "$runtime_op/waves/WAVE-DISPATCH-OP/state.json" "$brief_ref" "$scope_ref" "$plan_ref" "$accept_ref"
import json
import subprocess
import sys
from pathlib import Path

queue_file, state_file, brief_ref, scope_ref, plan_ref, accept_ref = sys.argv[1:7]
queue = json.loads(subprocess.check_output(["yq", "e", "-o=json", ".", queue_file], text=True))
payload = json.loads(queue["payload"])
state = json.loads(Path(state_file).read_text())
dispatch = state["dispatches"][0]
lane = state["packet"]["lane_outcomes"][0]

assert queue["status"] == "queued", queue
assert queue["route_target"] == "agent_tool", queue
assert payload["wave_id"] == "WAVE-DISPATCH-OP", payload
assert payload["loop_id"] == "LOOP-DISPATCH-OP", payload
assert payload["lane"] == "execution", payload
assert payload["task"] == "investigate automation workflow drift", payload
assert payload["owner_terminal"] == "SPINE-CONTROL-01", payload
assert payload["from_role"] == "researcher", payload
assert payload["to_role"] == "worker", payload
assert payload["transition_gate"] == "researcher_to_worker", payload
assert payload["horizon"] == "now", payload
assert payload["execution_readiness"] == "runnable", payload
assert payload["input_refs"]["research_brief_ref"] == brief_ref, payload
assert payload["input_refs"]["scope_ref"] == scope_ref, payload
assert payload["expected_output_refs"]["execution_plan_ref"] == plan_ref, payload
assert payload["expected_output_refs"]["acceptance_criteria_ref"] == accept_ref, payload
assert payload["execution_mode"] == "operational", payload
assert payload["transport"] == "mailroom", payload
assert payload["dispatch_transport"] == "mailroom", payload
assert payload["route_target"]["type"] == "agent_tool", payload
assert payload["route_target"]["tool"] == "route_resolve", payload
assert payload["route_target"]["input"] == "automation", payload

assert dispatch["status"] == "dispatched", dispatch
assert dispatch["dispatch_transport"] == "mailroom", dispatch
assert dispatch["mailroom_task_id"] == queue["task_id"], dispatch
assert dispatch["mailroom_task_file"] == queue_file, dispatch
assert dispatch["mailroom_task_state"] == "queued", dispatch
assert dispatch["mailroom_route_input"] == "automation", dispatch
assert dispatch["result"] == "mailroom task queued", dispatch

assert lane["lane_status"] == "DISPATCHED", lane
assert lane["dispatch_transport"] == "mailroom", lane
assert lane["mailroom_task_id"] == queue["task_id"], lane

assert state["role_flow"]["pending_transition"]["mailroom_task_id"] == queue["task_id"], state["role_flow"]
assert state["preflight"]["verdict"] == "go", state["preflight"]
PY
pass "operational dispatch preserves workflow identity in queue and wave state"
assert_not_exists "$runtime_op/state/orchestration/LOOP-DISPATCH-OP/stubs" "operational dispatch does not create pushability blocker stubs"

status_out="$(
  env \
    SPINE_REPO="$ROOT" \
    SPINE_RUNTIME_ROOT="$runtime_op" \
    SPINE_STATE="$runtime_op/state" \
    bash "$WAVE_SCRIPT" status WAVE-DISPATCH-OP 2>&1
)"
assert_contains "$status_out" "mailroom:" "wave status surfaces queued mailroom task identity"

worker_contract="$tmpdir/mailroom-worker.contract.yaml"
cat > "$worker_contract" <<'YAML'
runtime:
  poll_seconds: 300
  error_backoff_seconds: 1
  pid_file: "mailroom-task-worker.pid"
  log_file: "mailroom-task-worker.log"
  status_file: "mailroom-task-worker.status.json"
control_cycle:
  enabled: false
task_execution:
  enabled: true
  max_claims_per_tick: 2
  claim_policy:
    worker_id: "test-worker"
    claim_all: true
    claim_unassigned: true
    allow_unhealthy_claims: false
  execute_route_targets:
    - agent_tool
YAML

worker_json="$(
  env \
    MAILROOM_TASK_WORKER_CONTRACT="$worker_contract" \
    SPINE_REPO="$ROOT" \
    SPINE_RUNTIME_ROOT="$runtime_op" \
    SPINE_INBOX="$runtime_op/inbox" \
    SPINE_OUTBOX="$runtime_op/outbox" \
    SPINE_STATE="$runtime_op/state" \
    SPINE_LOGS="$runtime_op/logs" \
    OPS_GOVERNED_MAIN_OVERRIDE=1 \
    "$TASK_WORKER" --once | extract_json
)"
python3 - <<'PY' "$worker_json"
import json
import sys
payload = json.loads(sys.argv[1])
assert payload["tasks"]["claimed"] == 1, payload
assert payload["tasks"]["completed"] == 1, payload
assert payload["tasks"]["failed"] == 0, payload
PY
pass "mailroom worker consumes queued operational dispatch automatically"

done_file="$runtime_op/state/agent-tasks/done/$(basename "$queued_file")"
if [[ -f "$done_file" ]]; then
  pass "operational dispatch task reaches done lane"
else
  fail "operational dispatch task reaches done lane"
fi

python3 - <<'PY' "$runtime_op/waves/WAVE-DISPATCH-OP/state.json"
import json
import sys
from pathlib import Path

state = json.loads(Path(sys.argv[1]).read_text())
dispatch = state["dispatches"][0]
lane = state["packet"]["lane_outcomes"][0]
role_flow = state["role_flow"]
last_collect = state["last_collect"]

assert dispatch["status"] == "done", dispatch
assert dispatch["mailroom_task_state"] == "done", dispatch
assert dispatch["dispatch_transport"] == "mailroom", dispatch
assert dispatch["run_key"], dispatch
assert dispatch["result"].startswith("Mailroom: "), dispatch

assert lane["lane_status"] == "DONE", lane
assert lane["dispatch_transport"] == "mailroom", lane
assert lane["mailroom_task_id"] == dispatch["mailroom_task_id"], lane
assert lane["run_key"] == dispatch["run_key"], lane

assert "pending_transition" not in role_flow, role_flow
assert role_flow["current_role"] == "worker", role_flow
assert state["lifecycle_state"] == "implemented", state

assert last_collect["mailroom_tasks_matched"] == 1, last_collect
assert last_collect["dispatches_matched"] == 1, last_collect
PY
pass "mailroom task completion reconciles wave state automatically"

status_done_out="$(
  env \
    SPINE_REPO="$ROOT" \
    SPINE_RUNTIME_ROOT="$runtime_op" \
    SPINE_STATE="$runtime_op/state" \
    bash "$WAVE_SCRIPT" status WAVE-DISPATCH-OP 2>&1
)"
assert_contains "$status_done_out" "[done]" "wave status surfaces reconciled mailroom task completion"

runtime_code="$tmpdir/runtime-code"
mkdir -p "$runtime_code/state" "$runtime_code/waves/WAVE-DISPATCH-CODE"
cat > "$runtime_code/waves/WAVE-DISPATCH-CODE/state.json" <<'JSON'
{
  "wave_id": "WAVE-DISPATCH-CODE",
  "status": "active",
  "objective": "code dispatch still requires git pushability",
  "created_at": "2026-03-23T00:00:00Z",
  "dispatches": [],
  "packet": {
    "wave_id": "WAVE-DISPATCH-CODE",
    "loop_id": "LOOP-DISPATCH-CODE",
    "owner_terminal": "SPINE-CONTROL-01",
    "current_role": "researcher",
    "next_role": "worker",
    "deadline_utc": "2099-01-01T00:00:00Z",
    "horizon": "now",
    "execution_readiness": "runnable",
    "claimed_paths": ["ops/commands/wave.sh"],
    "execution_mode": "code",
    "transport": "git",
    "stub_matrix": [],
    "lane_outcomes": []
  },
  "wave_packet": {
    "wave_id": "WAVE-DISPATCH-CODE",
    "loop_id": "LOOP-DISPATCH-CODE",
    "owner_terminal": "SPINE-CONTROL-01",
    "current_role": "researcher",
    "next_role": "worker",
    "deadline_utc": "2099-01-01T00:00:00Z",
    "horizon": "now",
    "execution_readiness": "runnable",
    "claimed_paths": ["ops/commands/wave.sh"],
    "execution_mode": "code",
    "transport": "git",
    "stub_matrix": [],
    "lane_outcomes": []
  },
  "role_flow": {
    "current_role": "researcher",
    "next_role": "worker"
  },
  "workspace": {}
}
JSON

set +e
code_out="$(
  env \
    SPINE_REPO="$ROOT" \
    SPINE_RUNTIME_ROOT="$runtime_code" \
    SPINE_STATE="$runtime_code/state" \
    bash "$WAVE_SCRIPT" dispatch WAVE-DISPATCH-CODE \
      --lane execution \
      --task "investigate automation workflow drift" \
      --input-refs "research_brief_ref=$brief_ref,scope_ref=$scope_ref" \
      --output-refs "execution_plan_ref=$plan_ref,acceptance_criteria_ref=$accept_ref" 2>&1
)"
code_rc=$?
set -e
if [[ "$code_rc" -ne 0 ]]; then
  pass "code/git dispatch still follows the blocking git pushability path"
else
  fail "code/git dispatch still follows the blocking git pushability path"
fi
assert_contains "$code_out" "BLOCKED: dispatch pushability preflight failed" "code/git dispatch still blocks before enqueue"
assert_not_exists "$runtime_code/state/agent-tasks/queued" "code/git dispatch does not enqueue mailroom tasks on preflight block"

echo "════════════════════════════════════════"
echo "PASS: $PASS"
echo "FAIL: $FAIL"

if [[ "$FAIL" -ne 0 ]]; then
  exit 1
fi

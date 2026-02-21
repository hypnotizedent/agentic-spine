#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)}"
BIN="$ROOT/ops/plugins/mailroom-bridge/bin/mailroom-task-worker"
ENQUEUE_BIN="$ROOT/ops/plugins/mailroom-bridge/bin/mailroom-task-enqueue"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }
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

command -v jq >/dev/null 2>&1 || fail "jq required"
command -v yq >/dev/null 2>&1 || fail "yq required"
[[ -x "$BIN" ]] || fail "worker script missing or not executable"
[[ -x "$ENQUEUE_BIN" ]] || fail "enqueue script missing or not executable"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/runtime/inbox" "$tmp/runtime/outbox" "$tmp/runtime/state" "$tmp/runtime/logs"

contract="$tmp/worker.contract.yaml"
cat >"$contract" <<'YAML'
runtime:
  poll_seconds: 300
  error_backoff_seconds: 1
  pid_file: "mailroom-task-worker.pid"
  log_file: "mailroom-task-worker.log"
  status_file: "mailroom-task-worker.status.json"
control_cycle:
  enabled: false
task_execution:
  enabled: false
  claim_policy:
    worker_id: "test-worker"
  execute_route_targets:
    - capability
YAML

worker_env=(
  "MAILROOM_TASK_WORKER_CONTRACT=$contract"
  "SPINE_INBOX=$tmp/runtime/inbox"
  "SPINE_OUTBOX=$tmp/runtime/outbox"
  "SPINE_STATE=$tmp/runtime/state"
  "SPINE_LOGS=$tmp/runtime/logs"
)

once_json="$(env "${worker_env[@]}" "$BIN" --once | extract_json)"
echo "$once_json" | jq -e '.worker_id=="test-worker"' >/dev/null || fail "worker id override from contract"
echo "$once_json" | jq -e '.cycle.enabled==false and .tasks.enabled==false' >/dev/null || fail "once mode honors disabled cycle/tasks"
pass "worker --once emits deterministic JSON without executing cycle/tasks"

status_file="$tmp/runtime/state/mailroom-task-worker.status.json"
[[ -f "$status_file" ]] || fail "status file missing after --once"
pass "status file written to runtime state path"

status_out="$(env "${worker_env[@]}" "$BIN" --status)"
echo "$status_out" | grep "status: stopped" >/dev/null || fail "status output should report stopped without daemon"
echo "$status_out" | grep "worker_id: test-worker" >/dev/null || fail "status output should include worker id"
pass "worker --status output contract"

contract_agent_tool="$tmp/worker.agent-tool.contract.yaml"
cat >"$contract_agent_tool" <<'YAML'
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
    - capability
    - agent_tool
YAML

agent_payload="$(jq -cn '{action_id:"A90-route-discovery",title:"Resolve delegation target",reason:"test",route_target:{type:"agent_tool",tool:"route_resolve",input:"automation"},execution_mode:"delegated",route_resolution:{status:"matched",data:{input:"automation",agent:{id:"n8n-agent"}}}}')"
env MAILROOM_TASK_WORKER_CONTRACT="$contract_agent_tool" SPINE_INBOX="$tmp/runtime/inbox" SPINE_OUTBOX="$tmp/runtime/outbox" SPINE_STATE="$tmp/runtime/state" SPINE_LOGS="$tmp/runtime/logs" "$ENQUEUE_BIN" \
  --task-id TASK-AGENT-001 \
  --summary "delegated route task" \
  --route-target agent_tool \
  --payload "$agent_payload" \
  --json >/dev/null

queued_file="$tmp/runtime/state/agent-tasks/queued/TASK-AGENT-001.yaml"
[[ -f "$queued_file" ]] || fail "enqueue should create queued delegated task file"
stored_payload="$(yq e -r '.payload' "$queued_file")"
[[ "$stored_payload" == "$agent_payload" ]] || fail "queued task payload should round-trip JSON envelope safely"

agent_once_json="$(env MAILROOM_TASK_WORKER_CONTRACT="$contract_agent_tool" SPINE_INBOX="$tmp/runtime/inbox" SPINE_OUTBOX="$tmp/runtime/outbox" SPINE_STATE="$tmp/runtime/state" SPINE_LOGS="$tmp/runtime/logs" "$BIN" --once | extract_json)"
echo "$agent_once_json" | jq -e '.tasks.claimed==1 and .tasks.completed==1 and .tasks.failed==0' >/dev/null || fail "agent_tool task should be claimed and completed"

done_file="$tmp/runtime/state/agent-tasks/done/TASK-AGENT-001.yaml"
[[ -f "$done_file" ]] || fail "delegated agent_tool task should be moved to done"
yq e -r '.status' "$done_file" | grep '^done$' >/dev/null || fail "done task status should be done"
yq e -r '.result' "$done_file" | grep 'agent_tool=route_resolve' >/dev/null || fail "done result should include delegated agent_tool execution detail"
pass "worker consumes delegated agent_tool task end-to-end"

echo "mailroom-task-worker tests"

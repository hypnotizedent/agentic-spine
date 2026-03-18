#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
BIN="$ROOT/ops/plugins/infra/mailroom-bridge/bin/mailroom-task-worker"
ENQUEUE_BIN="$ROOT/ops/plugins/infra/mailroom-bridge/bin/mailroom-task-enqueue"
HANDOFF_CREATE_BIN="$ROOT/ops/plugins/core/handoff/bin/session-handoff-create"
HANDOFF_ACCEPT_BIN="$ROOT/ops/plugins/core/handoff/bin/session-handoff-accept"
HANDOFF_CLOSE_BIN="$ROOT/ops/plugins/core/handoff/bin/session-handoff-close"
CAP_BIN="$ROOT/bin/ops"
AOF_ACK_BIN="$ROOT/ops/plugins/core/aof/bin/contract-read-check.sh"

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
[[ -x "$HANDOFF_CREATE_BIN" ]] || fail "handoff create script missing or not executable"
[[ -x "$HANDOFF_ACCEPT_BIN" ]] || fail "handoff accept script missing or not executable"
[[ -x "$HANDOFF_CLOSE_BIN" ]] || fail "handoff close script missing or not executable"
[[ -x "$CAP_BIN" ]] || fail "ops cap entry missing or not executable"
[[ -x "$AOF_ACK_BIN" ]] || fail "AOF contract helper missing or not executable"

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

once_json="$(env -u OPS_GOVERNED_MAIN_OVERRIDE -u SPINE_RUNTIME_ROLE -u OPS_TERMINAL_ROLE -u SPINE_TERMINAL_NAME "${worker_env[@]}" "$BIN" --once | extract_json)"
echo "$once_json" | jq -e '.worker_id=="test-worker"' >/dev/null || fail "worker id override from contract"
echo "$once_json" | jq -e '.cycle.enabled==false and .tasks.enabled==false' >/dev/null || fail "once mode honors disabled cycle/tasks"
echo "$once_json" | jq -e '.bootstrap.ready == true and .bootstrap.governed_main_override.value == "1" and .bootstrap.runtime_role.value == "worker" and .bootstrap.terminal_role.value == "SPINE-CONTROL-01"' >/dev/null || fail "worker should self-bootstrap governed runtime env"
pass "worker --once emits deterministic JSON without executing cycle/tasks"

status_file="$tmp/runtime/state/mailroom-task-worker.status.json"
[[ -f "$status_file" ]] || fail "status file missing after --once"
pass "status file written to runtime state path"

status_out="$(env -u OPS_GOVERNED_MAIN_OVERRIDE -u SPINE_RUNTIME_ROLE -u OPS_TERMINAL_ROLE -u SPINE_TERMINAL_NAME "${worker_env[@]}" "$BIN" --status)"
echo "$status_out" | grep "status: stopped" >/dev/null || fail "status output should report stopped without daemon"
echo "$status_out" | grep "worker_id: test-worker" >/dev/null || fail "status output should include worker id"
echo "$status_out" | grep "bootstrap: override=1" >/dev/null || fail "status output should surface bootstrap override state"
pass "worker --status output contract"

contract_daemon="$tmp/worker.daemon.contract.yaml"
cat >"$contract_daemon" <<'YAML'
runtime:
  poll_seconds: 5
  error_backoff_seconds: 1
  pid_file: "mailroom-task-worker.pid"
  log_file: "mailroom-task-worker.log"
  status_file: "mailroom-task-worker.status.json"
control_cycle:
  enabled: false
task_execution:
  enabled: false
  claim_policy:
    worker_id: "daemon-worker"
YAML

daemon_env=(
  "MAILROOM_TASK_WORKER_CONTRACT=$contract_daemon"
  "SPINE_INBOX=$tmp/runtime/inbox"
  "SPINE_OUTBOX=$tmp/runtime/outbox"
  "SPINE_STATE=$tmp/runtime/state"
  "SPINE_LOGS=$tmp/runtime/logs"
)

daemon_start="$(env -u OPS_GOVERNED_MAIN_OVERRIDE -u SPINE_RUNTIME_ROLE -u OPS_TERMINAL_ROLE -u SPINE_TERMINAL_NAME "${daemon_env[@]}" "$BIN" --daemon)"
echo "$daemon_start" | grep "status: running" >/dev/null || fail "daemon start should report running"
daemon_status="$(env -u OPS_GOVERNED_MAIN_OVERRIDE -u SPINE_RUNTIME_ROLE -u OPS_TERMINAL_ROLE -u SPINE_TERMINAL_NAME "${daemon_env[@]}" "$BIN" --status)"
echo "$daemon_status" | grep "bootstrap: override=1" >/dev/null || fail "daemon status should show self-bootstrapped override"
echo "$daemon_status" | grep "terminal=SPINE-CONTROL-01" >/dev/null || fail "daemon status should show canonical control terminal role"
env "${daemon_env[@]}" "$BIN" --stop >/dev/null
pass "worker daemon start self-bootstraps governed env"

cap_env=(
  "OPS_CAP_AUTO_APPROVE=yes"
  "SPINE_CODE=$ROOT"
  "MAILROOM_TASK_WORKER_CONTRACT=$contract_daemon"
  "SPINE_INBOX=$tmp/runtime/inbox"
  "SPINE_OUTBOX=$tmp/runtime/outbox"
  "SPINE_STATE=$tmp/runtime/state"
  "SPINE_LOGS=$tmp/runtime/logs"
)

if [[ -f "$ROOT/.environment.yaml" ]]; then
  env "SPINE_STATE=$tmp/runtime/state" "CONTRACT_FILE=$ROOT/.environment.yaml" "$AOF_ACK_BIN" --ack >/dev/null
fi

cap_start="$(env -u OPS_GOVERNED_MAIN_OVERRIDE -u SPINE_RUNTIME_ROLE -u OPS_TERMINAL_ROLE -u SPINE_TERMINAL_NAME "${cap_env[@]}" "$CAP_BIN" cap run mailroom.task.worker.start)"
echo "$cap_start" | grep "allowlisted bootstrap/control-plane capability 'mailroom.task.worker.start'" >/dev/null || fail "cap start should be allowlisted through mutation context guard"
echo "$cap_start" | grep "status: running" >/dev/null || fail "cap start should report running"

cap_status="$(env -u OPS_GOVERNED_MAIN_OVERRIDE -u SPINE_RUNTIME_ROLE -u OPS_TERMINAL_ROLE -u SPINE_TERMINAL_NAME "${cap_env[@]}" "$CAP_BIN" cap run mailroom.task.worker.status)"
echo "$cap_status" | grep "status: running" >/dev/null || fail "cap status should report running daemon"
echo "$cap_status" | grep "bootstrap: override=1" >/dev/null || fail "cap status should surface governed bootstrap override"

cap_stop="$(env -u OPS_GOVERNED_MAIN_OVERRIDE -u SPINE_RUNTIME_ROLE -u OPS_TERMINAL_ROLE -u SPINE_TERMINAL_NAME "${cap_env[@]}" "$CAP_BIN" cap run mailroom.task.worker.stop)"
echo "$cap_stop" | grep "allowlisted bootstrap/control-plane capability 'mailroom.task.worker.stop'" >/dev/null || fail "cap stop should be allowlisted through mutation context guard"
echo "$cap_stop" | grep "mailroom.task.worker: stopped pid=" >/dev/null || fail "cap stop should stop the daemon"
cap_status_after_stop="$(env -u OPS_GOVERNED_MAIN_OVERRIDE -u SPINE_RUNTIME_ROLE -u OPS_TERMINAL_ROLE -u SPINE_TERMINAL_NAME "${cap_env[@]}" "$CAP_BIN" cap run mailroom.task.worker.status)"
echo "$cap_status_after_stop" | grep "status: stopped" >/dev/null || fail "cap status after stop should report stopped"
pass "cap entrypoint start/status/stop works on main with temp runtime"

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

handoff_launch_log="$tmp/handoff-launch.log"
cat >"$tmp/fake-handoff-launch" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
log_file="${FAKE_HANDOFF_LAUNCH_LOG:?}"
accept_bin="${HANDOFF_ACCEPT_BIN_REAL:?}"
role=""
tool=""
terminal=""
handoff_id=""
handoff_file=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --role) role="${2:?}"; shift 2 ;;
    --tool) tool="${2:?}"; shift 2 ;;
    --terminal) terminal="${2:?}"; shift 2 ;;
    --handoff-id) handoff_id="${2:?}"; shift 2 ;;
    --handoff-file) handoff_file="${2:?}"; shift 2 ;;
    *) shift ;;
  esac
done
[[ -n "$role" ]] || { echo "missing --role" >&2; exit 9; }
[[ -n "$tool" ]] || { echo "missing --tool" >&2; exit 9; }
[[ -n "$terminal" ]] || { echo "missing --terminal" >&2; exit 9; }
[[ -n "$handoff_id" ]] || { echo "missing --handoff-id" >&2; exit 9; }
[[ -n "$handoff_file" ]] || { echo "missing --handoff-file" >&2; exit 9; }
{
  echo "handoff_id=$handoff_id"
  echo "handoff_file=$handoff_file"
  echo "env_handoff_id=${SPINE_DISPATCH_HANDOFF_ID:-}"
  echo "target_agent_id=${SPINE_DISPATCH_TARGET_AGENT_ID:-}"
  echo "target_terminal_id=${SPINE_DISPATCH_TARGET_TERMINAL_ID:-}"
  echo "target_tool=${SPINE_DISPATCH_TARGET_TOOL:-}"
  echo "worker_id=${SPINE_DISPATCH_WORKER_ID:-}"
  echo "role=$role"
  echo "tool=$tool"
  echo "terminal=$terminal"
} >"$log_file"
if [[ "${FAKE_HANDOFF_SKIP_ACCEPT:-0}" != "1" ]]; then
  (
    sleep "${FAKE_HANDOFF_ACCEPT_DELAY:-1}"
    env \
      "SPINE_INBOX=${SPINE_INBOX:-}" \
      "SPINE_OUTBOX=${SPINE_OUTBOX:-}" \
      "SPINE_STATE=${SPINE_STATE:-}" \
      "SPINE_LOGS=${SPINE_LOGS:-}" \
      "$accept_bin" \
        --id "$handoff_id" \
        --handoff-file "$handoff_file" \
        --terminal-id "$terminal" \
        --tool "$tool" \
        --session-id "${FAKE_HANDOFF_SESSION_ID:-SESSION-HANDOFF-001}" \
        --agent-id "${SPINE_DISPATCH_TARGET_AGENT_ID:-}" \
        --worker-id "${SPINE_DISPATCH_WORKER_ID:-}" >/dev/null
  ) &
fi
echo "launch-ok terminal=$terminal tool=$tool handoff=$handoff_id"
SH
chmod +x "$tmp/fake-handoff-launch"

cat >"$tmp/fake-handoff-launch-timeout" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
sleep "${FAKE_HANDOFF_LAUNCH_SLEEP_SECONDS:-3}"
SH
chmod +x "$tmp/fake-handoff-launch-timeout"

contract_handoff="$tmp/worker.handoff.contract.yaml"
cat >"$contract_handoff" <<YAML
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
  max_claims_per_tick: 1
  claim_policy:
    worker_id: "test-worker"
    claim_all: true
    allow_unhealthy_claims: false
  execute_route_targets:
    - handoff
  handoff_dispatch:
    launcher_command:
      - $tmp/fake-handoff-launch
    launch_timeout_seconds: 5
    accept_timeout_seconds: 5
    accept_poll_interval_seconds: 1
    launch_role: solo
    default_tool: codex
    reconcile_capability: session.handoff.task_reconcile
YAML

handoff_env=(
  "MAILROOM_TASK_WORKER_CONTRACT=$contract_handoff"
  "SPINE_INBOX=$tmp/runtime/inbox"
  "SPINE_OUTBOX=$tmp/runtime/outbox"
  "SPINE_STATE=$tmp/runtime/state"
  "SPINE_LOGS=$tmp/runtime/logs"
  "FAKE_HANDOFF_LAUNCH_LOG=$handoff_launch_log"
  "HANDOFF_ACCEPT_BIN_REAL=$HANDOFF_ACCEPT_BIN"
  "FAKE_HANDOFF_SESSION_ID=SESSION-HANDOFF-001"
  "FAKE_HANDOFF_ACCEPT_DELAY=1"
)

rm -f "$tmp/runtime/state/agent-tasks/queued/"*.yaml "$tmp/runtime/state/agent-tasks/running/"*.yaml "$tmp/runtime/state/agent-tasks/done/"*.yaml "$tmp/runtime/state/agent-tasks/failed/"*.yaml 2>/dev/null || true
rm -f "$tmp/runtime/state/handoffs/"*.yaml 2>/dev/null || true

handoff_create_json="$(
  env "SPINE_INBOX=$tmp/runtime/inbox" "SPINE_OUTBOX=$tmp/runtime/outbox" "SPINE_STATE=$tmp/runtime/state" "SPINE_LOGS=$tmp/runtime/logs" "$HANDOFF_CREATE_BIN" \
    --summary "Bounded worker: dispatch handoff to governed terminal" \
    --loops "LOOP-HANDOFF-DISPATCH" \
    --actions "dispatch" \
    --owner tester \
    --from-role researcher \
    --to-role worker \
    --input-refs "research_brief_ref=/tmp/plan.md#research-brief,scope_ref=/tmp/plan.md#scope" \
    --output-refs "execution_plan_ref=/tmp/plan.md#execution-plan,acceptance_criteria_ref=/tmp/plan.md#acceptance-criteria" \
    --json
)"
handoff_id="$(echo "$handoff_create_json" | jq -r '.id')"
handoff_file="$(echo "$handoff_create_json" | jq -r '.file')"
handoff_task_id="$(echo "$handoff_create_json" | jq -r '.task_bridge.task_id')"
handoff_done_file="$tmp/runtime/state/agent-tasks/done/${handoff_task_id}.yaml"

handoff_once_json="$(env -u OPS_GOVERNED_MAIN_OVERRIDE -u SPINE_RUNTIME_ROLE -u OPS_TERMINAL_ROLE -u SPINE_TERMINAL_NAME "${handoff_env[@]}" "$BIN" --once | extract_json)"
echo "$handoff_once_json" | jq -e '.tasks.claimed == 1 and .tasks.completed == 1 and .tasks.failed == 0' >/dev/null || fail "handoff task should be claimed and completed only after acceptance"
[[ -f "$handoff_done_file" ]] || fail "accepted handoff should move task to done"
yq e -r '.health_preflight' "$handoff_done_file" | grep '^strict-pass$' >/dev/null || fail "handoff dispatch should preserve strict-pass agent preflight"
yq e -r '.result' "$handoff_done_file" | grep "target_terminal_id=MINT-DUTCHMAN-01" >/dev/null || fail "handoff dispatch result should capture target terminal"
yq e -r '.result' "$handoff_done_file" | grep "target_agent_id=flying-dutchman" >/dev/null || fail "handoff dispatch result should capture target agent"
yq e -r '.result' "$handoff_done_file" | grep "accepted_by_session_id=SESSION-HANDOFF-001" >/dev/null || fail "handoff dispatch result should capture accepted session id"
yq e -r '.state' "$handoff_file" | grep '^active$' >/dev/null || fail "handoff should remain active after dispatch"
yq e -r '.task_bridge.task_state' "$handoff_file" | grep '^done$' >/dev/null || fail "handoff dispatch should reconcile task bridge state to done"
yq e -r '.dispatch.status' "$handoff_file" | grep '^accepted$' >/dev/null || fail "handoff should record accepted dispatch status"
yq e -r '.dispatch.accepted_by_session_id' "$handoff_file" | grep '^SESSION-HANDOFF-001$' >/dev/null || fail "handoff should persist accepted session id"
yq e -r '.dispatch.target_terminal_id' "$handoff_file" | grep '^MINT-DUTCHMAN-01$' >/dev/null || fail "handoff should persist dispatched terminal id"
yq e -r '.dispatch.target_agent_id' "$handoff_file" | grep '^flying-dutchman$' >/dev/null || fail "handoff should persist dispatched agent id"
grep "^handoff_id=$handoff_id\$" "$handoff_launch_log" >/dev/null || fail "fake handoff launcher should receive handoff id"
grep "^handoff_file=$handoff_file\$" "$handoff_launch_log" >/dev/null || fail "fake handoff launcher should receive handoff file"
grep '^terminal=MINT-DUTCHMAN-01$' "$handoff_launch_log" >/dev/null || fail "fake handoff launcher should target MINT-DUTCHMAN-01"
grep '^tool=codex$' "$handoff_launch_log" >/dev/null || fail "fake handoff launcher should use terminal default tool"

env "SPINE_INBOX=$tmp/runtime/inbox" "SPINE_OUTBOX=$tmp/runtime/outbox" "SPINE_STATE=$tmp/runtime/state" "SPINE_LOGS=$tmp/runtime/logs" "$HANDOFF_CLOSE_BIN" \
  --id "$handoff_id" \
  --note "dispatch acknowledged by target terminal" >/dev/null
yq e -r '.state' "$handoff_file" | grep '^closed$' >/dev/null || fail "handoff should close cleanly after dispatch"
[[ -f "$handoff_done_file" ]] || fail "done task should remain done after handoff close"
pass "worker completes handoff tasks only after target acceptance and closeout remains clean"

rm -f "$tmp/runtime/state/agent-tasks/queued/"*.yaml "$tmp/runtime/state/agent-tasks/running/"*.yaml "$tmp/runtime/state/agent-tasks/done/"*.yaml "$tmp/runtime/state/agent-tasks/failed/"*.yaml 2>/dev/null || true
rm -f "$tmp/runtime/state/handoffs/"*.yaml 2>/dev/null || true

handoff_no_accept_json="$(
  env "SPINE_INBOX=$tmp/runtime/inbox" "SPINE_OUTBOX=$tmp/runtime/outbox" "SPINE_STATE=$tmp/runtime/state" "SPINE_LOGS=$tmp/runtime/logs" "$HANDOFF_CREATE_BIN" \
    --summary "Bounded worker: launched handoff must not complete without acceptance" \
    --loops "LOOP-HANDOFF-NO-ACCEPT" \
    --actions "dispatch,wait" \
    --owner tester \
    --from-role researcher \
    --to-role worker \
    --input-refs "research_brief_ref=/tmp/plan.md#research-brief,scope_ref=/tmp/plan.md#scope" \
    --output-refs "execution_plan_ref=/tmp/plan.md#execution-plan,acceptance_criteria_ref=/tmp/plan.md#acceptance-criteria" \
    --json
)"
handoff_no_accept_id="$(echo "$handoff_no_accept_json" | jq -r '.id')"
handoff_no_accept_file="$(echo "$handoff_no_accept_json" | jq -r '.file')"
handoff_no_accept_task_id="$(echo "$handoff_no_accept_json" | jq -r '.task_bridge.task_id')"
handoff_no_accept_failed_file="$tmp/runtime/state/agent-tasks/failed/${handoff_no_accept_task_id}.yaml"

handoff_no_accept_once_json="$(
  env -u OPS_GOVERNED_MAIN_OVERRIDE -u SPINE_RUNTIME_ROLE -u OPS_TERMINAL_ROLE -u SPINE_TERMINAL_NAME \
    "${handoff_env[@]}" \
    "FAKE_HANDOFF_SKIP_ACCEPT=1" \
    "$BIN" --once | extract_json
)"
echo "$handoff_no_accept_once_json" | jq -e '.tasks.claimed == 1 and .tasks.completed == 0 and .tasks.failed == 1' >/dev/null || fail "launched handoff without acceptance should fail instead of completing"
[[ -f "$handoff_no_accept_failed_file" ]] || fail "unaccepted handoff should move task to failed"
yq e -r '.task_bridge.task_state' "$handoff_no_accept_file" | grep '^failed$' >/dev/null || fail "failed handoff should reconcile failed task state"
yq e -r '.dispatch.status' "$handoff_no_accept_file" | grep '^failed$' >/dev/null || fail "handoff without acceptance should persist failed dispatch status"
yq e -r '.dispatch.last_error' "$handoff_no_accept_file" | grep 'handoff_accept_timeout' >/dev/null || fail "handoff without acceptance should record accept timeout reason"
pass "worker does not treat launched handoffs as done without target acceptance"

contract_handoff_launch_timeout="$tmp/worker.handoff-timeout.contract.yaml"
cat >"$contract_handoff_launch_timeout" <<YAML
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
  max_claims_per_tick: 1
  claim_policy:
    worker_id: "test-worker"
    claim_all: true
    allow_unhealthy_claims: false
  execute_route_targets:
    - handoff
  handoff_dispatch:
    launcher_command:
      - $tmp/fake-handoff-launch-timeout
    launch_timeout_seconds: 1
    accept_timeout_seconds: 1
    accept_poll_interval_seconds: 1
    launch_role: solo
    default_tool: codex
    reconcile_capability: session.handoff.task_reconcile
YAML

handoff_timeout_env=(
  "MAILROOM_TASK_WORKER_CONTRACT=$contract_handoff_launch_timeout"
  "SPINE_INBOX=$tmp/runtime/inbox"
  "SPINE_OUTBOX=$tmp/runtime/outbox"
  "SPINE_STATE=$tmp/runtime/state"
  "SPINE_LOGS=$tmp/runtime/logs"
  "FAKE_HANDOFF_LAUNCH_SLEEP_SECONDS=3"
)

rm -f "$tmp/runtime/state/agent-tasks/queued/"*.yaml "$tmp/runtime/state/agent-tasks/running/"*.yaml "$tmp/runtime/state/agent-tasks/done/"*.yaml "$tmp/runtime/state/agent-tasks/failed/"*.yaml 2>/dev/null || true
rm -f "$tmp/runtime/state/handoffs/"*.yaml 2>/dev/null || true

handoff_timeout_json="$(
  env "SPINE_INBOX=$tmp/runtime/inbox" "SPINE_OUTBOX=$tmp/runtime/outbox" "SPINE_STATE=$tmp/runtime/state" "SPINE_LOGS=$tmp/runtime/logs" "$HANDOFF_CREATE_BIN" \
    --summary "Bounded worker: launcher timeout should fail task not worker" \
    --loops "LOOP-HANDOFF-LAUNCH-TIMEOUT" \
    --actions "dispatch" \
    --owner tester \
    --from-role researcher \
    --to-role worker \
    --input-refs "research_brief_ref=/tmp/plan.md#research-brief,scope_ref=/tmp/plan.md#scope" \
    --output-refs "execution_plan_ref=/tmp/plan.md#execution-plan,acceptance_criteria_ref=/tmp/plan.md#acceptance-criteria" \
    --json
)"
handoff_timeout_id="$(echo "$handoff_timeout_json" | jq -r '.id')"
handoff_timeout_file="$(echo "$handoff_timeout_json" | jq -r '.file')"
handoff_timeout_task_id="$(echo "$handoff_timeout_json" | jq -r '.task_bridge.task_id')"
handoff_timeout_failed_file="$tmp/runtime/state/agent-tasks/failed/${handoff_timeout_task_id}.yaml"

handoff_timeout_once_json="$(
  env -u OPS_GOVERNED_MAIN_OVERRIDE -u SPINE_RUNTIME_ROLE -u OPS_TERMINAL_ROLE -u SPINE_TERMINAL_NAME \
    "${handoff_timeout_env[@]}" \
    "$BIN" --once | extract_json
)"
echo "$handoff_timeout_once_json" | jq -e '.tasks.claimed == 1 and .tasks.completed == 0 and .tasks.failed == 1' >/dev/null || fail "handoff launcher timeout should fail the task without crashing the worker"
[[ -f "$handoff_timeout_failed_file" ]] || fail "timed out handoff should move task to failed"
yq e -r '.dispatch.status' "$handoff_timeout_file" | grep '^failed$' >/dev/null || fail "handoff launcher timeout should persist failed dispatch status"
yq e -r '.dispatch.last_error' "$handoff_timeout_file" | grep 'handoff_launch_timeout:1s' >/dev/null || fail "handoff launcher timeout should record launch timeout reason"
pass "handoff launcher timeout degrades to task failure instead of worker death"

# ── max_claims_per_tick enforcement test ──
# Contract above sets max_claims_per_tick=2. Enqueue 4 tasks, run once,
# verify only 2 are claimed (the bound is enforced).

contract_bounded="$tmp/worker.bounded.contract.yaml"
cat >"$contract_bounded" <<'YAML'
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
  execute_route_targets:
    - capability
  capability_allowlist:
    - session.handoff.status
YAML

bounded_env=(
  "MAILROOM_TASK_WORKER_CONTRACT=$contract_bounded"
  "SPINE_INBOX=$tmp/runtime/inbox"
  "SPINE_OUTBOX=$tmp/runtime/outbox"
  "SPINE_STATE=$tmp/runtime/state"
  "SPINE_LOGS=$tmp/runtime/logs"
)

# Clean queued dir from previous tests
rm -f "$tmp/runtime/state/agent-tasks/queued/"*.yaml 2>/dev/null || true

cap_payload="$(jq -cn '{capability:"lifecycle.health"}')"
for i in 1 2 3 4; do
  env "${bounded_env[@]}" "$ENQUEUE_BIN" \
    --task-id "TASK-BOUND-$i" \
    --summary "bounded test task $i" \
    --route-target capability \
    --payload "$cap_payload" \
    --json >/dev/null
done

queued_before="$(ls "$tmp/runtime/state/agent-tasks/queued/"*.yaml 2>/dev/null | wc -l | tr -d ' ')"
[[ "$queued_before" == "4" ]] || fail "expected 4 queued tasks, got $queued_before"

bounded_json="$(env "${bounded_env[@]}" "$BIN" --once | extract_json)"
bounded_claimed="$(echo "$bounded_json" | jq -r '.tasks.claimed')"
bounded_max="$(echo "$bounded_json" | jq -r '.tasks.max_claims_per_tick')"

[[ "$bounded_max" == "2" ]] || fail "max_claims_per_tick should be 2, got $bounded_max"
[[ "$bounded_claimed" -le 2 ]] || fail "claimed ($bounded_claimed) exceeds max_claims_per_tick bound (2)"
pass "max_claims_per_tick=2 enforced: claimed=$bounded_claimed max=$bounded_max"

contract_known_agent="$tmp/worker.known-agent.contract.yaml"
cat >"$contract_known_agent" <<'YAML'
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
  max_claims_per_tick: 1
  claim_policy:
    worker_id: "test-worker"
    claim_all: true
    allow_unhealthy_claims: false
  execute_route_targets:
    - capability
  capability_allowlist:
    - agent.health.check-all
YAML

known_agent_env=(
  "MAILROOM_TASK_WORKER_CONTRACT=$contract_known_agent"
  "SPINE_INBOX=$tmp/runtime/inbox"
  "SPINE_OUTBOX=$tmp/runtime/outbox"
  "SPINE_STATE=$tmp/runtime/state"
  "SPINE_LOGS=$tmp/runtime/logs"
)

rm -f "$tmp/runtime/state/agent-tasks/queued/"*.yaml "$tmp/runtime/state/agent-tasks/running/"*.yaml "$tmp/runtime/state/agent-tasks/done/"*.yaml "$tmp/runtime/state/agent-tasks/failed/"*.yaml 2>/dev/null || true

known_agent_payload="$(jq -cn '{capability:"agent.health.check-all",args:["--agents","dutchman","--json"]}')"
env "${known_agent_env[@]}" "$ENQUEUE_BIN" \
  --task-id TASK-KNOWN-AGENT-1 \
  --summary "known alias agent without probes should still claim" \
  --required-agents "dutchman" \
  --route-target capability \
  --payload "$known_agent_payload" \
  --json >/dev/null

known_agent_json="$(env -u OPS_GOVERNED_MAIN_OVERRIDE -u SPINE_RUNTIME_ROLE -u OPS_TERMINAL_ROLE -u SPINE_TERMINAL_NAME "${known_agent_env[@]}" "$BIN" --once | extract_json)"
echo "$known_agent_json" | jq -e '.tasks.claimed == 1 and .tasks.completed == 1 and .tasks.failed == 0' >/dev/null || fail "known no-probe agent aliases should not block claim preflight"
[[ -f "$tmp/runtime/state/agent-tasks/done/TASK-KNOWN-AGENT-1.yaml" ]] || fail "known agent task should move to done"
yq e -r '.health_preflight' "$tmp/runtime/state/agent-tasks/done/TASK-KNOWN-AGENT-1.yaml" | grep '^strict-pass$' >/dev/null || fail "known no-probe agent alias should record a strict-pass preflight"
pass "worker claims known alias agents even when they expose no health probes"

contract_quarantine="$tmp/worker.quarantine.contract.yaml"
cat >"$contract_quarantine" <<'YAML'
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
  max_claims_per_tick: 1
  claim_policy:
    worker_id: "test-worker"
    claim_all: true
    claim_unassigned: true
    allow_unhealthy_claims: false
  claim_failure_policy:
    quarantine_after_failures: 2
  execute_route_targets:
    - capability
  capability_allowlist:
    - verify.core.run
YAML

quarantine_env=(
  "MAILROOM_TASK_WORKER_CONTRACT=$contract_quarantine"
  "SPINE_INBOX=$tmp/runtime/inbox"
  "SPINE_OUTBOX=$tmp/runtime/outbox"
  "SPINE_STATE=$tmp/runtime/state"
  "SPINE_LOGS=$tmp/runtime/logs"
)

rm -f "$tmp/runtime/state/agent-tasks/queued/"*.yaml "$tmp/runtime/state/agent-tasks/running/"*.yaml "$tmp/runtime/state/agent-tasks/failed/"*.yaml 2>/dev/null || true

poison_payload="$(jq -cn '{capability:"verify.core.run"}')"
env "${quarantine_env[@]}" "$ENQUEUE_BIN" \
  --task-id TASK-POISON-1 \
  --summary "poison task" \
  --required-agents "__missing_agent__" \
  --route-target capability \
  --payload "$poison_payload" \
  --json >/dev/null

first_fail_json="$(env -u OPS_GOVERNED_MAIN_OVERRIDE -u SPINE_RUNTIME_ROLE -u OPS_TERMINAL_ROLE -u SPINE_TERMINAL_NAME "${quarantine_env[@]}" "$BIN" --once | extract_json)"
echo "$first_fail_json" | jq -e '.tasks.failed == 1 and .tasks.quarantined == 0 and .tasks.last_claim_failure_task_id == "TASK-POISON-1"' >/dev/null || fail "first poison-task failure should be recorded without quarantine"
[[ -f "$tmp/runtime/state/agent-tasks/queued/TASK-POISON-1.yaml" ]] || fail "poison task should remain queued after first failure"
[[ "$(yq e -r '.claim_failure_count' "$tmp/runtime/state/agent-tasks/queued/TASK-POISON-1.yaml")" == "1" ]] || fail "first poison-task failure should increment claim_failure_count"

second_fail_json="$(env -u OPS_GOVERNED_MAIN_OVERRIDE -u SPINE_RUNTIME_ROLE -u OPS_TERMINAL_ROLE -u SPINE_TERMINAL_NAME "${quarantine_env[@]}" "$BIN" --once | extract_json)"
echo "$second_fail_json" | jq -e '.tasks.failed == 1 and .tasks.quarantined == 1 and .tasks.last_claim_failure_task_id == "TASK-POISON-1"' >/dev/null || fail "second poison-task failure should quarantine the task"
[[ ! -f "$tmp/runtime/state/agent-tasks/queued/TASK-POISON-1.yaml" ]] || fail "poison task should leave queued after quarantine"
[[ -f "$tmp/runtime/state/agent-tasks/failed/TASK-POISON-1.yaml" ]] || fail "poison task should move to failed after quarantine"
yq e -r '.failure_reason' "$tmp/runtime/state/agent-tasks/failed/TASK-POISON-1.yaml" | grep '^claim_quarantine:' >/dev/null || fail "poison task failure reason should record quarantine"
quarantine_status="$(env "${quarantine_env[@]}" "$BIN" --status)"
echo "$quarantine_status" | grep "last_claim_failure: TASK-POISON-1" >/dev/null || fail "status output should surface last claim failure task id"
pass "worker quarantines repeated claim failures and surfaces the blocker"

echo "mailroom-task-worker tests"

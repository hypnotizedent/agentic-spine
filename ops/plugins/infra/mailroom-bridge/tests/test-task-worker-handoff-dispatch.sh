#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
BIN="$ROOT/ops/plugins/infra/mailroom-bridge/bin/mailroom-task-worker"
HANDOFF_CREATE_BIN="$ROOT/ops/plugins/core/handoff/bin/session-handoff-create"
HANDOFF_ACCEPT_BIN="$ROOT/ops/plugins/core/handoff/bin/session-handoff-accept"
HANDOFF_CLOSE_BIN="$ROOT/ops/plugins/core/handoff/bin/session-handoff-close"

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
[[ -x "$HANDOFF_CREATE_BIN" ]] || fail "handoff create script missing or not executable"
[[ -x "$HANDOFF_ACCEPT_BIN" ]] || fail "handoff accept script missing or not executable"
[[ -x "$HANDOFF_CLOSE_BIN" ]] || fail "handoff close script missing or not executable"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/runtime/inbox" "$tmp/runtime/outbox" "$tmp/runtime/state" "$tmp/runtime/logs"

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
[[ -n "$handoff_id" ]] || { echo "missing --handoff-id" >&2; exit 9; }
[[ -n "$handoff_file" ]] || { echo "missing --handoff-file" >&2; exit 9; }
{
  echo "handoff_id=$handoff_id"
  echo "handoff_file=$handoff_file"
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

create_handoff() {
  env "SPINE_INBOX=$tmp/runtime/inbox" "SPINE_OUTBOX=$tmp/runtime/outbox" "SPINE_STATE=$tmp/runtime/state" "SPINE_LOGS=$tmp/runtime/logs" "$HANDOFF_CREATE_BIN" \
    --summary "$1" \
    --loops "$2" \
    --actions "dispatch" \
    --owner tester \
    --from-role researcher \
    --to-role worker \
    --input-refs "research_brief_ref=/tmp/plan.md#research-brief,scope_ref=/tmp/plan.md#scope" \
    --output-refs "execution_plan_ref=/tmp/plan.md#execution-plan,acceptance_criteria_ref=/tmp/plan.md#acceptance-criteria" \
    --json
}

rm -f "$tmp/runtime/state/agent-tasks/queued/"*.yaml "$tmp/runtime/state/agent-tasks/running/"*.yaml "$tmp/runtime/state/agent-tasks/done/"*.yaml "$tmp/runtime/state/agent-tasks/failed/"*.yaml 2>/dev/null || true
rm -f "$tmp/runtime/state/handoffs/"*.yaml 2>/dev/null || true

handoff_create_json="$(create_handoff "Bounded worker: dispatch handoff to governed terminal" "LOOP-HANDOFF-DISPATCH")"
handoff_id="$(echo "$handoff_create_json" | jq -r '.id')"
handoff_file="$(echo "$handoff_create_json" | jq -r '.file')"
handoff_task_id="$(echo "$handoff_create_json" | jq -r '.task_bridge.task_id')"
handoff_done_file="$tmp/runtime/state/agent-tasks/done/${handoff_task_id}.yaml"

handoff_once_json="$(env -u OPS_GOVERNED_MAIN_OVERRIDE -u SPINE_RUNTIME_ROLE -u OPS_TERMINAL_ROLE -u SPINE_TERMINAL_NAME "${handoff_env[@]}" "$BIN" --once | extract_json)"
echo "$handoff_once_json" | jq -e '.tasks.claimed == 1 and .tasks.completed == 1 and .tasks.failed == 0' >/dev/null || fail "handoff task should complete after target acceptance"
[[ -f "$handoff_done_file" ]] || fail "accepted handoff should move task to done"
yq e -r '.dispatch.status' "$handoff_file" | grep '^accepted$' >/dev/null || fail "handoff should persist accepted dispatch status"
yq e -r '.dispatch.accepted_by_session_id' "$handoff_file" | grep '^SESSION-HANDOFF-001$' >/dev/null || fail "handoff should persist accepted session id"
grep "^handoff_id=$handoff_id\$" "$handoff_launch_log" >/dev/null || fail "fake launcher should receive handoff id"
grep "^handoff_file=$handoff_file\$" "$handoff_launch_log" >/dev/null || fail "fake launcher should receive handoff file"
env "SPINE_INBOX=$tmp/runtime/inbox" "SPINE_OUTBOX=$tmp/runtime/outbox" "SPINE_STATE=$tmp/runtime/state" "SPINE_LOGS=$tmp/runtime/logs" "$HANDOFF_CLOSE_BIN" \
  --id "$handoff_id" \
  --note "dispatch acknowledged by target terminal" >/dev/null
pass "accepted handoff completes only after target acceptance"

rm -f "$tmp/runtime/state/agent-tasks/queued/"*.yaml "$tmp/runtime/state/agent-tasks/running/"*.yaml "$tmp/runtime/state/agent-tasks/done/"*.yaml "$tmp/runtime/state/agent-tasks/failed/"*.yaml 2>/dev/null || true
rm -f "$tmp/runtime/state/handoffs/"*.yaml 2>/dev/null || true

handoff_no_accept_json="$(create_handoff "Bounded worker: launched handoff must not complete without acceptance" "LOOP-HANDOFF-NO-ACCEPT")"
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
yq e -r '.dispatch.status' "$handoff_no_accept_file" | grep '^failed$' >/dev/null || fail "handoff without acceptance should persist failed dispatch status"
yq e -r '.dispatch.last_error' "$handoff_no_accept_file" | grep 'handoff_accept_timeout' >/dev/null || fail "handoff without acceptance should record accept timeout reason"
pass "launched handoff without acceptance fails cleanly"

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

handoff_timeout_json="$(create_handoff "Bounded worker: launcher timeout should fail task not worker" "LOOP-HANDOFF-LAUNCH-TIMEOUT")"
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

echo "task worker handoff dispatch tests"

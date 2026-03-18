#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
ENSURE_BIN="$ROOT/ops/plugins/infra/mailroom-bridge/bin/mailroom-runtime-ensure"
RECONCILE_BIN="$ROOT/ops/plugins/core/handoff/bin/session-handoff-task-reconcile"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || fail "jq required"
command -v yq >/dev/null 2>&1 || fail "yq required"
[[ -x "$ENSURE_BIN" ]] || fail "ensure script missing or not executable"
[[ -x "$RECONCILE_BIN" ]] || fail "reconcile script missing or not executable"

tmp="$(mktemp -d)"
cleanup() {
  if [[ -f "$tmp/runtime/state/mailroom-task-worker.pid" ]]; then
    pid="$(cat "$tmp/runtime/state/mailroom-task-worker.pid" 2>/dev/null || true)"
    if [[ -n "${pid:-}" ]]; then
      kill "$pid" >/dev/null 2>&1 || true
    fi
  fi
  rm -rf "$tmp"
}
trap cleanup EXIT

mkdir -p "$tmp/runtime/mailroom/inbox" "$tmp/runtime/mailroom/outbox" "$tmp/runtime/state/agent-tasks/queued" "$tmp/runtime/state/agent-tasks/running" "$tmp/runtime/state/agent-tasks/failed" "$tmp/runtime/state/handoffs" "$tmp/runtime/logs" "$tmp/bin"

cat >"$tmp/ensure.contract.yaml" <<YAML
mounts:
  - id: mintfiles
    label: com.ronnyworks.mintfiles.mount
    mountpoint: $tmp/MinIO
    expected_entries:
      - artwork-intake
      - artwork-output
  - id: archives
    label: com.ronnyworks.archives.mount
    mountpoint: $tmp/Archives
    expected_entries:
      - mint-legacy
      - Legacy
watcher:
  label: com.ronny.agent-inbox
  restart_bin: fake-agent-restart
worker:
  bin: fake-worker
  fresh_tick_timeout_seconds: 5
  stale_status_seconds: 60
  status_file: \$SPINE_STATE/mailroom-task-worker.status.json
  pid_file: \$SPINE_STATE/mailroom-task-worker.pid
tasks:
  reconcile_bin: ops/plugins/core/handoff/bin/session-handoff-task-reconcile
  running_stale_seconds: 60
recovery:
  launchd_restart_bin: fake-launchd-restart
  launchctl_bin: fake-launchctl
YAML

cat >"$tmp/runtime/state/handoffs/HO-CLOSED-0001.yaml" <<YAML
version: "1.1"
id: HO-CLOSED-0001
state: closed
owner: tester
summary: "Closed handoff should complete queued task during ensure"
created_at_utc: "2026-03-12T15:00:00Z"
expires_at_utc: "2026-03-15T15:00:00Z"
closed_at_utc: "2026-03-12T15:10:00Z"
close_note: "finished"
loops:
  - LOOP-CLOSED-ENSURE
actions:
  - finish
from_role: researcher
to_role: worker
transition_gate: researcher_to_worker
input_refs:
  research_brief_ref: /tmp/plan.md#research-brief
  scope_ref: /tmp/plan.md#scope
output_refs:
  execution_plan_ref: /tmp/plan.md#execution-plan
  acceptance_criteria_ref: /tmp/plan.md#acceptance-criteria
notes: []
task_bridge:
  enabled: true
  task_id: TASK-HANDOFF-CLOSED-0001
  task_file: $tmp/runtime/state/agent-tasks/queued/TASK-HANDOFF-CLOSED-0001.yaml
  task_state: queued
  route_target: handoff
  required_agents:
    - flying-dutchman
YAML

cat >"$tmp/runtime/state/handoffs/HO-ACTIVE-0001.yaml" <<'YAML'
version: "1.1"
id: HO-ACTIVE-0001
state: active
owner: tester
summary: "Active handoff missing bridged task during ensure"
created_at_utc: "2026-03-12T15:00:00Z"
expires_at_utc: "2026-03-15T15:00:00Z"
loops:
  - LOOP-ACTIVE-ENSURE
actions:
  - recreate
from_role: researcher
to_role: worker
transition_gate: researcher_to_worker
input_refs:
  research_brief_ref: /tmp/plan.md#research-brief
  scope_ref: /tmp/plan.md#scope
output_refs:
  execution_plan_ref: /tmp/plan.md#execution-plan
  acceptance_criteria_ref: /tmp/plan.md#acceptance-criteria
notes: []
YAML

cat >"$tmp/runtime/state/agent-tasks/queued/TASK-HANDOFF-CLOSED-0001.yaml" <<'YAML'
task_id: TASK-HANDOFF-CLOSED-0001
status: queued
summary: closed handoff queued task
route_target: handoff
payload: '{"kind":"session_handoff","handoff_id":"HO-CLOSED-0001","to_role":"worker"}'
created_at: "2026-03-12T15:00:00Z"
updated_at: "2026-03-12T15:00:00Z"
required_agents: ["flying-dutchman"]
YAML

cat >"$tmp/runtime/state/agent-tasks/queued/TASK-HANDOFF-MISSING-0001.yaml" <<'YAML'
task_id: TASK-HANDOFF-MISSING-0001
status: queued
summary: orphan handoff task
route_target: handoff
payload: '{"kind":"session_handoff","handoff_id":"HO-MISSING-0001","to_role":"worker"}'
created_at: "2026-03-12T15:00:00Z"
updated_at: "2026-03-12T15:00:00Z"
required_agents: ["flying-dutchman"]
YAML

cat >"$tmp/runtime/state/agent-tasks/running/TASK-UNCLAIMED.yaml" <<'YAML'
task_id: TASK-UNCLAIMED
status: running
summary: reboot-leftover unclaimed task
claimed_at: "2026-03-12T15:00:00Z"
heartbeat_at: "2026-03-12T15:00:00Z"
updated_at: "2026-03-12T15:00:00Z"
YAML

cat >"$tmp/runtime/state/agent-tasks/running/TASK-CLAIMED.yaml" <<'YAML'
task_id: TASK-CLAIMED
status: running
summary: reboot-leftover claimed task
claimed_by: worker-1
claimed_at: "2026-03-12T15:00:00Z"
heartbeat_at: "2026-03-12T15:00:00Z"
updated_at: "2026-03-12T15:00:00Z"
YAML

cat >"$tmp/runtime/state/mailroom-task-worker.status.json" <<'JSON'
{"capability":"mailroom.task.worker.status","generated_at":"2026-03-09T19:15:55Z","status":"ok","data":{"cycle":{"status":"failed"},"tasks":{"claimed":0,"completed":0,"failed":1,"skipped":0}}}
JSON

STATE_FILE="$tmp/launchd-state.txt"
cat >"$STATE_FILE" <<'TXT'
com.ronnyworks.mintfiles.mount=stopped
com.ronnyworks.archives.mount=stopped
com.ronny.agent-inbox=stopped
TXT

cat >"$tmp/bin/fake-launchctl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
state_file="${FAKE_LAUNCHD_STATE:?}"
cmd="${1:-}"
target="${2:-}"
label="${target##*/}"
state="$(grep "^${label}=" "$state_file" 2>/dev/null | tail -n1 | cut -d= -f2- || true)"
if [[ "$cmd" == "print" && "$state" == "running" ]]; then
  cat <<EOF
gui/501/${label} = {
  active count = 1
  state = running

  program = /bin/bash
  pid = 1234

  resource coalition = {
    state = active
  }
}
EOF
  exit 0
fi
exit 1
SH

cat >"$tmp/bin/fake-launchd-restart" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
label=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --label) label="${2:?}"; shift 2 ;;
    *) shift ;;
  esac
done
state_file="${FAKE_LAUNCHD_STATE:?}"
tmp_file="${state_file}.tmp"
grep -v "^${label}=" "$state_file" >"$tmp_file" 2>/dev/null || true
echo "${label}=running" >>"$tmp_file"
mv "$tmp_file" "$state_file"
case "$label" in
  com.ronnyworks.mintfiles.mount)
    mkdir -p "${FAKE_MINTFILES_MOUNT:?}/artwork-intake" "${FAKE_MINTFILES_MOUNT:?}/artwork-output"
    ;;
  com.ronnyworks.archives.mount)
    mkdir -p "${FAKE_ARCHIVES_MOUNT:?}/mint-legacy" "${FAKE_ARCHIVES_MOUNT:?}/Legacy"
    ;;
esac
echo "recovery.launchd.restart"
echo "label: $label"
echo "result: success"
SH

cat >"$tmp/bin/fake-agent-restart" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
state_file="${FAKE_LAUNCHD_STATE:?}"
tmp_file="${state_file}.tmp"
grep -v '^com.ronny.agent-inbox=' "$state_file" >"$tmp_file" 2>/dev/null || true
echo 'com.ronny.agent-inbox=running' >>"$tmp_file"
mv "$tmp_file" "$state_file"
echo "spine.watcher.restart"
echo "status: running"
SH

cat >"$tmp/bin/fake-worker" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
status_file="${FAKE_WORKER_STATUS_FILE:?}"
pid_file="${FAKE_WORKER_PID_FILE:?}"
mode="${1:-}"
if [[ "$mode" == "--stop" ]]; then
  if [[ -f "$pid_file" ]]; then
    pid="$(cat "$pid_file")"
    kill "$pid" >/dev/null 2>&1 || true
    rm -f "$pid_file"
    echo "mailroom.task.worker: stopped pid=$pid"
  else
    echo "mailroom.task.worker: not running"
  fi
  exit 0
fi
if [[ "$mode" == "--daemon" ]]; then
  sleep 120 >/dev/null 2>&1 &
  pid=$!
  echo "$pid" >"$pid_file"
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  cat >"$status_file" <<JSON
{"capability":"mailroom.task.worker.status","generated_at":"$now","status":"ok","data":{"cycle":{"status":"ok"},"tasks":{"claimed":0,"completed":0,"failed":0,"skipped":0}}}
JSON
  echo "mailroom.task.worker"
  echo "  status: running"
  exit 0
fi
echo "unsupported mode: $*" >&2
exit 2
SH

chmod +x "$tmp/bin/fake-launchctl" "$tmp/bin/fake-launchd-restart" "$tmp/bin/fake-agent-restart" "$tmp/bin/fake-worker"

dry_run_json="$(FAKE_LAUNCHD_STATE="$STATE_FILE" FAKE_MINTFILES_MOUNT="$tmp/MinIO" FAKE_ARCHIVES_MOUNT="$tmp/Archives" FAKE_WORKER_STATUS_FILE="$tmp/runtime/state/mailroom-task-worker.status.json" FAKE_WORKER_PID_FILE="$tmp/runtime/state/mailroom-task-worker.pid" MAILROOM_RUNTIME_ENSURE_CONTRACT="$tmp/ensure.contract.yaml" MAILROOM_RUNTIME_ENSURE_LAUNCHCTL_BIN="$tmp/bin/fake-launchctl" MAILROOM_RUNTIME_ENSURE_RECOVERY_LAUNCHD_RESTART_BIN="$tmp/bin/fake-launchd-restart" MAILROOM_RUNTIME_ENSURE_AGENT_RESTART_BIN="$tmp/bin/fake-agent-restart" MAILROOM_RUNTIME_ENSURE_WORKER_BIN="$tmp/bin/fake-worker" SPINE_STATE="$tmp/runtime/state" SPINE_LOGS="$tmp/runtime/logs" SPINE_INBOX="$tmp/runtime/mailroom/inbox" SPINE_OUTBOX="$tmp/runtime/mailroom/outbox" "$ENSURE_BIN" --json --dry-run)"
echo "$dry_run_json" | jq -e '.status=="dry-run" and .data.worker.status=="dry-run" and .data.watcher.status=="dry-run" and .data.task_reconcile.status=="dry-run" and .data.task_reconcile.data.completed==1 and .data.task_reconcile.data.recreated==1 and .data.task_reconcile.data.orphan_failed==1 and .data.task_reconcile.data.stale_requeued==1 and .data.task_reconcile.data.stale_failed==1 and .data.summary.reconciled_count==0' >/dev/null || fail "dry-run should report pending queue-truth recovery actions without claiming reconciliation already happened"
[[ -f "$tmp/runtime/state/agent-tasks/running/TASK-UNCLAIMED.yaml" ]] || fail "dry-run should not mutate running tasks"
pass "runtime ensure dry-run reports reboot recovery actions without mutating state"

json_out="$(FAKE_LAUNCHD_STATE="$STATE_FILE" FAKE_MINTFILES_MOUNT="$tmp/MinIO" FAKE_ARCHIVES_MOUNT="$tmp/Archives" FAKE_WORKER_STATUS_FILE="$tmp/runtime/state/mailroom-task-worker.status.json" FAKE_WORKER_PID_FILE="$tmp/runtime/state/mailroom-task-worker.pid" MAILROOM_RUNTIME_ENSURE_CONTRACT="$tmp/ensure.contract.yaml" MAILROOM_RUNTIME_ENSURE_LAUNCHCTL_BIN="$tmp/bin/fake-launchctl" MAILROOM_RUNTIME_ENSURE_RECOVERY_LAUNCHD_RESTART_BIN="$tmp/bin/fake-launchd-restart" MAILROOM_RUNTIME_ENSURE_AGENT_RESTART_BIN="$tmp/bin/fake-agent-restart" MAILROOM_RUNTIME_ENSURE_WORKER_BIN="$tmp/bin/fake-worker" SPINE_STATE="$tmp/runtime/state" SPINE_LOGS="$tmp/runtime/logs" SPINE_INBOX="$tmp/runtime/mailroom/inbox" SPINE_OUTBOX="$tmp/runtime/mailroom/outbox" "$ENSURE_BIN" --json)"
echo "$json_out" | jq -e '.status=="ok" and .data.summary.restored_count>=4 and .data.summary.reconciled_count==5 and .data.task_reconcile.data.completed==1 and .data.task_reconcile.data.recreated==1 and .data.task_reconcile.data.orphan_failed==1 and .data.task_reconcile.data.stale_requeued==1 and .data.task_reconcile.data.stale_failed==1 and .data.worker.status=="restored" and .data.watcher.launchd_running==true and ([.data.mounts[].launchd_running] | all)' >/dev/null || fail "ensure should restore mounts, watcher, handoff/task drift, and worker"
[[ -d "$tmp/MinIO/artwork-intake" ]] || fail "mintfiles mount restore should recreate expected mount entries"
[[ -d "$tmp/Archives/mint-legacy" ]] || fail "archives mount restore should recreate expected mount entries"
[[ -f "$tmp/runtime/state/agent-tasks/queued/TASK-UNCLAIMED.yaml" ]] || fail "unclaimed stale task should be requeued"
[[ -f "$tmp/runtime/state/agent-tasks/failed/TASK-CLAIMED.yaml" ]] || fail "claimed stale task should be failed"
[[ -f "$tmp/runtime/state/agent-tasks/done/TASK-HANDOFF-CLOSED-0001.yaml" ]] || fail "closed handoff queued task should move to done during ensure"
[[ -f "$tmp/runtime/state/agent-tasks/queued/TASK-HANDOFF-ACTIVE-0001.yaml" ]] || fail "active handoff should recreate queued task during ensure"
[[ -f "$tmp/runtime/state/agent-tasks/failed/TASK-HANDOFF-MISSING-0001.yaml" ]] || fail "orphan handoff task should fail during ensure"
grep '^com.ronny.agent-inbox=running$' "$STATE_FILE" >/dev/null || fail "watcher restart should mark watcher launchd label running"
[[ -f "$tmp/runtime/state/mailroom-task-worker.pid" ]] || fail "worker restore should write pid file"
pass "runtime ensure restores canonical reboot state and queue truth end-to-end"

echo "mailroom-runtime-ensure tests"

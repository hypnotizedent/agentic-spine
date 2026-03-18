#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
CREATE_BIN="$ROOT/ops/plugins/core/handoff/bin/session-handoff-create"
CLOSE_BIN="$ROOT/ops/plugins/core/handoff/bin/session-handoff-close"
RECONCILE_BIN="$ROOT/ops/plugins/core/handoff/bin/session-handoff-task-reconcile"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || fail "jq required"
command -v yq >/dev/null 2>&1 || fail "yq required"
[[ -x "$CREATE_BIN" ]] || fail "create script missing or not executable"
[[ -x "$CLOSE_BIN" ]] || fail "close script missing or not executable"
[[ -x "$RECONCILE_BIN" ]] || fail "reconcile script missing or not executable"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/runtime/inbox" "$tmp/runtime/outbox" "$tmp/runtime/state/agent-tasks/queued" "$tmp/runtime/state/agent-tasks/running" "$tmp/runtime/state/agent-tasks/failed" "$tmp/runtime/state/agent-tasks/done" "$tmp/runtime/logs"

env_common=(
  "SPINE_INBOX=$tmp/runtime/inbox"
  "SPINE_OUTBOX=$tmp/runtime/outbox"
  "SPINE_STATE=$tmp/runtime/state"
  "SPINE_LOGS=$tmp/runtime/logs"
)

create_json="$(
  env "${env_common[@]}" "$CREATE_BIN" \
    --summary "Bounded worker: close should complete bridged task" \
    --loops "LOOP-CLOSE-TEST" \
    --actions "execute,close" \
    --owner tester \
    --from-role researcher \
    --to-role worker \
    --input-refs "research_brief_ref=/tmp/plan.md#research-brief,scope_ref=/tmp/plan.md#scope" \
    --output-refs "execution_plan_ref=/tmp/plan.md#execution-plan,acceptance_criteria_ref=/tmp/plan.md#acceptance-criteria" \
    --json
)"

handoff_id="$(echo "$create_json" | jq -r '.id')"
handoff_file="$(echo "$create_json" | jq -r '.file')"
queued_task_id="$(echo "$create_json" | jq -r '.task_bridge.task_id')"
queued_task_file="$(echo "$create_json" | jq -r '.task_bridge.task_file')"
[[ -f "$queued_task_file" ]] || fail "bridged queued task should exist before close"

env "${env_common[@]}" "$CLOSE_BIN" --id "$handoff_id" --note "worker completed bounded implementation" >/dev/null

done_task_file="$tmp/runtime/state/agent-tasks/done/${queued_task_id}.yaml"
[[ -f "$done_task_file" ]] || fail "closing handoff should move bridged task to done immediately"
[[ ! -f "$queued_task_file" ]] || fail "queued bridged task should be removed after close"
yq e -r '.task_bridge.task_state' "$handoff_file" | grep '^done$' >/dev/null || fail "handoff close should sync bridged task state to done"
pass "session-handoff-close updates bridged task state immediately"

manual_handoff_dir="$tmp/runtime/state/handoffs"
mkdir -p "$manual_handoff_dir"

cat >"$manual_handoff_dir/HO-CLOSED-0001.yaml" <<YAML
version: "1.1"
id: HO-CLOSED-0001
state: closed
owner: tester
summary: "Closed handoff should complete queued task"
created_at_utc: "2026-03-12T15:00:00Z"
expires_at_utc: "2026-03-15T15:00:00Z"
closed_at_utc: "2026-03-12T15:10:00Z"
close_note: "finished"
loops:
  - LOOP-CLOSED-TEST
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

cat >"$tmp/runtime/state/agent-tasks/queued/TASK-HANDOFF-CLOSED-0001.yaml" <<'YAML'
task_id: TASK-HANDOFF-CLOSED-0001
status: queued
summary: closed handoff task still queued
route_target: handoff
payload: '{"kind":"session_handoff","handoff_id":"HO-CLOSED-0001","to_role":"worker"}'
created_at: "2026-03-12T15:00:00Z"
updated_at: "2026-03-12T15:00:00Z"
required_agents: ["flying-dutchman"]
YAML

cat >"$manual_handoff_dir/HO-ACTIVE-0001.yaml" <<'YAML'
version: "1.1"
id: HO-ACTIVE-0001
state: active
owner: tester
summary: "Active handoff missing bridged task"
created_at_utc: "2026-03-12T15:00:00Z"
expires_at_utc: "2026-03-15T15:00:00Z"
loops:
  - LOOP-ACTIVE-TEST
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

cat >"$tmp/runtime/state/agent-tasks/queued/TASK-HANDOFF-MISSING-0001.yaml" <<'YAML'
task_id: TASK-HANDOFF-MISSING-0001
status: queued
summary: orphan bridged task
route_target: handoff
payload: '{"kind":"session_handoff","handoff_id":"HO-MISSING-0001","to_role":"worker"}'
created_at: "2026-03-12T15:00:00Z"
updated_at: "2026-03-12T15:00:00Z"
required_agents: ["flying-dutchman"]
YAML

cat >"$tmp/runtime/state/agent-tasks/running/TASK-STALE-UNCLAIMED.yaml" <<'YAML'
task_id: TASK-STALE-UNCLAIMED
status: running
summary: stale unclaimed running task
claimed_at: "2026-03-12T15:00:00Z"
heartbeat_at: "2026-03-12T15:00:00Z"
updated_at: "2026-03-12T15:00:00Z"
YAML

cat >"$tmp/runtime/state/agent-tasks/running/TASK-STALE-CLAIMED.yaml" <<'YAML'
task_id: TASK-STALE-CLAIMED
status: running
summary: stale claimed running task
claimed_by: dutchman
claimed_at: "2026-03-12T15:00:00Z"
heartbeat_at: "2026-03-12T15:00:00Z"
updated_at: "2026-03-12T15:00:00Z"
YAML

json_out="$(
  env "${env_common[@]}" "$RECONCILE_BIN" --json --running-stale-seconds 60
)"

echo "$json_out" | jq -e '.status=="ok" and .data.completed==1 and .data.recreated==1 and .data.orphan_failed==1 and .data.stale_requeued==1 and .data.stale_failed==1' >/dev/null || fail "reconciler should cover closed handoff completion, active handoff recreation, orphan task failure, and stale running policy"
[[ -f "$tmp/runtime/state/agent-tasks/done/TASK-HANDOFF-CLOSED-0001.yaml" ]] || fail "closed handoff queued task should move to done"
[[ -f "$tmp/runtime/state/agent-tasks/queued/TASK-HANDOFF-ACTIVE-0001.yaml" ]] || fail "active handoff should recreate queued bridged task"
[[ -f "$tmp/runtime/state/agent-tasks/failed/TASK-HANDOFF-MISSING-0001.yaml" ]] || fail "orphan handoff task should fail"
[[ -f "$tmp/runtime/state/agent-tasks/queued/TASK-STALE-UNCLAIMED.yaml" ]] || fail "stale unclaimed running task should requeue"
[[ -f "$tmp/runtime/state/agent-tasks/failed/TASK-STALE-CLAIMED.yaml" ]] || fail "stale claimed running task should fail"
yq e -r '.task_bridge.task_state' "$manual_handoff_dir/HO-CLOSED-0001.yaml" | grep '^done$' >/dev/null || fail "closed handoff should sync done state back into task bridge"
yq e -r '.task_bridge.task_id' "$manual_handoff_dir/HO-ACTIVE-0001.yaml" | grep '^TASK-HANDOFF-ACTIVE-0001$' >/dev/null || fail "active handoff should persist recreated task id"
pass "session-handoff-task-reconcile repairs handoff/task drift and stale running tasks"

echo "session handoff task reconcile tests"

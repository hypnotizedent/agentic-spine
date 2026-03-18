#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
CREATE_BIN="$ROOT/ops/plugins/core/handoff/bin/session-handoff-create"
BRIDGE_BIN="$ROOT/ops/plugins/core/handoff/bin/session-handoff-task-bridge"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || fail "jq required"
command -v yq >/dev/null 2>&1 || fail "yq required"
[[ -x "$CREATE_BIN" ]] || fail "create script missing or not executable"
[[ -x "$BRIDGE_BIN" ]] || fail "task bridge script missing or not executable"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/runtime/inbox" "$tmp/runtime/outbox" "$tmp/runtime/state" "$tmp/runtime/logs"

env_common=(
  "SPINE_INBOX=$tmp/runtime/inbox"
  "SPINE_OUTBOX=$tmp/runtime/outbox"
  "SPINE_STATE=$tmp/runtime/state"
  "SPINE_LOGS=$tmp/runtime/logs"
)

create_json="$(
  env "${env_common[@]}" "$CREATE_BIN" \
    --summary "Bounded worker: test handoff task bridge" \
    --loops "LOOP-TEST-HANDOFF" \
    --actions "classify,dispatch" \
    --owner tester \
    --from-role researcher \
    --to-role worker \
    --input-refs "research_brief_ref=/tmp/plan.md#research-brief,scope_ref=/tmp/plan.md#scope" \
    --output-refs "execution_plan_ref=/tmp/plan.md#execution-plan,acceptance_criteria_ref=/tmp/plan.md#acceptance-criteria" \
    --json
)"

handoff_id="$(echo "$create_json" | jq -r '.id')"
handoff_file="$(echo "$create_json" | jq -r '.file')"
task_id="$(echo "$create_json" | jq -r '.task_bridge.task_id')"
task_file="$(echo "$create_json" | jq -r '.task_bridge.task_file')"

[[ -f "$handoff_file" ]] || fail "handoff file should exist"
[[ -f "$task_file" ]] || fail "queued task file should exist"
[[ "$task_id" == "TASK-HANDOFF-${handoff_id#HO-}" ]] || fail "task id should be derived from handoff id"

yq e -r '.route_target' "$task_file" | grep '^handoff$' >/dev/null || fail "task route_target should be handoff"
yq e -r '.required_agents[0]' "$task_file" | grep '^flying-dutchman$' >/dev/null || fail "task required agent should default to flying-dutchman"
yq e -r '.payload' "$task_file" | jq -e --arg handoff_id "$handoff_id" '.kind=="session_handoff" and .handoff_id==$handoff_id and .to_role=="worker" and .dispatch.target_agent_id=="flying-dutchman" and (.required_agents | index("flying-dutchman") != null)' >/dev/null || fail "task payload should preserve handoff metadata and dispatch target"
yq e -r '.task_bridge.task_id' "$handoff_file" | grep "^$task_id\$" >/dev/null || fail "handoff should persist bridged task id"
pass "session-handoff-create auto-bridges worker handoffs into queued tasks"

manual_handoff_dir="$tmp/runtime/state/handoffs"
manual_handoff_file="$manual_handoff_dir/HO-MANUAL-0001.yaml"
mkdir -p "$manual_handoff_dir"
cat >"$manual_handoff_file" <<'YAML'
version: "1.1"
id: HO-MANUAL-0001
state: active
owner: tester
summary: "Bounded worker: backfill idle handoff"
created_at_utc: "2026-03-12T15:00:00Z"
expires_at_utc: "2026-03-15T15:00:00Z"
loops:
  - LOOP-MANUAL-TEST
actions:
  - backfill
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

bridge_json="$(env "${env_common[@]}" "$BRIDGE_BIN" --id HO-MANUAL-0001 --json)"
manual_task_id="$(echo "$bridge_json" | jq -r '.data.task_id')"
manual_task_file="$(echo "$bridge_json" | jq -r '.data.task_file')"

[[ -f "$manual_task_file" ]] || fail "manual bridge should create queued task file"
yq e -r '.task_bridge.task_id' "$manual_handoff_file" | grep "^$manual_task_id\$" >/dev/null || fail "manual handoff should persist bridged task id"
pass "session-handoff-task-bridge backfills existing idle handoffs"

echo "session handoff task bridge tests"

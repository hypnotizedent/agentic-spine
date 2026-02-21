#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)}"
BIN="$ROOT/ops/plugins/mailroom-bridge/bin/mailroom-task-worker"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || fail "jq required"
[[ -x "$BIN" ]] || fail "worker script missing or not executable"

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

once_json="$(env "${worker_env[@]}" "$BIN" --once)"
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

echo "mailroom-task-worker tests"

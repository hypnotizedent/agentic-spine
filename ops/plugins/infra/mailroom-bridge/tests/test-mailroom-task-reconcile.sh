#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
BIN="$ROOT/ops/plugins/infra/mailroom-bridge/bin/mailroom-task-reconcile"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || fail "jq required"
command -v yq >/dev/null 2>&1 || fail "yq required"
[[ -x "$BIN" ]] || fail "reconcile script missing or not executable"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/runtime/state/agent-tasks/queued" "$tmp/runtime/state/agent-tasks/running" "$tmp/runtime/state/agent-tasks/failed" "$tmp/runtime/logs"

cat >"$tmp/runtime/state/agent-tasks/running/TASK-UNCLAIMED.yaml" <<'YAML'
task_id: TASK-UNCLAIMED
status: running
summary: stale unclaimed
claimed_at: "2026-03-12T15:00:00Z"
heartbeat_at: "2026-03-12T15:00:00Z"
updated_at: "2026-03-12T15:00:00Z"
YAML

cat >"$tmp/runtime/state/agent-tasks/running/TASK-CLAIMED.yaml" <<'YAML'
task_id: TASK-CLAIMED
status: running
summary: stale claimed
claimed_by: dutchman
claimed_at: "2026-03-12T15:00:00Z"
heartbeat_at: "2026-03-12T15:00:00Z"
updated_at: "2026-03-12T15:00:00Z"
YAML

json_out="$(SPINE_STATE="$tmp/runtime/state" SPINE_LOGS="$tmp/runtime/logs" "$BIN" --json --stale-seconds 60)"
echo "$json_out" | jq -e '.status=="ok" and .data.requeued==1 and .data.failed==1' >/dev/null || fail "reconcile should requeue one task and fail one task"
[[ -f "$tmp/runtime/state/agent-tasks/queued/TASK-UNCLAIMED.yaml" ]] || fail "unclaimed stale task should move back to queued"
[[ -f "$tmp/runtime/state/agent-tasks/failed/TASK-CLAIMED.yaml" ]] || fail "claimed stale task should move to failed"
yq e -r '.requeue_reason' "$tmp/runtime/state/agent-tasks/queued/TASK-UNCLAIMED.yaml" | grep 'stale_running_reconciled:unclaimed' >/dev/null || fail "queued task should record reconcile reason"
yq e -r '.failure_reason' "$tmp/runtime/state/agent-tasks/failed/TASK-CLAIMED.yaml" | grep '^stale_running_reconciled:' >/dev/null || fail "failed task should record stale-running failure reason"
pass "stale running tasks reconcile into queued/failed buckets"

rm -f "$tmp/runtime/state/agent-tasks/queued/"*.yaml "$tmp/runtime/state/agent-tasks/failed/"*.yaml 2>/dev/null || true
mkdir -p "$tmp/runtime/state/agent-tasks/running"
cat >"$tmp/runtime/state/agent-tasks/running/TASK-DRYRUN.yaml" <<'YAML'
task_id: TASK-DRYRUN
status: running
summary: dry-run stale task
claimed_at: "2026-03-12T15:00:00Z"
heartbeat_at: "2026-03-12T15:00:00Z"
updated_at: "2026-03-12T15:00:00Z"
YAML

dry_run="$(SPINE_STATE="$tmp/runtime/state" SPINE_LOGS="$tmp/runtime/logs" "$BIN" --json --stale-seconds 60 --dry-run)"
echo "$dry_run" | jq -e '.status=="dry-run" and .data.requeued==1' >/dev/null || fail "dry-run should report reconcile action"
[[ -f "$tmp/runtime/state/agent-tasks/running/TASK-DRYRUN.yaml" ]] || fail "dry-run should not mutate task files"
pass "dry-run reports stale task reconciliation without mutating files"

echo "mailroom-task-reconcile tests"

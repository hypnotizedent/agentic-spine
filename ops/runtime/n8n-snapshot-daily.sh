#!/usr/bin/env bash
set -euo pipefail

# Scheduled runner: n8n workflow snapshot at 03:00 daily
# LaunchAgent: com.ronny.n8n-snapshot-daily
# Gaps: GAP-OP-738

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CAP_RUNNER="${SPINE_ROOT}/bin/ops"
source "${SPINE_ROOT}/ops/runtime/lib/job-wrapper.sh"

run_n8n_snapshot_guarded() {
  local tmp rc
  tmp="$(mktemp)"

  set +e
  "$CAP_RUNNER" cap run n8n.workflows.snapshot >"$tmp" 2>&1
  rc=$?
  set -e

  cat "$tmp"

  # Scheduled lane should not hard-fail when proactive mutation guard blocks
  # execution. Guard state is handled in the stability lane.
  if [[ "$rc" -eq 3 ]] && grep -q 'BLOCKED: proactive mutation guard' "$tmp"; then
    echo "[n8n-snapshot-daily] WARN proactive mutation guard blocked snapshot; deferring to stability lane."
    rm -f "$tmp"
    return 0
  fi

  rm -f "$tmp"
  return "$rc"
}

echo "[n8n-snapshot-daily] start $(date -u +%Y-%m-%dT%H:%M:%SZ)"

spine_job_run \
  "n8n-snapshot-daily:n8n.workflows.snapshot" \
  run_n8n_snapshot_guarded

echo "[n8n-snapshot-daily] done $(date -u +%Y-%m-%dT%H:%M:%SZ)"

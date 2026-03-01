#!/usr/bin/env bash
# TRIAGE: Keep monitored scheduled LaunchAgents running within cadence using runtime telemetry recency checks.
# D299: launchd scheduler recency lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
STATUS_SCRIPT="$ROOT/ops/plugins/host/bin/launchd-scheduler-health-status"

fail() {
  echo "D299 FAIL: $*" >&2
  exit 1
}

[[ -x "$STATUS_SCRIPT" ]] || fail "missing scheduler status script: $STATUS_SCRIPT"
command -v jq >/dev/null 2>&1 || fail "missing dependency: jq"

payload="$($STATUS_SCRIPT --json 2>/dev/null || true)"
[[ -n "$payload" ]] || fail "scheduler status returned empty payload"

status="$(jq -r '.status // "unknown"' <<<"$payload" 2>/dev/null || echo "unknown")"
stale="$(jq -r '.data.summary.stale // 0' <<<"$payload" 2>/dev/null || echo "0")"
failed="$(jq -r '.data.summary.failed // 0' <<<"$payload" 2>/dev/null || echo "0")"
unknown="$(jq -r '.data.summary.unknown // 0' <<<"$payload" 2>/dev/null || echo "0")"
total="$(jq -r '.data.summary.total // 0' <<<"$payload" 2>/dev/null || echo "0")"
stale_labels="$(jq -r '.data.stale_labels // [] | join(", ")' <<<"$payload" 2>/dev/null || true)"
failed_labels="$(jq -r '.data.failed_labels // [] | join(", ")' <<<"$payload" 2>/dev/null || true)"

if [[ "$status" == "error" || "$failed" -gt 0 || "$stale" -gt 0 ]]; then
  fail "scheduler drift status=${status} total=${total} stale=${stale} failed=${failed} unknown=${unknown} stale_labels=${stale_labels:-none} failed_labels=${failed_labels:-none}"
fi

echo "D299 PASS: scheduler recency healthy (status=${status} total=${total} stale=${stale} failed=${failed} unknown=${unknown})"

#!/usr/bin/env bash
set -euo pipefail

# Scheduled runner: domain inventory observed-feed refresh
# LaunchAgent template: com.ronny.domain-inventory-refresh-daily
# W69 freshness recovery: D188

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CAP_RUNNER="$SPINE_ROOT/bin/ops"
source "${SPINE_ROOT}/ops/runtime/lib/job-wrapper.sh"

echo "[domain-inventory-refresh-daily] start $(date -u +%Y-%m-%dT%H:%M:%SZ)"

spine_job_run \
  "domain-inventory-refresh-daily:domain-inventory-refresh" \
  "$CAP_RUNNER" cap run domain-inventory-refresh -- --once

echo "[domain-inventory-refresh-daily] done $(date -u +%Y-%m-%dT%H:%M:%SZ)"

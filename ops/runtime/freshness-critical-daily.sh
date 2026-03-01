#!/usr/bin/env bash
set -euo pipefail

# Scheduled runner: refresh critical 24h freshness surfaces.
# Covers gates: D192, D193, D194, D205, D208 (+ D104 freshness support).
# LaunchAgent: com.ronny.freshness-critical-daily

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CAP_RUNNER="${SPINE_ROOT}/bin/ops"
source "${SPINE_ROOT}/ops/runtime/lib/job-wrapper.sh"

failures=0
declare -a failed_caps=()

run_cap() {
  local cap="$1"
  if spine_job_run "freshness-critical-daily:${cap}" "$CAP_RUNNER" cap run "$cap"; then
    return 0
  fi
  local rc=$?
  failures=$((failures + 1))
  failed_caps+=("${cap}(rc=${rc})")
  echo "[freshness-critical-daily] WARN ${cap} failed rc=${rc}" >&2
  return 0
}

echo "[freshness-critical-daily] start $(date -u +%Y-%m-%dT%H:%M:%SZ)"

run_cap media-content-snapshot-refresh
run_cap ha-inventory-snapshot-build
run_cap network-inventory-snapshot-build
run_cap ha.z2m.devices.snapshot
run_cap network.home.dhcp.audit
run_cap calendar.external.ingest.refresh
run_cap calendar.ha.ingest.refresh
run_cap infra.storage.audit.snapshot
run_cap cloudflare.inventory.sync
run_cap verify.freshness.reconcile

if (( failures > 0 )); then
  spine_enqueue_email_intent \
    "freshness-critical" \
    "incident" \
    "freshness-critical-daily had refresh failures" \
    "failures=${failures}; failed_capabilities=${failed_caps[*]}" \
    "freshness-critical-daily"
  echo "[freshness-critical-daily] done with failures=$((${failures})) $(date -u +%Y-%m-%dT%H:%M:%SZ)" >&2
  exit 1
fi

echo "[freshness-critical-daily] done $(date -u +%Y-%m-%dT%H:%M:%SZ)"

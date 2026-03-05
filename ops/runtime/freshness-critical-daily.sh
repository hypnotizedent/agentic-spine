#!/usr/bin/env bash
set -euo pipefail

# Scheduled runner: refresh critical 24h freshness surfaces.
# Covers gates: D192, D193, D194, D205, D208 (+ D104 freshness support).
# LaunchAgent: com.ronny.freshness-critical-daily

CONTROL_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
source "${CONTROL_ROOT}/ops/runtime/lib/runtime-managed-worktree.sh"
RUNTIME_ROOT="$(spine_runtime_prepare_managed_worktree "$CONTROL_ROOT")"
CAP_RUNNER="${RUNTIME_ROOT}/bin/ops"
source "${RUNTIME_ROOT}/ops/runtime/lib/job-wrapper.sh"

failures=0
declare -a failed_caps=()

run_cap() {
  local cap="$1"
  shift || true
  if spine_job_run "freshness-critical-daily:${cap}" "$CAP_RUNNER" cap run "$cap" "$@"; then
    return 0
  fi
  local rc=$?
  failures=$((failures + 1))
  failed_caps+=("${cap}(rc=${rc})")
  echo "[freshness-critical-daily] WARN ${cap} failed rc=${rc}" >&2
  return 0
}

echo "[freshness-critical-daily] start $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "[freshness-critical-daily] control_root=${CONTROL_ROOT}"
echo "[freshness-critical-daily] runtime_root=${RUNTIME_ROOT}"
echo "[freshness-critical-daily] worktree_identity=${OPS_WORKTREE_IDENTITY:-unset}"

run_cap media-content-snapshot-refresh -- --apply
run_cap ha-inventory-snapshot-build -- --apply
run_cap network-inventory-snapshot-build -- --apply
run_cap ha.z2m.devices.snapshot -- --apply
run_cap network.home.dhcp.audit -- --apply
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

#!/usr/bin/env bash
set -euo pipefail

# Scheduled runner: refresh critical 24h freshness surfaces.
# Covers gates: D192, D193, D194, D205, D208 (+ D104 freshness support).
# LaunchAgent: com.ronny.freshness-critical-daily

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CAP_RUNNER="${SPINE_ROOT}/bin/ops"

echo "[freshness-critical-daily] start $(date -u +%Y-%m-%dT%H:%M:%SZ)"

"$CAP_RUNNER" cap run media-content-snapshot-refresh
"$CAP_RUNNER" cap run ha-inventory-snapshot-build
"$CAP_RUNNER" cap run network-inventory-snapshot-build
"$CAP_RUNNER" cap run ha.z2m.devices.snapshot
"$CAP_RUNNER" cap run network.home.dhcp.audit
"$CAP_RUNNER" cap run calendar.external.ingest.refresh
"$CAP_RUNNER" cap run calendar.ha.ingest.refresh
"$CAP_RUNNER" cap run infra.storage.audit.snapshot
"$CAP_RUNNER" cap run cloudflare.inventory.sync
"$CAP_RUNNER" cap run verify.freshness.reconcile

echo "[freshness-critical-daily] done $(date -u +%Y-%m-%dT%H:%M:%SZ)"

#!/usr/bin/env bash
set -euo pipefail

# Scheduled runner: alerting probe + dispatch every 15 minutes
# LaunchAgent: com.ronny.alerting-probe-cycle
# Gaps: GAP-OP-740

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CAP_RUNNER="${SPINE_ROOT}/bin/ops"

echo "[alerting-probe-cycle] start $(date -u +%Y-%m-%dT%H:%M:%SZ)"

"$CAP_RUNNER" cap run alerting.probe
"$CAP_RUNNER" cap run alerting.dispatch

echo "[alerting-probe-cycle] done $(date -u +%Y-%m-%dT%H:%M:%SZ)"

#!/usr/bin/env bash
set -euo pipefail

# Scheduled runner: SLO evidence collection at 23:59
# LaunchAgent: com.ronny.slo-evidence-daily
# Gaps: GAP-OP-736

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CAP_RUNNER="${SPINE_ROOT}/bin/ops"

echo "[slo-evidence-daily] start $(date -u +%Y-%m-%dT%H:%M:%SZ)"

"$CAP_RUNNER" cap run slo.evidence.daily

echo "[slo-evidence-daily] done $(date -u +%Y-%m-%dT%H:%M:%SZ)"

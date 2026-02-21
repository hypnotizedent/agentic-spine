#!/usr/bin/env bash
set -euo pipefail

# Scheduled runner: n8n workflow snapshot at 03:00 daily
# LaunchAgent: com.ronny.n8n-snapshot-daily
# Gaps: GAP-OP-738

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CAP_RUNNER="${SPINE_ROOT}/bin/ops"

echo "[n8n-snapshot-daily] start $(date -u +%Y-%m-%dT%H:%M:%SZ)"

"$CAP_RUNNER" cap run n8n.workflows.snapshot

echo "[n8n-snapshot-daily] done $(date -u +%Y-%m-%dT%H:%M:%SZ)"

#!/usr/bin/env bash
set -euo pipefail

# Scheduled runner: extension transaction index refresh
# LaunchAgent template: com.ronny.extension-index-refresh-daily
# W69 freshness recovery: D178

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CAP_RUNNER="$SPINE_ROOT/bin/ops"

echo "[extension-index-refresh-daily] start $(date -u +%Y-%m-%dT%H:%M:%SZ)"

"$CAP_RUNNER" cap run platform.extension.index.build

echo "[extension-index-refresh-daily] done $(date -u +%Y-%m-%dT%H:%M:%SZ)"

#!/usr/bin/env bash
set -euo pipefail

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CAP_RUNNER="$SPINE_ROOT/bin/ops"
CHECKSUM="$SPINE_ROOT/ops/plugins/evidence/bin/receipts-checksum-parity-report"

echo "[receipts-archive-reconcile-daily] start $(date -u +%Y-%m-%dT%H:%M:%SZ)"

"$CAP_RUNNER" cap run receipts.index.build
"$CHECKSUM"
"$CAP_RUNNER" cap run receipts.rotate -- --execute

echo "[receipts-archive-reconcile-daily] done $(date -u +%Y-%m-%dT%H:%M:%SZ)"

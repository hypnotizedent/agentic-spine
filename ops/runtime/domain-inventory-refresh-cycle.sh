#!/usr/bin/env bash
set -euo pipefail

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
OPS_BIN="$SPINE_ROOT/bin/ops"
source "${SPINE_ROOT}/ops/runtime/lib/job-wrapper.sh"

if [[ ! -x "$OPS_BIN" ]]; then
  echo "[domain-inventory-refresh-cycle] STOP: missing ops runner at $OPS_BIN" >&2
  exit 2
fi

echo "[domain-inventory-refresh-cycle] start $(date -u +%Y-%m-%dT%H:%M:%SZ)"
spine_job_run \
  "domain-inventory-refresh-cycle:domain-inventory-refresh" \
  "$OPS_BIN" cap run domain-inventory-refresh -- --loop --interval-min 30

#!/usr/bin/env bash
# Gate: D391 assertion-health-strictness-lock
# Category: process-hygiene
# Ring: standard
# Severity: medium
#
# Assertion-grade automation surfaces must call health/status capabilities in
# strict mode so failed health checks propagate as failed automation.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${SPINE_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
LANE_SCRIPT="$ROOT/ops/plugins/lifecycle/bin/lane-standard-run"
MINT_LOOP="$ROOT/ops/plugins/mint/bin/loop-daily"
SERVICES_STATUS="$ROOT/ops/plugins/infra/services/bin/services-health-status"
MINT_STATUS="$ROOT/ops/plugins/mint/bin/modules-health"

fail() {
  echo "D391 FAIL: $*" >&2
  exit 1
}

for file in "$LANE_SCRIPT" "$MINT_LOOP" "$SERVICES_STATUS" "$MINT_STATUS"; do
  [[ -f "$file" ]] || fail "missing file: $file"
done

rg -q 'run_phase "services.health.status" services.health.status --strict-exit' "$LANE_SCRIPT" \
  || fail "lane-standard-run does not call services.health.status with --strict-exit"

rg -q 'run_step "mint.modules.health" mint.modules.health --strict-exit' "$MINT_LOOP" \
  || fail "mint loop-daily does not call mint.modules.health with --strict-exit"

rg -q -- '--strict-exit' "$SERVICES_STATUS" \
  || fail "services-health-status lacks strict-exit support"

rg -q -- '--strict-exit' "$MINT_STATUS" \
  || fail "modules-health lacks strict-exit support"

echo "D391 PASS: assertion-grade health automation uses strict-exit semantics"
exit 0

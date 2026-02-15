#!/usr/bin/env bash
# aof-verify — Run AOF product gates (D91-D97).
set -euo pipefail

SP="${SPINE_ROOT:-${SPINE_CODE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)}}"

echo "═══════════════════════════════════════"
echo "  AOF VERIFY (product gates)"
echo "═══════════════════════════════════════"
echo ""

FAIL=0
PASS_COUNT=0
SKIP=0

run_gate() {
  local script="$1"
  local gate_id="$2"
  local desc="$3"

  if [[ ! -f "$script" ]]; then
    echo "SKIP $gate_id $desc (script not found)"
    SKIP=$((SKIP + 1))
    return
  fi

  echo -n "$gate_id $desc... "
  local tmp rc
  tmp="$(mktemp)"
  set +e
  bash "$script" >"$tmp" 2>&1
  rc=$?
  set -e

  if [[ "$rc" -eq 0 ]]; then
    echo "PASS"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "FAIL (rc=$rc)"
    FAIL=$((FAIL + 1))
    sed -n '1,20p' "$tmp" | sed 's/^/  /' || true
  fi
  rm -f "$tmp" 2>/dev/null || true
}

run_gate "$SP/surfaces/verify/d91-aof-product-foundation-lock.sh"    "D91" "product foundation lock"
run_gate "$SP/surfaces/verify/d92-ha-config-version-control.sh"      "D92" "HA config version control"
run_gate "$SP/surfaces/verify/d93-tenant-storage-boundary-lock.sh"   "D93" "tenant storage boundary"
run_gate "$SP/surfaces/verify/d94-policy-runtime-enforcement-lock.sh" "D94" "policy runtime enforcement"
run_gate "$SP/surfaces/verify/d95-version-compat-matrix-lock.sh"     "D95" "version compat matrix"
run_gate "$SP/surfaces/verify/d96-evidence-retention-policy-lock.sh" "D96" "evidence retention policy"
run_gate "$SP/surfaces/verify/d97-surface-readonly-contract-lock.sh" "D97" "surface readonly contract"

echo ""
echo "───────────────────────────────────────"
echo "Results: $PASS_COUNT passed, $FAIL failed, $SKIP skipped"
echo "═══════════════════════════════════════"

exit "$FAIL"

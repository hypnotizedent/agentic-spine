#!/usr/bin/env bash
set -euo pipefail

# TRIAGE: D393 mint-status-consumer-projection-lock
# Ring: standard
# Description: Enforce Mint status consumers use governed projection, not ad hoc proof/planning docs
# Rationale: Prevent status consumer drift to manual truth or expensive re-runs

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${SPINE_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

WORKBENCH="${WORKBENCH_ROOT:-$HOME/code/workbench}"
MINT_MODULES="${MINT_MODULES_ROOT:-$HOME/code/mint-modules}"

check_count=0
fail_count=0

check() {
  local name="$1"
  local cmd="$2"
  ((check_count++)) || true
  if eval "$cmd"; then
    echo "  ✓ $name"
  else
    echo "  ✗ $name"
    ((fail_count++)) || true
  fi
}

echo "════════════════════════════════════════"
echo "D393: mint-status-consumer-projection-lock"
echo "════════════════════════════════════════"
echo

# Check 1: Projection file exists and is authoritative
check "projection exists" "[[ -f '$ROOT/ops/bindings/mint.module.status.projected.yaml' ]]"

# Check 2: mint.module.status.show capability exists
check "show capability exists" "grep -q 'mint.module.status.show:' '$ROOT/ops/capabilities.yaml'"

# Check 3: mint-modules-ops.sh status uses projection
check "mint-modules-ops.sh uses projection" "grep -q 'mint.module.status.show' '$WORKBENCH/scripts/root/operator/mint-modules-ops.sh'"

# Check 4: flying-dutchman.sh status uses projection
check "flying-dutchman.sh uses projection" "grep -q 'mint.module.status.show' '$WORKBENCH/scripts/root/operator/flying-dutchman.sh'"

# Check 5: Domain doc points to projection authority
check "domain doc cites projection" "grep -q 'mint.module.status.projected.yaml' '$ROOT/docs/governance/domains/mint.md'"

# Check 6: Authority contract exists and is valid
check "authority contract exists" "[[ -f '$ROOT/ops/bindings/mint.module.status.authority.contract.yaml' ]]"

# Check 7: Authority contract marks planning docs as non-authoritative
check "authority forbids planning docs" "grep -q 'do_not_use_for_operational_truth' '$ROOT/ops/bindings/mint.module.status.authority.contract.yaml'"

# Check 8: mint-modules-ops.sh does NOT call mint.runtime.proof in status command
check "mint-modules-ops.sh status avoids proof" "! grep -A5 'cmd_status()' '$WORKBENCH/scripts/root/operator/mint-modules-ops.sh' | grep -q 'mint.runtime.proof'"

# Check 9: flying-dutchman.sh distinguishes status (projection) from proof (deep)
check "flying-dutchman distinguishes status/proof" "grep -A2 'status)' '$WORKBENCH/scripts/root/operator/flying-dutchman.sh' | grep -q 'mint.module.status.show'"

# Check 10: Capability map includes show capability
check "capability map has show" "grep -q 'mint.module.status.show:' '$ROOT/ops/bindings/capability_map.yaml'"

echo
if [[ $fail_count -eq 0 ]]; then
  echo "PASS ($check_count/$check_count)"
  exit 0
else
  echo "FAIL ($((check_count - fail_count))/$check_count)"
  exit 1
fi

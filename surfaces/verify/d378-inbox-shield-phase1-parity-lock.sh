#!/usr/bin/env bash
# d378-inbox-shield-phase1-parity-lock.sh
# TRIAGE: inbox-shield Phase 1 governance parity
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PASS=0
FAIL=0
TOTAL=0

check() {
  TOTAL=$((TOTAL + 1))
  if eval "$2"; then
    echo "  PASS [$1]"
    PASS=$((PASS + 1))
  else
    echo "  FAIL [$1] $3"
    FAIL=$((FAIL + 1))
  fi
}

echo "D378 inbox-shield-phase1-parity-lock"

# 1. Capability registered in capabilities.yaml
check "cap-registered" \
  "grep -q 'inbox-shield.status:' '$ROOT/ops/capabilities.yaml'" \
  "inbox-shield.status not found in capabilities.yaml"

# 2. Capability registered in capability_map.yaml
check "cap-map-registered" \
  "grep -q 'inbox-shield.status:' '$ROOT/ops/bindings/capability_map.yaml'" \
  "inbox-shield.status not found in capability_map.yaml"

# 3. Contracts file exists
check "contracts-landed" \
  "[[ -f '$ROOT/ops/bindings/inbox-shield.contracts.yaml' ]]" \
  "inbox-shield.contracts.yaml not found"

# 4. Status script exists
check "status-script-exists" \
  "[[ -x '$ROOT/ops/plugins/inbox-shield/bin/inbox-shield-status' ]]" \
  "inbox-shield-status script not found or not executable"

# 5. Service onboarding entry exists
check "service-onboarding" \
  "grep -q 'id: inbox-shield' '$ROOT/ops/bindings/service.onboarding.contract.yaml'" \
  "inbox-shield not in service.onboarding.contract.yaml"

echo ""
echo "D378: $PASS/$TOTAL PASS"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1

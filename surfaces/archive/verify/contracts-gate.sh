#!/usr/bin/env bash
# contracts-gate.sh - Kernel contracts existence gate
# Ensures authoritative contract docs exist and are non-empty.
# Exit: 0 = PASS, 1 = FAIL

set -euo pipefail

SP="${SPINE_ROOT:-$HOME/code/agentic-spine}"
cd "$SP"

fail() { echo "FAIL: $*" >&2; exit 1; }

echo "=== CONTRACTS GATE ==="

# Required contracts
CONTRACTS=(
  "docs/core/RECEIPTS_CONTRACT.md"
  "docs/core/AGENT_OUTPUT_CONTRACT.md"
  "docs/core/PLAN_SCHEMA.md"
)

for c in "${CONTRACTS[@]}"; do
  if [[ ! -f "$c" ]]; then
    fail "Missing contract: $c"
  fi
  if [[ ! -s "$c" ]]; then
    fail "Empty contract: $c"
  fi
  echo "OK: $c"
done

echo "Contracts gate: PASS"

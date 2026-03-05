#!/usr/bin/env bash
# TRIAGE: Check infra placement against governance policy. Verify VM/host assignments.
set -euo pipefail

# D37: Infra Placement Policy Lock
# Purpose: enforce canonical site/hypervisor/service placement policy.
#
# Fails when:
#   - vm_targets violate site/proxmox/vmid policy
#   - services in relocation manifest violate primary/dr site policy
#   - non-planned service registry host does not match expected placement

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MANIFEST="${D37_MANIFEST:-$ROOT/ops/bindings/infra.relocation.plan.yaml}"
POLICY="${D37_POLICY:-$ROOT/ops/bindings/infra.placement.policy.yaml}"
CHECKER="${D37_CHECKER:-$ROOT/ops/plugins/infra/bin/infra-placement-policy-check}"

fail() { echo "D37 FAIL: $*" >&2; exit 1; }

[[ -x "$CHECKER" ]] || fail "placement checker missing or not executable: $CHECKER"
[[ -f "$POLICY" ]] || fail "placement policy binding missing: $POLICY"

if [[ ! -f "$MANIFEST" ]]; then
    echo "D37 PASS: no relocation manifest configured"
    exit 0
fi

"$CHECKER" --manifest "$MANIFEST" --policy "$POLICY" --check all >/dev/null
echo "D37 PASS: infra placement policy enforced"

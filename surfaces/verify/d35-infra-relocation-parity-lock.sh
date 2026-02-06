#!/usr/bin/env bash
set -euo pipefail

# D35: Infra Relocation Parity Lock
# Purpose: Enforce cross-SSOT consistency for infrastructure relocations.
#
# Behavior by state:
#   - planning/complete: PASS (parity check not required)
#   - preflight/cutover/cleanup: validates required_updates files exist
#     and SERVICE_REGISTRY.yaml host matches manifest for migrated services
#
# Fails on:
#   - Missing files listed in required_updates (during active states)
#   - Service host mismatch between manifest and registry (status=migrated/cutover)
#
# Note: Full 6-surface parity (STACK_REGISTRY, DEVICE_IDENTITY, health, ssh,
# backup) is advisory via infra.relocation.parity capability, not enforced
# at gate level during planning phase.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MANIFEST="$ROOT/ops/bindings/infra.relocation.plan.yaml"

fail() { echo "D35 FAIL: $*" >&2; exit 1; }

require_tool() {
    command -v "$1" >/dev/null 2>&1 || fail "required tool missing: $1"
}

require_tool yq

# Check manifest exists
if [[ ! -f "$MANIFEST" ]]; then
    echo "D35 PASS: no relocation manifest configured"
    exit 0
fi

yq e '.' "$MANIFEST" >/dev/null 2>&1 || fail "relocation manifest is not valid YAML"

# Get relocation state
STATE=$(yq e '.active_relocation.state' "$MANIFEST" 2>/dev/null || echo "none")

# Skip parity check if no active relocation or in planning state
if [[ "$STATE" == "null" ]] || [[ "$STATE" == "none" ]] || [[ "$STATE" == "planning" ]] || [[ "$STATE" == "complete" ]]; then
    echo "D35 PASS: relocation state is '$STATE' (parity check not required)"
    exit 0
fi

FAIL_COUNT=0

# Verify required_updates files exist
echo "Checking required SSOT files..."
while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    if [[ ! -f "$ROOT/$file" ]]; then
        echo "  MISSING: $file"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
done < <(yq e '.required_updates[]' "$MANIFEST" 2>/dev/null)

# For active relocations (preflight, cutover, cleanup), verify parity
if [[ "$STATE" == "preflight" ]] || [[ "$STATE" == "cutover" ]] || [[ "$STATE" == "cleanup" ]]; then
    # Load registries
    SERVICE_REG="$ROOT/docs/governance/SERVICE_REGISTRY.yaml"
    HEALTH_BINDING="$ROOT/ops/bindings/services.health.yaml"

    echo "Checking service parity for state: $STATE..."

    # Check each service in manifest
    while IFS= read -r service; do
        [[ -z "$service" ]] && continue

        to_host=$(yq e ".services[] | select(.service == \"$service\") | .to_host" "$MANIFEST")
        status=$(yq e ".services[] | select(.service == \"$service\") | .status" "$MANIFEST")

        # Skip planned services (not yet moved)
        [[ "$status" == "planned" ]] && continue

        # For migrated services, verify registry has new host
        if [[ "$status" == "migrated" ]] || [[ "$status" == "cutover" ]]; then
            reg_host=$(yq e ".services.\"$service\".host" "$SERVICE_REG" 2>/dev/null || echo "not-found")
            if [[ "$reg_host" != "$to_host" ]] && [[ "$reg_host" != "not-found" ]]; then
                echo "  PARITY MISMATCH: $service - manifest says $to_host, registry says $reg_host"
                FAIL_COUNT=$((FAIL_COUNT + 1))
            fi
        fi

    done < <(yq e '.services[].service' "$MANIFEST" 2>/dev/null)
fi

(( FAIL_COUNT == 0 )) || fail "relocation parity violated (${FAIL_COUNT} issue(s))"
echo "D35 PASS: infra relocation parity enforced"

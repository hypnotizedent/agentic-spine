#!/usr/bin/env bash
# TRIAGE: Update all SSOTs when relocating services: DEVICE_IDENTITY, SERVICE_REGISTRY, SSH config.
set -euo pipefail

# D35: Infra Relocation Parity Lock
# Purpose: Enforce cross-SSOT consistency for infrastructure relocations.
#
# Behavior by state:
#   - planning/complete: PASS (parity check not required)
#   - preflight/cutover/cleanup: validates required_updates files exist and:
#       * every non-planned service exists in SERVICE_REGISTRY.yaml
#       * SERVICE_REGISTRY host matches manifest to_host
#       * to_host exists in ssh.targets.yaml
#
# Fails on:
#   - Missing files listed in required_updates (during active states)
#   - Missing service entry for non-planned service in SERVICE_REGISTRY.yaml
#   - Service host mismatch between manifest and SERVICE_REGISTRY.yaml
#   - Missing to_host entry in ssh.targets.yaml for non-planned service
#
# Optional test overrides:
#   D35_MANIFEST=/tmp/manifest.yaml
#   D35_SERVICE_REGISTRY=/tmp/SERVICE_REGISTRY.yaml
#   D35_SSH_TARGETS=/tmp/ssh.targets.yaml

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MANIFEST="${D35_MANIFEST:-$ROOT/ops/bindings/infra.relocation.plan.yaml}"
SERVICE_REG="${D35_SERVICE_REGISTRY:-$ROOT/docs/governance/SERVICE_REGISTRY.yaml}"
SSH_BINDING="${D35_SSH_TARGETS:-$ROOT/ops/bindings/ssh.targets.yaml}"

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
    local_path="$file"
    if [[ "$file" != /* ]]; then
        local_path="$ROOT/$file"
    fi
    if [[ ! -f "$local_path" ]]; then
        echo "  MISSING: $file"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
done < <(yq e '.required_updates[]' "$MANIFEST" 2>/dev/null)

# For active relocations (preflight, cutover, cleanup), verify parity
if [[ "$STATE" == "preflight" ]] || [[ "$STATE" == "cutover" ]] || [[ "$STATE" == "cleanup" ]]; then
    [[ -f "$SERVICE_REG" ]] || fail "service registry not found: $SERVICE_REG"
    [[ -f "$SSH_BINDING" ]] || fail "ssh targets binding not found: $SSH_BINDING"

    echo "Checking service parity for state: $STATE..."

    # Check each service in manifest
    while IFS= read -r service; do
        [[ -z "$service" ]] && continue

        to_host="$(yq e ".services[] | select(.service == \"$service\") | .to_host" "$MANIFEST")"
        status="$(yq e ".services[] | select(.service == \"$service\") | .status" "$MANIFEST")"

        # Skip planned services (not yet moved)
        [[ "$status" == "planned" ]] && continue

        if [[ -z "$to_host" ]] || [[ "$to_host" == "null" ]]; then
            echo "  PARITY MISMATCH: $service - manifest to_host is empty for status=$status"
            FAIL_COUNT=$((FAIL_COUNT + 1))
            continue
        fi

        # Every non-planned service must exist in SERVICE_REGISTRY
        reg_host="$(yq e ".services.\"$service\".host // \"null\"" "$SERVICE_REG" 2>/dev/null || echo "null")"
        if [[ "$reg_host" == "null" ]] || [[ -z "$reg_host" ]]; then
            echo "  PARITY MISMATCH: $service missing from SERVICE_REGISTRY.yaml"
            FAIL_COUNT=$((FAIL_COUNT + 1))
            continue
        fi

        # Registry host must match manifest to_host
        if [[ "$reg_host" != "$to_host" ]]; then
            echo "  PARITY MISMATCH: $service - manifest says $to_host, registry says $reg_host"
            FAIL_COUNT=$((FAIL_COUNT + 1))
        fi

        # Every non-planned service target host must be SSH-addressable
        ssh_target="$(yq e ".ssh.targets[] | select(.id == \"$to_host\") | .id" "$SSH_BINDING" 2>/dev/null || echo "null")"
        if [[ "$ssh_target" == "null" ]] || [[ -z "$ssh_target" ]]; then
            echo "  PARITY MISMATCH: $service - to_host '$to_host' missing in ssh.targets.yaml"
            FAIL_COUNT=$((FAIL_COUNT + 1))
        fi
    done < <(yq e '.services[].service' "$MANIFEST" 2>/dev/null)
fi

(( FAIL_COUNT == 0 )) || fail "relocation parity violated (${FAIL_COUNT} issue(s))"
echo "D35 PASS: infra relocation parity enforced"

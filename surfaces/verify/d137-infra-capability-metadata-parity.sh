#!/usr/bin/env bash
# TRIAGE: Add plane/domain/requires fields to infra capabilities in ops/capabilities.yaml
# D137: Infra capability metadata parity (plane/domain/requires) for proxmox/post_power/maintenance surfaces
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CAPS="$ROOT/ops/capabilities.yaml"

ERRORS=0
err() { echo "  $*"; ERRORS=$((ERRORS + 1)); }

command -v yq >/dev/null 2>&1 || { err "yq not installed"; echo "D137 FAIL: 1 check(s) failed"; exit 1; }
[[ -f "$CAPS" ]] || { err "capabilities.yaml not found"; echo "D137 FAIL: 1 check(s) failed"; exit 1; }

# Target capabilities that must have plane=fabric, domain=infra, and requires list
TARGET_CAPS=(
  "infra.proxmox.maintenance.precheck"
  "infra.proxmox.maintenance.shutdown"
  "infra.proxmox.maintenance.startup"
  "infra.post_power.recovery.status"
  "infra.post_power.recovery"
  "infra.maintenance.window"
  "infra.proxmox.node_path.migrate"
)

for cap in "${TARGET_CAPS[@]}"; do
  plane="$(yq e ".capabilities.\"$cap\".plane // \"\"" "$CAPS" 2>/dev/null)"
  domain="$(yq e ".capabilities.\"$cap\".domain // \"\"" "$CAPS" 2>/dev/null)"

  if [[ -z "$plane" || "$plane" == "null" ]]; then
    err "Capability $cap missing required field 'plane'"
  elif [[ "$plane" != "fabric" ]]; then
    err "Capability $cap has plane=$plane (expected: fabric)"
  fi

  if [[ -z "$domain" || "$domain" == "null" ]]; then
    err "Capability $cap missing required field 'domain'"
  elif [[ "$domain" != "infra" ]]; then
    err "Capability $cap has domain=$domain (expected: infra)"
  fi
done

# Capabilities that must have requires list (all except node_path.migrate which has its own)
REQUIRES_CAPS=(
  "infra.proxmox.maintenance.precheck"
  "infra.proxmox.maintenance.shutdown"
  "infra.proxmox.maintenance.startup"
  "infra.post_power.recovery.status"
  "infra.post_power.recovery"
  "infra.maintenance.window"
)

for cap in "${REQUIRES_CAPS[@]}"; do
  req_count="$(yq e ".capabilities.\"$cap\".requires | length" "$CAPS" 2>/dev/null || echo "0")"
  if [[ "$req_count" -eq 0 || "$req_count" == "null" ]]; then
    err "Capability $cap has no requires preconditions"
  fi
done

if [[ "$ERRORS" -gt 0 ]]; then
  echo "D137 FAIL: $ERRORS parity errors found"
  exit 1
fi

echo "D137 PASS: infra capability metadata parity enforced (${#TARGET_CAPS[@]} capabilities checked)"
exit 0

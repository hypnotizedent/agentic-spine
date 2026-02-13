#!/usr/bin/env bash
# TRIAGE: Ensure bidirectional host coverage between registries.
# D59: Cross-registry completeness lock
# Verifies bidirectional host coverage between ssh.targets.yaml,
# SERVICE_REGISTRY.yaml, and naming.policy.yaml.
#
# Only checks shop-site, Tailscale-connected hosts (not LAN-only devices,
# not home-site hosts, not decommissioned entries).
set -euo pipefail

SP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

SSH_TARGETS="$SP/ops/bindings/ssh.targets.yaml"
SERVICE_REG="$SP/docs/governance/SERVICE_REGISTRY.yaml"
NAMING="$SP/ops/bindings/naming.policy.yaml"

FAIL=0
err() { echo "  FAIL: $1" >&2; FAIL=1; }

[[ -f "$SSH_TARGETS" ]] || { err "ssh.targets.yaml not found"; exit 1; }
[[ -f "$SERVICE_REG" ]] || { err "SERVICE_REGISTRY.yaml not found"; exit 1; }
[[ -f "$NAMING" ]]      || { err "naming.policy.yaml not found"; exit 1; }
command -v yq >/dev/null 2>&1 || { err "yq not found"; exit 1; }

# Get SSH target IDs (excluding lan_only and optional)
ssh_hosts=$(yq -r '.ssh.targets[] | select(.access_method != "lan_only") | .id' "$SSH_TARGETS")

# Get SERVICE_REGISTRY host keys
svc_hosts=$(yq -r '.hosts | keys | .[]' "$SERVICE_REG")

# Get naming.policy hosts (non-decommissioned, with ssh_target: true)
naming_ssh_hosts=$(yq -r '.hosts[] | select(.status != "decommissioned") | select(.surfaces.ssh_target == true) | .canonical_name' "$NAMING")

# Check 1: Every naming.policy ssh_target host should be in ssh.targets.yaml
for host in $naming_ssh_hosts; do
  if ! echo "$ssh_hosts" | grep -qx "$host"; then
    err "$host: in naming.policy (ssh_target=true) but missing from ssh.targets.yaml"
  fi
done

# Check 2: Every SSH target (non-lan-only, non-home) should be in SERVICE_REGISTRY hosts
# Filter to shop-site hosts only by checking naming.policy site
for host in $ssh_hosts; do
  site=$(yq -r ".hosts[] | select(.canonical_name == \"$host\") | .site" "$NAMING")
  [[ "$site" != "shop" ]] && continue

  kind=$(yq -r ".hosts[] | select(.canonical_name == \"$host\") | .kind" "$NAMING")
  # Skip proxmox hypervisors — they're in SERVICE_REGISTRY only if they host services
  [[ "$kind" == "proxmox" ]] && continue

  status=$(yq -r ".hosts[] | select(.canonical_name == \"$host\") | .status" "$NAMING")
  [[ "$status" == "decommissioned" ]] && continue

  if ! echo "$svc_hosts" | grep -qx "$host"; then
    err "$host: in ssh.targets.yaml (shop) but missing from SERVICE_REGISTRY.yaml hosts"
  fi
done

exit "$FAIL"

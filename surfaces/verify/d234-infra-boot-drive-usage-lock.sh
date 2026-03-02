#!/usr/bin/env bash
# TRIAGE: D234 infra-boot-drive-usage-lock
# Enforces: boot drive usage below threshold on all active VMs with persistent workloads.
# Checks: (1) boot drive <80% used, (2) VMs declared as "violation" in storage placement policy have open gaps.
# Does NOT remediate — just fails loudly when boot drives are filling up.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
source "$ROOT/surfaces/verify/lib/tailscale-guard.sh"
require_tailscale_for "docker-host"

VM_BINDING="$ROOT/ops/bindings/vm.lifecycle.yaml"
SSH_TARGETS="$ROOT/ops/bindings/ssh.targets.yaml"
STORAGE_POLICY="$ROOT/ops/bindings/infra.storage.placement.policy.yaml"

ERRORS=0
SKIPS=0
CONTEXT_SKIPS=0
err() { echo "  FAIL: $*" >&2; ERRORS=$((ERRORS + 1)); }
ok() { [[ "${DRIFT_VERBOSE:-0}" == "1" ]] && echo "  OK: $*" || true; }
skip() { echo "  SKIP: $*"; SKIPS=$((SKIPS + 1)); }
skip_context() { echo "  SKIP(context): $*"; CONTEXT_SKIPS=$((CONTEXT_SKIPS + 1)); }

is_private_ipv4() {
  local ip="$1"
  [[ "$ip" =~ ^10\. ]] && return 0
  [[ "$ip" =~ ^192\.168\. ]] && return 0
  if [[ "$ip" =~ ^172\.([0-9]+)\. ]]; then
    local o2="${BASH_REMATCH[1]}"
    [[ "$o2" -ge 16 && "$o2" -le 31 ]] && return 0
  fi
  return 1
}

local_ipv4_prefixes() {
  {
    if command -v ifconfig >/dev/null 2>&1; then
      ifconfig 2>/dev/null | awk '/inet /{print $2}'
    fi
    if command -v ip >/dev/null 2>&1; then
      ip -4 addr show 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1
    fi
  } | awk -F. 'NF==4 {print $1 "." $2 "." $3}' | sort -u
}

is_same_local_subnet_24() {
  local ip="$1"
  local prefix local_prefix
  prefix="$(awk -F. 'NF==4 {print $1 "." $2 "." $3}' <<<"$ip")"
  [[ -n "$prefix" ]] || return 1
  while read -r local_prefix; do
    [[ -n "$local_prefix" ]] || continue
    [[ "$local_prefix" == "$prefix" ]] && return 0
  done < <(local_ipv4_prefixes)
  return 1
}

is_off_lan_context() {
  local ip="$1"
  is_private_ipv4 "$ip" || return 1
  is_same_local_subnet_24 "$ip" && return 1
  return 0
}

# Check that storage placement policy exists
if [[ ! -f "$STORAGE_POLICY" ]]; then
  err "infra.storage.placement.policy.yaml not found (GAP-OP-943)"
  echo "D234 FAIL: $ERRORS check(s) failed"
  exit 1
fi

WARN_PCT=$(yq -r '.thresholds.boot_usage_warn_pct // 80' "$STORAGE_POLICY" 2>/dev/null || echo 80)
CRIT_PCT=$(yq -r '.thresholds.boot_usage_critical_pct // 90' "$STORAGE_POLICY" 2>/dev/null || echo 90)

# Get list of active VMs (non-decommissioned, non-template, with ssh_target)
ACTIVE_VMS=$(yq -r '.vms[] | select(.status == "active" and .ssh_target != null and .ssh_target != "" and .proxmox_host == "pve") | .hostname + "\t" + .ssh_target + "\t" + (.id | tostring)' "$VM_BINDING" 2>/dev/null || echo "")

if [[ -z "$ACTIVE_VMS" ]]; then
  err "no active VMs found in vm.lifecycle.yaml"
  echo "D234 FAIL: $ERRORS check(s) failed"
  exit 1
fi

while IFS=$'\t' read -r hostname ssh_target vmid; do
  [[ -z "$hostname" ]] && continue

  # Get SSH connection info
  ssh_host=$(yq -r ".ssh.targets[] | select(.id == \"${ssh_target}\") | .host" "$SSH_TARGETS" 2>/dev/null || echo "")
  ssh_user=$(yq -r ".ssh.targets[] | select(.id == \"${ssh_target}\") | .user // \"ubuntu\"" "$SSH_TARGETS" 2>/dev/null || echo "ubuntu")
  ssh_policy=$(yq -r ".ssh.targets[] | select(.id == \"${ssh_target}\") | .access_policy // \"lan_first\"" "$SSH_TARGETS" 2>/dev/null || echo "lan_first")

  if [[ -z "$ssh_host" || "$ssh_host" == "null" ]]; then
    skip "VM $vmid ($hostname): no SSH host found in ssh.targets.yaml"
    continue
  fi

  SSH_REF="${ssh_user}@${ssh_host}"
  SSH_OPTS="-o ConnectTimeout=8 -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

  # Test SSH connectivity
  if ! ssh $SSH_OPTS "$SSH_REF" "true" 2>/dev/null; then
    if [[ "$ssh_policy" == "lan_first" ]] && is_off_lan_context "$ssh_host"; then
      skip_context "VM $vmid ($hostname): SSH unreachable from current off-LAN context ($SSH_REF)"
    else
      skip "VM $vmid ($hostname): SSH unreachable ($SSH_REF)"
    fi
    continue
  fi

  # Get boot drive usage percentage
  boot_pct=$(ssh $SSH_OPTS "$SSH_REF" "df --output=pcent / 2>/dev/null | tail -1 | tr -d ' %'" 2>/dev/null || echo "")

  if [[ -z "$boot_pct" ]]; then
    skip "VM $vmid ($hostname): could not read boot drive usage"
    continue
  fi

  if [[ "$boot_pct" -ge "$CRIT_PCT" ]]; then
    err "VM $vmid ($hostname): boot drive at ${boot_pct}% (CRITICAL, threshold ${CRIT_PCT}%)"
  elif [[ "$boot_pct" -ge "$WARN_PCT" ]]; then
    err "VM $vmid ($hostname): boot drive at ${boot_pct}% (WARNING, threshold ${WARN_PCT}%)"
  else
    ok "VM $vmid ($hostname): boot drive at ${boot_pct}%"
  fi

done <<< "$ACTIVE_VMS"

# Check that storage policy has no undocumented violations
VIOLATION_COUNT=$(yq -r '[.vm_storage | to_entries[] | select(.value.status == "violation")] | length' "$STORAGE_POLICY" 2>/dev/null || echo 0)
VIOLATION_WITH_GAP=$(yq -r '[.vm_storage | to_entries[] | select(.value.status == "violation" and .value.gap != null)] | length' "$STORAGE_POLICY" 2>/dev/null || echo 0)

if [[ "$VIOLATION_COUNT" -ne "$VIOLATION_WITH_GAP" ]]; then
  err "storage placement policy has $VIOLATION_COUNT violations but only $VIOLATION_WITH_GAP have gap entries"
fi

ok "storage placement policy: $VIOLATION_COUNT violations, $VIOLATION_WITH_GAP with gaps"

if [[ "$ERRORS" -gt 0 || "$SKIPS" -gt 0 ]]; then
  echo "D234 FAIL: $ERRORS check(s) failed ($SKIPS skipped, $CONTEXT_SKIPS contextual skips)"
  exit 1
fi

if [[ "$CONTEXT_SKIPS" -gt 0 ]]; then
  echo "D234 PASS: contextual off-LAN skips only ($CONTEXT_SKIPS)"
  exit 0
fi

echo "D234 PASS (0 skipped)"
exit 0

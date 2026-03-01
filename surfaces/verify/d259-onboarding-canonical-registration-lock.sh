#!/usr/bin/env bash
# TRIAGE: Complete vm lifecycle + ssh/tailscale registration for active hosts.
# D259: Onboarding canonical registration lock.
# Blocks active/registered shop VM lifecycle states when canonical SSH + Tailscale
# registration is incomplete across vm.lifecycle, ssh.targets, and SERVICE_REGISTRY.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SSH_BINDING="$ROOT/ops/bindings/ssh.targets.yaml"
VM_BINDING="$ROOT/ops/bindings/vm.lifecycle.yaml"
SERVICE_REGISTRY="$ROOT/docs/governance/SERVICE_REGISTRY.yaml"
STORAGE_POLICY="$ROOT/ops/bindings/infra.storage.placement.policy.yaml"

fail=0
err() { echo "D259 FAIL: $*" >&2; fail=1; }

command -v yq >/dev/null 2>&1 || { echo "D259 FAIL: missing dependency: yq" >&2; exit 1; }
for f in "$SSH_BINDING" "$VM_BINDING" "$SERVICE_REGISTRY" "$STORAGE_POLICY"; do
  [[ -f "$f" ]] || { echo "D259 FAIL: missing file: $f" >&2; exit 1; }
done

vm_count="$(yq e '.vms | length' "$VM_BINDING" 2>/dev/null || echo 0)"
[[ "$vm_count" =~ ^[0-9]+$ ]] || { echo "D259 FAIL: invalid vm lifecycle structure" >&2; exit 1; }

checked=0
for ((i=0; i<vm_count; i++)); do
  status="$(yq e -r ".vms[$i].status // \"\"" "$VM_BINDING")"
  site_scope="$(yq e -r ".vms[$i].site_scope // \"shop\"" "$VM_BINDING")"
  proxmox_host="$(yq e -r ".vms[$i].proxmox_host // \"\"" "$VM_BINDING")"
  case "$status" in
    registered|active) ;;
    *) continue ;;
  esac
  [[ "$site_scope" == "home" ]] && continue
  [[ "$proxmox_host" == "pve" ]] || continue

  checked=$((checked + 1))
  hostname="$(yq e -r ".vms[$i].hostname // \"\"" "$VM_BINDING")"
  vm_ts_ip="$(yq e -r ".vms[$i].tailscale_ip // \"\"" "$VM_BINDING")"
  ssh_target="$(yq e -r ".vms[$i].ssh_target // \"\"" "$VM_BINDING")"

  [[ -n "$hostname" && "$hostname" != "null" ]] || { err "row $i: missing hostname"; continue; }
  [[ -n "$vm_ts_ip" && "$vm_ts_ip" != "null" && "$vm_ts_ip" != "PENDING_TS_IP" ]] || err "$hostname: tailscale_ip must be set before status=$status"
  [[ -n "$ssh_target" && "$ssh_target" != "null" ]] || { err "$hostname: ssh_target missing before status=$status"; continue; }

  ssh_host="$(yq e -r ".ssh.targets[] | select(.id == \"$ssh_target\") | .host // \"\"" "$SSH_BINDING" 2>/dev/null || true)"
  [[ -n "$ssh_host" && "$ssh_host" != "null" ]] || { err "$hostname: ssh_target '$ssh_target' missing in ssh.targets"; continue; }
  [[ "$ssh_host" == "$vm_ts_ip" ]] || err "$hostname: ssh.targets host mismatch for '$ssh_target' expected=$vm_ts_ip actual=$ssh_host"

  sr_ts_ip="$(yq e -r ".hosts.\"$hostname\".tailscale_ip // \"\"" "$SERVICE_REGISTRY" 2>/dev/null || true)"
  sr_ssh="$(yq e -r ".hosts.\"$hostname\".ssh // \"\"" "$SERVICE_REGISTRY" 2>/dev/null || true)"
  [[ -n "$sr_ts_ip" && "$sr_ts_ip" != "null" ]] || { err "$hostname: SERVICE_REGISTRY hosts entry missing before status=$status"; continue; }
  [[ "$sr_ts_ip" == "$vm_ts_ip" ]] || err "$hostname: SERVICE_REGISTRY tailscale_ip mismatch expected=$vm_ts_ip actual=$sr_ts_ip"
  [[ "$sr_ssh" == "$ssh_target" ]] || err "$hostname: SERVICE_REGISTRY ssh mismatch expected=$ssh_target actual=$sr_ssh"

  lane="$(yq e -r ".vm_storage.\"$hostname\".capacity_lane // \"\"" "$STORAGE_POLICY" 2>/dev/null || true)"
  budget_class="$(yq e -r ".vm_storage.\"$hostname\".capacity_budget_class // \"\"" "$STORAGE_POLICY" 2>/dev/null || true)"
  retention_ref="$(yq e -r ".vm_storage.\"$hostname\".retention_policy_ref // \"\"" "$STORAGE_POLICY" 2>/dev/null || true)"
  reclaim_ref="$(yq e -r ".vm_storage.\"$hostname\".reclaim_policy_ref // \"\"" "$STORAGE_POLICY" 2>/dev/null || true)"

  [[ -n "$lane" && "$lane" != "null" ]] || err "$hostname: infra.storage.placement.policy missing capacity_lane"
  [[ -n "$budget_class" && "$budget_class" != "null" ]] || err "$hostname: infra.storage.placement.policy missing capacity_budget_class"
  [[ -n "$retention_ref" && "$retention_ref" != "null" ]] || err "$hostname: infra.storage.placement.policy missing retention_policy_ref"
  [[ -n "$reclaim_ref" && "$reclaim_ref" != "null" ]] || err "$hostname: infra.storage.placement.policy missing reclaim_policy_ref"

  if [[ -n "$retention_ref" && "$retention_ref" != "null" ]]; then
    retention_file="${retention_ref%%#*}"
    [[ "$retention_file" = /* ]] || retention_file="$ROOT/$retention_file"
    [[ -f "$retention_file" ]] || err "$hostname: retention_policy_ref target missing on disk ($retention_ref)"
  fi
  if [[ -n "$reclaim_ref" && "$reclaim_ref" != "null" ]]; then
    reclaim_file="${reclaim_ref%%#*}"
    [[ "$reclaim_file" = /* ]] || reclaim_file="$ROOT/$reclaim_file"
    [[ -f "$reclaim_file" ]] || err "$hostname: reclaim_policy_ref target missing on disk ($reclaim_ref)"
  fi
done

[[ "$checked" -gt 0 ]] || err "no registered/active shop VMs found for onboarding checks"

# Active services must reference known SERVICE_REGISTRY host keys.
mapfile -t known_hosts < <(yq e -r '.hosts | keys | .[]' "$SERVICE_REGISTRY" 2>/dev/null)
while IFS= read -r host; do
  [[ -z "$host" || "$host" == "null" ]] && continue
  found=0
  for known in "${known_hosts[@]:-}"; do
    [[ "$known" == "$host" ]] && { found=1; break; }
  done
  [[ "$found" -eq 1 ]] || err "service host '$host' missing from SERVICE_REGISTRY hosts map"
done < <(yq e -r '.services[] | select((.status // "active") == "active") | .host // ""' "$SERVICE_REGISTRY" 2>/dev/null)

if [[ "$fail" -eq 1 ]]; then
  exit 1
fi

echo "D259 PASS: onboarding canonical registration checks passed (checked=$checked registered/active shop VMs)"

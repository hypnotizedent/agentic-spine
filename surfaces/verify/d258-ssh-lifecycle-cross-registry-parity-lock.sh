#!/usr/bin/env bash
# TRIAGE: Repair ssh.targets/vm.lifecycle/service-registry parity before rerun.
# D258: SSH lifecycle cross-registry parity lock.
# Enforces vm.lifecycle <-> ssh.targets <-> SERVICE_REGISTRY hosts parity for active shop VMs
# and validates workbench SSH attach contract anchor paths.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SSH_BINDING="$ROOT/ops/bindings/ssh.targets.yaml"
VM_BINDING="$ROOT/ops/bindings/vm.lifecycle.yaml"
SERVICE_REGISTRY="$ROOT/docs/governance/SERVICE_REGISTRY.yaml"
WORKBENCH_SSH_CONTRACT="$ROOT/ops/bindings/workbench.ssh.attach.contract.yaml"

fail=0
err() { echo "D258 FAIL: $*" >&2; fail=1; }

command -v yq >/dev/null 2>&1 || { echo "D258 FAIL: missing dependency: yq" >&2; exit 1; }
for f in "$SSH_BINDING" "$VM_BINDING" "$SERVICE_REGISTRY" "$WORKBENCH_SSH_CONTRACT"; do
  [[ -f "$f" ]] || { echo "D258 FAIL: missing file: $f" >&2; exit 1; }
done

# Contract anchor checks: keep workbench attach contract bound to canonical paths.
wb_binding="$(yq e -r '.spine_binding // ""' "$WORKBENCH_SSH_CONTRACT" 2>/dev/null || true)"
wb_config="$(yq e -r '.workbench_ssh_config // ""' "$WORKBENCH_SSH_CONTRACT" 2>/dev/null || true)"
[[ "$wb_binding" == "ops/bindings/ssh.targets.yaml" ]] || err "workbench.ssh.attach.contract spine_binding mismatch: $wb_binding"
[[ "$wb_config" == "dotfiles/ssh/config.d/tailscale.conf" ]] || err "workbench.ssh.attach.contract workbench_ssh_config mismatch: $wb_config"

vm_count="$(yq e '.vms | length' "$VM_BINDING" 2>/dev/null || echo 0)"
[[ "$vm_count" =~ ^[0-9]+$ ]] || { echo "D258 FAIL: invalid vm lifecycle structure" >&2; exit 1; }

checked=0
for ((i=0; i<vm_count; i++)); do
  status="$(yq e -r ".vms[$i].status // \"\"" "$VM_BINDING")"
  site_scope="$(yq e -r ".vms[$i].site_scope // \"shop\"" "$VM_BINDING")"
  proxmox_host="$(yq e -r ".vms[$i].proxmox_host // \"\"" "$VM_BINDING")"
  [[ "$status" == "active" ]] || continue
  [[ "$site_scope" == "home" ]] && continue
  [[ "$proxmox_host" == "pve" ]] || continue

  checked=$((checked + 1))
  hostname="$(yq e -r ".vms[$i].hostname // \"\"" "$VM_BINDING")"
  vm_ts_ip="$(yq e -r ".vms[$i].tailscale_ip // \"\"" "$VM_BINDING")"
  ssh_target="$(yq e -r ".vms[$i].ssh_target // \"\"" "$VM_BINDING")"

  [[ -n "$hostname" && "$hostname" != "null" ]] || { err "active VM row $i missing hostname"; continue; }
  [[ -n "$vm_ts_ip" && "$vm_ts_ip" != "null" ]] || err "$hostname: missing vm.lifecycle tailscale_ip"
  [[ -n "$ssh_target" && "$ssh_target" != "null" ]] || { err "$hostname: missing vm.lifecycle ssh_target"; continue; }

  ssh_host="$(yq e -r ".ssh.targets[] | select(.id == \"$ssh_target\") | .host // \"\"" "$SSH_BINDING" 2>/dev/null || true)"
  [[ -n "$ssh_host" && "$ssh_host" != "null" ]] || { err "$hostname: ssh_target '$ssh_target' missing in ssh.targets"; continue; }
  [[ "$ssh_host" == "$vm_ts_ip" ]] || err "$hostname: tailscale mismatch vm.lifecycle=$vm_ts_ip ssh.targets=$ssh_host (ssh_target=$ssh_target)"

  sr_ts_ip="$(yq e -r ".hosts.\"$hostname\".tailscale_ip // \"\"" "$SERVICE_REGISTRY" 2>/dev/null || true)"
  sr_ssh="$(yq e -r ".hosts.\"$hostname\".ssh // \"\"" "$SERVICE_REGISTRY" 2>/dev/null || true)"
  [[ -n "$sr_ts_ip" && "$sr_ts_ip" != "null" ]] || { err "$hostname: missing SERVICE_REGISTRY hosts entry"; continue; }
  [[ "$sr_ts_ip" == "$vm_ts_ip" ]] || err "$hostname: tailscale mismatch vm.lifecycle=$vm_ts_ip SERVICE_REGISTRY=$sr_ts_ip"
  [[ "$sr_ssh" == "$ssh_target" ]] || err "$hostname: ssh target mismatch vm.lifecycle=$ssh_target SERVICE_REGISTRY=$sr_ssh"
done

[[ "$checked" -gt 0 ]] || err "no active shop VMs found for parity checks"

if [[ "$fail" -eq 1 ]]; then
  exit 1
fi

echo "D258 PASS: cross-registry SSH lifecycle parity valid (checked=$checked active shop VMs)"

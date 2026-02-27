#!/usr/bin/env bash
# D262: SSH/Tailscale duplicate-truth lock.
# Detects duplicate or undocumented truth sources for host alias + tailscale target mappings.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIFECYCLE_CONTRACT="$ROOT/ops/bindings/tailscale.ssh.lifecycle.contract.yaml"
SSH_BINDING="$ROOT/ops/bindings/ssh.targets.yaml"
VM_BINDING="$ROOT/ops/bindings/vm.lifecycle.yaml"
SERVICE_REGISTRY="$ROOT/docs/governance/SERVICE_REGISTRY.yaml"

fail=0
err() { echo "D262 FAIL: $*" >&2; fail=1; }

command -v yq >/dev/null 2>&1 || { echo "D262 FAIL: missing dependency: yq" >&2; exit 1; }
for f in "$LIFECYCLE_CONTRACT" "$SSH_BINDING" "$VM_BINDING" "$SERVICE_REGISTRY"; do
  [[ -f "$f" ]] || { echo "D262 FAIL: missing file: $f" >&2; exit 1; }
done

# 1) Active shop VM tailscale IPs must be unique.
dupe_vm_ips="$(
  yq e -r '.vms[] | select(.status == "active" and (.site_scope // "shop") != "home" and .proxmox_host == "pve") | .tailscale_ip // ""' "$VM_BINDING" \
  | sed '/^$/d' | sort | uniq -d
)"
[[ -z "$dupe_vm_ips" ]] || err "duplicate active shop vm.lifecycle tailscale_ip values: $(echo "$dupe_vm_ips" | paste -sd ',' -)"

# 2) Non-LAN SSH target hosts must be unique.
dupe_ssh_hosts="$(
  yq e -r '.ssh.targets[] | select((.access_method // "ssh") != "lan_only") | .host // ""' "$SSH_BINDING" \
  | sed '/^$/d' | sort | uniq -d
)"
[[ -z "$dupe_ssh_hosts" ]] || err "duplicate non-lan ssh.targets host values: $(echo "$dupe_ssh_hosts" | paste -sd ',' -)"

# 3) SERVICE_REGISTRY host ssh mappings must resolve and match ssh.targets host.
while IFS=$'\t' read -r host_id sr_ssh sr_ts; do
  [[ -n "$host_id" && "$host_id" != "null" ]] || continue
  [[ -n "$sr_ssh" && "$sr_ssh" != "null" ]] || continue
  [[ "$sr_ssh" == "localhost" ]] && continue
  ssh_host="$(yq e -r ".ssh.targets[] | select(.id == \"$sr_ssh\") | .host // \"\"" "$SSH_BINDING" 2>/dev/null || true)"
  [[ -n "$ssh_host" && "$ssh_host" != "null" ]] || { err "$host_id: SERVICE_REGISTRY ssh target '$sr_ssh' missing in ssh.targets"; continue; }
  [[ "$sr_ts" == "$ssh_host" ]] || err "$host_id: SERVICE_REGISTRY tailscale_ip=$sr_ts but ssh.target($sr_ssh) host=$ssh_host"
done < <(yq e -r '.hosts | to_entries[] | [.key, (.value.ssh // ""), (.value.tailscale_ip // "")] | @tsv' "$SERVICE_REGISTRY")

# 4) Any active VM hostname != ssh_target must be explicitly documented override.
mapfile -t overrides < <(yq e -r '.approved_alias_overrides[]? | (.vm_hostname + "=>" + .ssh_target)' "$LIFECYCLE_CONTRACT" 2>/dev/null || true)
is_override() {
  local key="$1"
  local row
  for row in "${overrides[@]:-}"; do
    [[ "$row" == "$key" ]] && return 0
  done
  return 1
}

vm_count="$(yq e '.vms | length' "$VM_BINDING" 2>/dev/null || echo 0)"
for ((i=0; i<vm_count; i++)); do
  status="$(yq e -r ".vms[$i].status // \"\"" "$VM_BINDING")"
  [[ "$status" == "active" ]] || continue
  hostname="$(yq e -r ".vms[$i].hostname // \"\"" "$VM_BINDING")"
  ssh_target="$(yq e -r ".vms[$i].ssh_target // \"\"" "$VM_BINDING")"
  [[ -n "$hostname" && -n "$ssh_target" ]] || continue
  if [[ "$hostname" != "$ssh_target" ]]; then
    key="${hostname}=>${ssh_target}"
    is_override "$key" || err "undocumented hostname/ssh_target divergence: $key (add approved_alias_overrides)"
  fi
done

if [[ "$fail" -eq 1 ]]; then
  exit 1
fi

echo "D262 PASS: duplicate-truth checks clean for ssh/tailscale host alias mappings"

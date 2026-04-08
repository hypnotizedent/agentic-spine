#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
VM_BINDING="$ROOT/ops/bindings/vm.lifecycle.yaml"
source "$ROOT/ops/lib/ssh-resolve.sh"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "G1 FAIL: missing dependency: $1" >&2
    exit 2
  }
}

need_cmd yq
need_cmd ssh

[[ -f "$VM_BINDING" ]] || {
  echo "G1 FAIL: missing vm lifecycle binding: $VM_BINDING" >&2
  exit 2
}

printf "%-22s %-10s %-12s %s\n" "vm" "status" "path" "detail"

failures=0
checked=0

while IFS=$'\t' read -r hostname ssh_target ssh_user; do
  [[ -n "$hostname" ]] || continue
  checked=$((checked + 1))

  [[ -n "$ssh_target" && "$ssh_target" != "null" ]] || ssh_target="$hostname"
  resolved="$(ssh_resolve_ssh_host_with_fallback "$ssh_target" 5 2>/dev/null || true)"
  resolved_host="$(awk '{print $1}' <<<"$resolved")"
  path_used="$(awk '{print $2}' <<<"$resolved")"
  [[ -n "$path_used" ]] || path_used="unresolved"

  if [[ -z "$resolved_host" || "$path_used" == "unreachable" ]]; then
    printf "%-22s %-10s %-12s %s\n" "$hostname" "FAIL" "$path_used" "ssh target unreachable"
    failures=$((failures + 1))
    continue
  fi

  ssh_user="$(ssh_resolve_user "$ssh_target" "${ssh_user:-ubuntu}")"
  set +e
  ssh -n \
    -o ConnectTimeout=8 \
    -o BatchMode=yes \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    "${ssh_user}@${resolved_host}" \
    "true" >/dev/null 2>&1
  rc=$?
  set -e

  if [[ "$rc" -eq 0 ]]; then
    printf "%-22s %-10s %-12s %s\n" "$hostname" "PASS" "$path_used" "${ssh_user}@${resolved_host}"
  else
    printf "%-22s %-10s %-12s %s\n" "$hostname" "FAIL" "$path_used" "${ssh_user}@${resolved_host}"
    failures=$((failures + 1))
  fi
done < <(
  yq e -r '
    .vms[]
    | select(.status == "active")
    | [ .hostname, (.ssh_target // .hostname // ""), (.ssh_user // "ubuntu") ]
    | @tsv
  ' "$VM_BINDING"
)

if [[ "$checked" -eq 0 ]]; then
  echo "G1 FAIL: no active VMs found in vm.lifecycle.yaml" >&2
  exit 1
fi

if [[ "$failures" -gt 0 ]]; then
  echo "G1 FAIL: vm reachability failures=${failures}/${checked}" >&2
  exit 1
fi

echo "G1 PASS: all active VMs reachable (${checked})"

#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
VM_BINDING="$ROOT/ops/bindings/vm.lifecycle.yaml"
POLICY="$ROOT/ops/bindings/infra.storage.placement.policy.yaml"
source "$ROOT/ops/lib/ssh-resolve.sh"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "G2 FAIL: missing dependency: $1" >&2
    exit 2
  }
}

need_cmd yq
need_cmd ssh

[[ -f "$VM_BINDING" ]] || {
  echo "G2 FAIL: missing vm lifecycle binding: $VM_BINDING" >&2
  exit 2
}
[[ -f "$POLICY" ]] || {
  echo "G2 FAIL: missing storage policy: $POLICY" >&2
  exit 2
}

warn_pct="$(yq e -r '.thresholds.boot_usage_warn_pct // 80' "$POLICY")"
crit_pct="$(yq e -r '.thresholds.boot_usage_critical_pct // 90' "$POLICY")"

printf "%-22s %-10s %-12s %s\n" "vm" "usage" "path" "detail"

failures=0
checked=0
skipped=0

while IFS=$'\t' read -r hostname ssh_target ssh_user; do
  [[ -n "$hostname" ]] || continue

  [[ -n "$ssh_target" && "$ssh_target" != "null" ]] || ssh_target="$hostname"
  resolved="$(ssh_resolve_ssh_host_with_fallback "$ssh_target" 5 2>/dev/null || true)"
  resolved_host="$(awk '{print $1}' <<<"$resolved")"
  path_used="$(awk '{print $2}' <<<"$resolved")"

  if [[ -z "$resolved_host" || "$path_used" == "unreachable" ]]; then
    printf "%-22s %-10s %-12s %s\n" "$hostname" "SKIP" "g1-owned" "unreachable"
    skipped=$((skipped + 1))
    continue
  fi

  checked=$((checked + 1))
  ssh_user="$(ssh_resolve_user "$ssh_target" "${ssh_user:-ubuntu}")"
  boot_pct="$(
    ssh -n \
      -o ConnectTimeout=8 \
      -o BatchMode=yes \
      -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null \
      "${ssh_user}@${resolved_host}" \
      "df -P / 2>/dev/null | tail -1 | awk '{print \$5}' | tr -d ' %'" \
      2>/dev/null || true
  )"

  if [[ ! "$boot_pct" =~ ^[0-9]+$ ]]; then
    printf "%-22s %-10s %-12s %s\n" "$hostname" "FAIL" "$path_used" "unable to read boot usage"
    failures=$((failures + 1))
    continue
  fi

  if [[ "$boot_pct" -ge "$crit_pct" ]]; then
    printf "%-22s %-10s %-12s %s\n" "$hostname" "${boot_pct}%" "$path_used" "critical threshold ${crit_pct}%"
    failures=$((failures + 1))
  elif [[ "$boot_pct" -ge "$warn_pct" ]]; then
    printf "%-22s %-10s %-12s %s\n" "$hostname" "${boot_pct}%" "$path_used" "warning threshold ${warn_pct}%"
    failures=$((failures + 1))
  else
    printf "%-22s %-10s %-12s %s\n" "$hostname" "${boot_pct}%" "$path_used" "ok"
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
  echo "G2 FAIL: no reachable VMs available for boot drive audit" >&2
  exit 1
fi

if [[ "$failures" -gt 0 ]]; then
  echo "G2 FAIL: boot drive health failures=${failures}/${checked} (skipped=${skipped})" >&2
  exit 1
fi

echo "G2 PASS: boot drive usage below thresholds (${checked} checked, ${skipped} skipped)"

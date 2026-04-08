#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CONTRACT="$ROOT/ops/bindings/domains/media/media.pipeline.contract.yaml"
VM_BINDING="$ROOT/ops/bindings/vm.lifecycle.yaml"
source "$ROOT/ops/lib/ssh-resolve.sh"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "G4 FAIL: missing dependency: $1" >&2
    exit 2
  }
}

need_cmd yq
need_cmd ssh

[[ -f "$CONTRACT" ]] || {
  echo "G4 FAIL: missing media pipeline contract: $CONTRACT" >&2
  exit 2
}
[[ -f "$VM_BINDING" ]] || {
  echo "G4 FAIL: missing vm lifecycle binding: $VM_BINDING" >&2
  exit 2
}

printf "%-18s %-8s %-12s %s\n" "host" "status" "mode" "detail"

failures=0
checked=0

while IFS=$'\t' read -r host source_path mount_path expected_mode; do
  [[ -n "$host" ]] || continue
  if ! yq e -e ".vms[] | select(.hostname == \"$host\" and .status == \"active\")" "$VM_BINDING" >/dev/null 2>&1; then
    continue
  fi

  checked=$((checked + 1))
  resolved="$(ssh_resolve_ssh_host_with_fallback "$host" 5 2>/dev/null || true)"
  resolved_host="$(awk '{print $1}' <<<"$resolved")"
  path_used="$(awk '{print $2}' <<<"$resolved")"
  ssh_user="$(ssh_resolve_user "$host" ubuntu)"

  if [[ -z "$resolved_host" || "$path_used" == "unreachable" ]]; then
    printf "%-18s %-8s %-12s %s\n" "$host" "FAIL" "$expected_mode" "unreachable"
    failures=$((failures + 1))
    continue
  fi

  mount_row="$(
    ssh -n \
      -o ConnectTimeout=8 \
      -o BatchMode=yes \
      -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null \
      "${ssh_user}@${resolved_host}" \
      "findmnt -rn -T '$mount_path' -t nfs,nfs4 -o SOURCE,OPTIONS" \
      2>/dev/null || true
  )"

  if [[ -z "$mount_row" ]]; then
    printf "%-18s %-8s %-12s %s\n" "$host" "FAIL" "$expected_mode" "missing $mount_path"
    failures=$((failures + 1))
    continue
  fi

  actual_source="${mount_row%% *}"
  actual_opts="${mount_row#* }"
  if [[ "$actual_source" != *":${source_path#*:}" ]]; then
    printf "%-18s %-8s %-12s %s\n" "$host" "FAIL" "$expected_mode" "source=$actual_source"
    failures=$((failures + 1))
    continue
  fi

  if [[ "$expected_mode" == "rw" && ! "$actual_opts" =~ (^|,)rw($|,) ]]; then
    printf "%-18s %-8s %-12s %s\n" "$host" "FAIL" "$expected_mode" "opts=$actual_opts"
    failures=$((failures + 1))
    continue
  fi
  if [[ "$expected_mode" == "ro" && ! "$actual_opts" =~ (^|,)ro($|,) ]]; then
    printf "%-18s %-8s %-12s %s\n" "$host" "FAIL" "$expected_mode" "opts=$actual_opts"
    failures=$((failures + 1))
    continue
  fi

  printf "%-18s %-8s %-12s %s\n" "$host" "PASS" "$expected_mode" "$path_used $mount_path"
done < <(
  yq e -r '
    .nfs_health
    | to_entries[]
    | select((.value.classification // "") == "canonical_active")
    | [.key, (.value.source // ""), (.value.mount // ""), (.value.mode // "rw")]
    | @tsv
  ' "$CONTRACT"
)

if [[ "$checked" -eq 0 ]]; then
  echo "G4 FAIL: no active canonical NFS mounts declared" >&2
  exit 1
fi

if [[ "$failures" -gt 0 ]]; then
  echo "G4 FAIL: nfs mount failures=${failures}/${checked}" >&2
  exit 1
fi

echo "G4 PASS: canonical NFS mounts healthy (${checked})"

#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
VM_BINDING="$ROOT/ops/bindings/vm.lifecycle.yaml"
source "$ROOT/ops/lib/ssh-resolve.sh"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "G9 FAIL: missing dependency: $1" >&2
    exit 2
  }
}

need_cmd yq
need_cmd ssh

[[ -f "$VM_BINDING" ]] || {
  echo "G9 FAIL: missing vm lifecycle binding: $VM_BINDING" >&2
  exit 2
}

printf "%-22s %-10s %s\n" "host" "status" "detail"

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
    printf "%-22s %-10s %s\n" "$hostname" "SKIP" "unreachable (owned by G1)"
    skipped=$((skipped + 1))
    continue
  fi

  checked=$((checked + 1))
  ssh_user="$(ssh_resolve_user "$ssh_target" "${ssh_user:-ubuntu}")"
  remote_output="$(
    ssh -n \
      -o ConnectTimeout=8 \
      -o BatchMode=yes \
      -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null \
      "${ssh_user}@${resolved_host}" \
      "if command -v docker >/dev/null 2>&1; then docker ps -a --format '{{.Names}}|{{.Status}}'; elif command -v sudo >/dev/null 2>&1 && sudo -n docker info >/dev/null 2>&1; then sudo -n docker ps -a --format '{{.Names}}|{{.Status}}'; else echo '__NO_DOCKER__'; fi" \
      2>/dev/null || true
  )"

  if [[ "$remote_output" == "__NO_DOCKER__" || -z "$remote_output" ]]; then
    printf "%-22s %-10s %s\n" "$hostname" "SKIP" "no docker runtime"
    skipped=$((skipped + 1))
    continue
  fi

  host_fail=0
  while IFS='|' read -r container_name container_status; do
    [[ -n "$container_name" ]] || continue
    if [[ "$container_status" == *"Exited"* || "$container_status" == *"Dead"* || "$container_status" == *"Restarting"* || "$container_status" == *"(unhealthy)"* ]]; then
      printf "%-22s %-10s %s\n" "$hostname" "FAIL" "${container_name}: ${container_status}"
      failures=$((failures + 1))
      host_fail=1
    fi
  done <<< "$remote_output"

  if [[ "$host_fail" -eq 0 ]]; then
    container_count="$(printf '%s\n' "$remote_output" | sed '/^$/d' | wc -l | tr -d ' ')"
    printf "%-22s %-10s %s\n" "$hostname" "PASS" "containers=${container_count} path=${path_used}"
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
  echo "G9 FAIL: no reachable hosts available for docker checks" >&2
  exit 1
fi

if [[ "$failures" -gt 0 ]]; then
  echo "G9 FAIL: unhealthy docker containers detected" >&2
  exit 1
fi

echo "G9 PASS: docker containers healthy (${checked} checked, ${skipped} skipped)"

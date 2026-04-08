#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
NAS_STATUS="$ROOT/ops/plugins/infra/observability/bin/nas-health-status"
source "$ROOT/ops/lib/ssh-resolve.sh"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "G3 FAIL: missing dependency: $1" >&2
    exit 2
  }
}

need_cmd ssh

[[ -x "$NAS_STATUS" ]] || {
  echo "G3 FAIL: missing NAS health probe: $NAS_STATUS" >&2
  exit 2
}

failures=0

run_remote() {
  local target_id="$1"
  local user_default="$2"
  local command="$3"
  local resolved resolved_host ssh_user

  resolved="$(ssh_resolve_ssh_host_with_fallback "$target_id" 5 2>/dev/null || true)"
  resolved_host="$(awk '{print $1}' <<<"$resolved")"
  [[ -n "$resolved_host" ]] || return 1
  ssh_user="$(ssh_resolve_user "$target_id" "$user_default")"
  ssh -n \
    -o ConnectTimeout=8 \
    -o BatchMode=yes \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    "${ssh_user}@${resolved_host}" \
    "$command" 2>/dev/null
}

echo "==> pve zpool health"
pve_pools="$(run_remote pve root "zpool list -H -o name,health,capacity" || true)"
if [[ -z "$pve_pools" ]]; then
  echo "G3 FAIL: unable to read zpool status from pve" >&2
  failures=$((failures + 1))
else
  while read -r pool_name pool_health pool_capacity; do
    [[ -n "$pool_name" ]] || continue
    cap_pct="${pool_capacity%\%}"
    if [[ "$pool_health" != "ONLINE" ]]; then
      echo "  FAIL: $pool_name health=$pool_health capacity=$pool_capacity" >&2
      failures=$((failures + 1))
      continue
    fi
    if [[ "$cap_pct" =~ ^[0-9]+$ ]] && [[ "$cap_pct" -ge 90 ]]; then
      echo "  FAIL: $pool_name capacity=$pool_capacity" >&2
      failures=$((failures + 1))
      continue
    fi
    echo "  PASS: $pool_name health=$pool_health capacity=$pool_capacity"
  done <<< "$pve_pools"
fi

echo
echo "==> md1400 mounts"
for target_id in pve archive-smb; do
  resolved="$(ssh_resolve_ssh_host_with_fallback "$target_id" 5 2>/dev/null || true)"
  resolved_host="$(awk '{print $1}' <<<"$resolved")"
  resolved_path="$(awk '{print $2}' <<<"$resolved")"
  if [[ -z "$resolved_host" || "$resolved_path" == "unreachable" ]]; then
    echo "  SKIP: $target_id unreachable (owned by G1)"
    continue
  fi
  mount_row="$(run_remote "$target_id" root "findmnt -rn -T /md1400 -o SOURCE,TARGET,FSTYPE" || true)"
  if [[ -z "$mount_row" ]]; then
    echo "  FAIL: $target_id missing /md1400 mount" >&2
    failures=$((failures + 1))
  else
    echo "  PASS: $target_id $mount_row"
  fi
done

echo
echo "==> nas storage health"
set +e
nas_output="$("$NAS_STATUS" 2>&1)"
nas_rc=$?
set -e
printf '%s\n' "$nas_output"
if [[ "$nas_rc" -ne 0 ]]; then
  failures=$((failures + 1))
fi

if [[ "$failures" -gt 0 ]]; then
  echo "G3 FAIL: storage pool health failures=$failures" >&2
  exit 1
fi

echo "G3 PASS: storage pools healthy"

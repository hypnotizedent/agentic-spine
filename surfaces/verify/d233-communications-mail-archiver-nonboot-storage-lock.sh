#!/usr/bin/env bash
# TRIAGE: D233 communications-mail-archiver-nonboot-storage-lock
# Enforces: mail-archiver high-write paths are bind-mounted to non-boot storage on communications-stack
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
source "$ROOT/surfaces/verify/lib/tailscale-guard.sh"
require_tailscale_for "communications-stack"

VM_BINDING="$ROOT/ops/bindings/vm.lifecycle.yaml"
COMMS_CONTRACT="$ROOT/ops/bindings/communications.stack.contract.yaml"
SSH_BINDING="$ROOT/ops/bindings/ssh.targets.yaml"

ERRORS=0
err() { echo "  FAIL: $*" >&2; ERRORS=$((ERRORS + 1)); }
ok() { [[ "${DRIFT_VERBOSE:-0}" == "1" ]] && echo "  OK: $*" || true; }

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

COMMS_IP=$(yq -r '.vms[] | select(.hostname == "communications-stack") | .lan_ip // .tailscale_ip' "$VM_BINDING" 2>/dev/null || echo "")
COMMS_USER=$(yq -r '.vms[] | select(.hostname == "communications-stack") | .ssh_user // "ubuntu"' "$VM_BINDING" 2>/dev/null || echo "ubuntu")
COMMS_POLICY="$(yq -r '.ssh.targets[] | select(.id == "communications-stack") | .access_policy // "lan_first"' "$SSH_BINDING" 2>/dev/null || echo "lan_first")"

if [[ -z "$COMMS_IP" || "$COMMS_IP" == "null" ]]; then
  err "communications-stack host not found in vm.lifecycle binding"
fi

if [[ "$ERRORS" -gt 0 ]]; then
  echo "D233 FAIL: $ERRORS check(s) failed"
  exit 1
fi

SSH_REF="${COMMS_USER}@${COMMS_IP}"
SSH_OPTS="-o ConnectTimeout=10 -o BatchMode=yes"
NONBOOT_ROOT="$(yq -r '.mail_archiver.storage_invariants.nonboot_root // "/srv/mail-archiver"' "$COMMS_CONTRACT" 2>/dev/null || echo "/srv/mail-archiver")"

mapfile -t REQUIRED_MOUNTS < <(yq -r '.mail_archiver.storage_invariants.required_bind_mounts[]? | [.container, .destination, .source_prefix] | @tsv' "$COMMS_CONTRACT" 2>/dev/null || true)
if [[ "${#REQUIRED_MOUNTS[@]}" -eq 0 ]]; then
  REQUIRED_MOUNTS=(
    $'mail-archiver\t/app/uploads\t/srv/mail-archiver/uploads'
    $'mail-archiver\t/tmp\t/srv/mail-archiver/tmp'
    $'mail-archiver-db\t/var/lib/postgresql/data\t/srv/mail-archiver/postgres-data'
  )
fi

ssh_cmd() {
  ssh $SSH_OPTS "$SSH_REF" "$@" 2>/dev/null
}

if [[ "$COMMS_POLICY" == "lan_first" ]] && is_off_lan_context "$COMMS_IP"; then
  echo "D233 SKIP: communications-stack off-LAN context for lan_first target ($SSH_REF)"
  exit 0
fi

if ! ssh_cmd "true" >/dev/null; then
  if [[ "$COMMS_POLICY" == "lan_first" ]] && is_off_lan_context "$COMMS_IP"; then
    echo "D233 SKIP: communications-stack unreachable from current off-LAN context (lan_first target: $SSH_REF)"
    exit 0
  fi
  err "ssh reachability failed for communications-stack ($SSH_REF)"
fi

ROOT_FS_DEV="$(ssh_cmd "findmnt -n -o SOURCE --target /" || true)"
DATA_FS_DEV="$(ssh_cmd "findmnt -n -o SOURCE --target ${NONBOOT_ROOT}" || true)"

if [[ -z "$ROOT_FS_DEV" ]]; then
  err "could not resolve root filesystem device on communications-stack"
fi
if [[ -z "$DATA_FS_DEV" ]]; then
  err "could not resolve ${NONBOOT_ROOT} filesystem device on communications-stack"
fi
if [[ -n "$ROOT_FS_DEV" && -n "$DATA_FS_DEV" && "$ROOT_FS_DEV" == "$DATA_FS_DEV" ]]; then
  err "${NONBOOT_ROOT} resolves to root filesystem device ($ROOT_FS_DEV); expected non-boot data disk"
else
  ok "${NONBOOT_ROOT} is on non-root device ($DATA_FS_DEV)"
fi

container_running() {
  local container="$1"
  local running
  running="$(ssh_cmd "docker inspect ${container} --format '{{.State.Running}}' || echo false" || true)"
  [[ "$running" == "true" ]]
}

mount_source() {
  local container="$1"
  local destination="$2"
  ssh_cmd "docker inspect ${container} --format '{{range .Mounts}}{{if eq .Destination \"${destination}\"}}{{.Source}}{{end}}{{end}}'" || true
}

check_mount() {
  local container="$1"
  local destination="$2"
  local required_prefix="$3"

  local source_path
  source_path="$(mount_source "$container" "$destination" | tr -d '\r' | xargs || true)"

  if [[ -z "$source_path" ]]; then
    err "${container} missing bind mount for ${destination}"
    return
  fi

  if [[ "$source_path" != "${required_prefix}"* ]]; then
    err "${container} ${destination} source ${source_path} not under ${required_prefix}"
  else
    ok "${container} ${destination} source under ${required_prefix}"
  fi

  local source_dev
  source_dev="$(ssh_cmd "findmnt -n -o SOURCE --target '${source_path}' || true" || true)"
  if [[ -z "$source_dev" ]]; then
    err "${container} ${destination} source ${source_path} has unresolved backing device"
    return
  fi

  if [[ -n "$ROOT_FS_DEV" && "$source_dev" == "$ROOT_FS_DEV" ]]; then
    err "${container} ${destination} source ${source_path} resolves to root device ${ROOT_FS_DEV}"
    return
  fi

  if [[ -n "$DATA_FS_DEV" && "$source_dev" != "$DATA_FS_DEV" ]]; then
    err "${container} ${destination} source ${source_path} device ${source_dev} != ${NONBOOT_ROOT} device ${DATA_FS_DEV}"
    return
  fi

  ok "${container} ${destination} source ${source_path} resolves to non-boot device ${source_dev}"
}

declare -A CONTAINER_STATE=()

for entry in "${REQUIRED_MOUNTS[@]}"; do
  IFS=$'\t' read -r container destination source_prefix <<< "$entry"
  [[ -n "$container" && -n "$destination" && -n "$source_prefix" ]] || continue

  if [[ -z "${CONTAINER_STATE[$container]+x}" ]]; then
    if container_running "$container"; then
      CONTAINER_STATE[$container]="up"
    else
      CONTAINER_STATE[$container]="down"
      err "${container} container not running on communications-stack"
    fi
  fi

  [[ "${CONTAINER_STATE[$container]}" == "up" ]] || continue
  check_mount "$container" "$destination" "$source_prefix"
done

if [[ "$ERRORS" -gt 0 ]]; then
  echo "D233 FAIL: $ERRORS check(s) failed"
  exit 1
fi

echo "D233 PASS"
exit 0

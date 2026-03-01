#!/usr/bin/env bash
# TRIAGE: Advisory post-update health check for media services touched by watchtower in the last 24h.
set -euo pipefail

source "${SPINE_ROOT:-$HOME/code/agentic-spine}/surfaces/verify/lib/tailscale-guard.sh"
require_tailscale

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
SERVICES_FILE="$ROOT/ops/bindings/services.health.yaml"
VM_BINDING="$ROOT/ops/bindings/vm.lifecycle.yaml"

warn() {
  echo "  WARN: $*"
  WARNINGS=$((WARNINGS + 1))
}

ok() {
  [[ "${DRIFT_VERBOSE:-0}" == "1" ]] && echo "  OK: $*" || true
}

get_vm_ssh_ref() {
  local vm="$1"
  local target user

  target="$(yq -r ".vms[] | select(.hostname == \"$vm\") | .ssh_target // .hostname // \"\"" "$VM_BINDING" 2>/dev/null || true)"
  user="$(yq -r ".vms[] | select(.hostname == \"$vm\") | .ssh_user // \"\"" "$VM_BINDING" 2>/dev/null || true)"

  if [[ -z "$target" || "$target" == "null" ]]; then
    echo ""
    return 1
  fi

  if [[ -n "$user" && "$user" != "null" ]]; then
    echo "${user}@${target}"
  else
    echo "$target"
  fi
}

check_watchtower_updates() {
  local ssh_ref="$1"
  local output

  output="$(ssh -o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=no "$ssh_ref" '
set -euo pipefail
DOCKER_CMD="docker"
if ! docker ps >/dev/null 2>&1; then
  if command -v sudo >/dev/null 2>&1 && sudo -n docker ps >/dev/null 2>&1; then
    DOCKER_CMD="sudo -n docker"
  else
    echo "__NO_DOCKER__"
    exit 0
  fi
fi
LOGS="$($DOCKER_CMD logs watchtower --since 24h 2>&1 || true)"
if printf "%s\n" "$LOGS" | grep -Eiq "updated|updating|found new|pulling"; then
  echo "__UPDATED__"
else
  echo "__NO_UPDATES__"
fi
' 2>/dev/null || true)"

  if [[ -z "$output" ]]; then
    echo "__UNREACHABLE__"
    return 0
  fi

  echo "$output"
}

probe_host_endpoints() {
  local vm="$1"
  local endpoint_id url expect enabled http_code

  while IFS=$'\t' read -r endpoint_id url expect enabled; do
    [[ -n "$endpoint_id" ]] || continue
    [[ "$enabled" == "true" ]] || continue

    http_code="$(curl -fsS -o /dev/null -w '%{http_code}' --max-time 10 "$url" 2>/dev/null || true)"
    if [[ ! "$http_code" =~ ^[0-9]+$ ]]; then
      warn "${vm}: ${endpoint_id} probe failed (${url})"
      continue
    fi

    if [[ "$http_code" != "$expect" ]]; then
      warn "${vm}: ${endpoint_id} expected HTTP ${expect}, got ${http_code} (${url})"
      continue
    fi

    ok "${vm}: ${endpoint_id} healthy (http=${http_code})"
    CHECKED_ENDPOINTS=$((CHECKED_ENDPOINTS + 1))
  done < <(yq e -r ".endpoints[] | select(.host == \"$vm\") | [.id, .url, (.expect // 200), ((.enabled // true) | tostring)] | @tsv" "$SERVICES_FILE" 2>/dev/null || true)
}

command -v yq >/dev/null 2>&1 || { echo "D304 WARN: missing dependency yq"; exit 0; }
command -v curl >/dev/null 2>&1 || { echo "D304 WARN: missing dependency curl"; exit 0; }
command -v ssh >/dev/null 2>&1 || { echo "D304 WARN: missing dependency ssh"; exit 0; }
[[ -f "$SERVICES_FILE" ]] || { echo "D304 WARN: missing services health binding: $SERVICES_FILE"; exit 0; }
[[ -f "$VM_BINDING" ]] || { echo "D304 WARN: missing VM binding: $VM_BINDING"; exit 0; }

WARNINGS=0
CHECKED_ENDPOINTS=0
UPDATED_VMS=0

for vm in download-stack streaming-stack; do
  ssh_ref="$(get_vm_ssh_ref "$vm" 2>/dev/null || true)"
  if [[ -z "$ssh_ref" ]]; then
    warn "${vm}: no ssh target found in vm.lifecycle binding"
    continue
  fi

  watchtower_state="$(check_watchtower_updates "$ssh_ref")"
  case "$watchtower_state" in
    *__UPDATED__*)
      UPDATED_VMS=$((UPDATED_VMS + 1))
      echo "  INFO: ${vm}: watchtower updates detected in last 24h"
      probe_host_endpoints "$vm"
      ;;
    *__NO_UPDATES__*)
      ok "${vm}: no watchtower updates in last 24h"
      ;;
    *__NO_DOCKER__*)
      warn "${vm}: docker access unavailable for watchtower log check"
      ;;
    *)
      warn "${vm}: unreachable for watchtower log check"
      ;;
  esac
done

if (( UPDATED_VMS == 0 )); then
  echo "D304 PASS: no media watchtower updates detected in last 24h"
  exit 0
fi

if (( WARNINGS > 0 )); then
  echo "D304 WARN: post-update media health advisory warnings detected (warnings=$WARNINGS checked_endpoints=$CHECKED_ENDPOINTS updated_vms=$UPDATED_VMS)"
  exit 0
fi

echo "D304 PASS: watchtower post-update media health checks clean (checked_endpoints=$CHECKED_ENDPOINTS updated_vms=$UPDATED_VMS)"

#!/usr/bin/env bash
# TRIAGE: D109 media-compose-config-match-lock — Live containers match declared services in binding
# D109: Media Compose Config Match Lock
# Enforces: Running containers match services declared in media.services.yaml
set -euo pipefail

# Network gate — skip cleanly when Tailscale VPN is disconnected
source "${SPINE_ROOT:-$HOME/code/agentic-spine}/surfaces/verify/lib/tailscale-guard.sh"
require_tailscale_for "download-stack"

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
BINDING="$ROOT/ops/bindings/media.services.yaml"
VM_BINDING="$ROOT/ops/bindings/vm.lifecycle.yaml"

ERRORS=0
err() { echo "  FAIL: $*" >&2; ERRORS=$((ERRORS + 1)); }
ok() { [[ "${DRIFT_VERBOSE:-0}" == "1" ]] && echo "  OK: $*" || true; }

command -v yq >/dev/null 2>&1 || { err "yq not installed"; exit 1; }
command -v ssh >/dev/null 2>&1 || { err "ssh not installed"; exit 1; }

MEDIA_VMS=("download-stack" "streaming-stack")

get_vm_ssh_ref() {
  local vm="$1"
  local target user

  target=$(yq -r ".vms[] | select(.hostname == \"$vm\") | .ssh_target // .hostname // \"\"" "$VM_BINDING" 2>/dev/null || echo "")
  user=$(yq -r ".vms[] | select(.hostname == \"$vm\") | .ssh_user // \"\"" "$VM_BINDING" 2>/dev/null || echo "")

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

for vm in "${MEDIA_VMS[@]}"; do
  ssh_ref=$(get_vm_ssh_ref "$vm" 2>/dev/null || true)
  if [[ -z "$ssh_ref" ]]; then
    err "$vm: no ssh target found in vm.lifecycle binding"
    continue
  fi

  declared_services=$(yq -r ".services | to_entries[] | select(.value.vm == \"$vm\") | .key" "$BINDING" 2>/dev/null | sort)

  docker_cmd="docker"
  docker_out=$(ssh -o ConnectTimeout=10 -o BatchMode=yes "$ssh_ref" "docker ps --format '{{.Names}}'" 2>&1 || true)
  if echo "$docker_out" | grep -qi "permission denied while trying to connect to the docker api"; then
    docker_out=$(ssh -o ConnectTimeout=10 -o BatchMode=yes "$ssh_ref" "sudo -n docker ps --format '{{.Names}}'" 2>&1 || true)
    if echo "$docker_out" | grep -qi "^sudo: "; then
      err "$vm: docker socket permission denied and sudo fallback unavailable"
      continue
    fi
    docker_cmd="sudo -n docker"
  fi

  running_containers=$(printf '%s\n' "$docker_out" | sort)

  if [[ -z "$running_containers" ]]; then
    err "$vm: could not fetch running containers"
    continue
  fi

  for svc in $declared_services; do
    status=$(yq -r ".services[\"$svc\"].status // \"active\"" "$BINDING" 2>/dev/null)
    container=$(yq -r ".services[\"$svc\"].container // \"$svc\"" "$BINDING" 2>/dev/null)

    if [[ "$status" == "parked" || "$status" == "stopped" ]]; then
      if echo "$running_containers" | grep -q "^${container}$"; then
        ok "$svc on $vm: parked but still running (expected)"
      else
        ok "$svc on $vm: parked and stopped"
      fi
    else
      if echo "$running_containers" | grep -q "^${container}$"; then
        ok "$svc on $vm: running"
      else
        err "$svc on $vm: declared active but not running"
      fi
    fi
  done

  if [[ "$vm" == "download-stack" ]]; then
    poster_user=$(ssh -o ConnectTimeout=10 -o BatchMode=yes "$ssh_ref" "$docker_cmd inspect --format '{{.Config.User}}' posterizarr" 2>/dev/null || true)
    poster_config_src=$(ssh -o ConnectTimeout=10 -o BatchMode=yes "$ssh_ref" "$docker_cmd inspect --format '{{range .Mounts}}{{if eq .Destination \"/config\"}}{{.Source}}{{end}}{{end}}' posterizarr" 2>/dev/null || true)
    poster_owner=$(ssh -o ConnectTimeout=10 -o BatchMode=yes "$ssh_ref" "sudo -n stat -c '%u:%g' /mnt/docker/volumes/posterizarr" 2>/dev/null || true)
    flare_config_src=$(ssh -o ConnectTimeout=10 -o BatchMode=yes "$ssh_ref" "$docker_cmd inspect --format '{{range .Mounts}}{{if eq .Destination \"/config\"}}{{.Source}}{{end}}{{end}}' flaresolverr" 2>/dev/null || true)
    decy_app_src=$(ssh -o ConnectTimeout=10 -o BatchMode=yes "$ssh_ref" "$docker_cmd inspect --format '{{range .Mounts}}{{if eq .Destination \"/app\"}}{{.Source}}{{end}}{{end}}' decypharr" 2>/dev/null || true)

    case "$poster_user" in
      nobody:nogroup|65534:65533|65534) ok "posterizarr runtime user=$poster_user" ;;
      *) err "posterizarr runtime user='$poster_user' (expected nobody:nogroup or uid 65534)" ;;
    esac

    [[ "$poster_config_src" == /mnt/docker/volumes/posterizarr* ]] \
      || err "posterizarr /config source='$poster_config_src' (expected /mnt/docker/volumes/posterizarr*)"
    [[ "$poster_owner" == "65534:65533" ]] \
      || err "posterizarr config owner='$poster_owner' (expected 65534:65533)"

    [[ "$flare_config_src" == /mnt/docker/volumes/flaresolverr/config* ]] \
      || err "flaresolverr /config source='$flare_config_src' (expected /mnt/docker/volumes/flaresolverr/config*)"
    [[ "$flare_config_src" != /var/lib/docker/volumes/* ]] \
      || err "flaresolverr /config backed by docker volume ('$flare_config_src') (expected bind mount)"

    [[ "$decy_app_src" == /mnt/docker/volumes/decypharr/app* ]] \
      || err "decypharr /app source='$decy_app_src' (expected /mnt/docker/volumes/decypharr/app*)"
    [[ "$decy_app_src" != /var/lib/docker/volumes/* ]] \
      || err "decypharr /app backed by docker volume ('$decy_app_src') (expected bind mount)"
  fi
done

if [[ "$ERRORS" -gt 0 ]]; then
  echo "D109 FAIL: $ERRORS check(s) failed"
  exit 1
fi

ok "All declared services match running state"
exit 0

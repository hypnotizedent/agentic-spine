#!/usr/bin/env bash
# TRIAGE: Keep Privado VPN policy canonical: gluetun healthy, slskd tunneled via gluetun, and qBittorrent route mode matching ops/bindings/vpn.provider.yaml.
# D223: Media VPN Routing Lock
# Enforces: VPN provider binding, compose wiring, and live container routing parity
set -euo pipefail

# Network gate — skip cleanly when Tailscale VPN is disconnected.
source "${SPINE_ROOT:-$HOME/code/agentic-spine}/surfaces/verify/lib/tailscale-guard.sh"
require_tailscale_for "download-stack"

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
VPN_BINDING="$ROOT/ops/bindings/vpn.provider.yaml"
MEDIA_BINDING="$ROOT/ops/bindings/media.services.yaml"
VM_BINDING="$ROOT/ops/bindings/vm.lifecycle.yaml"
COMPOSE="$ROOT/ops/staged/download-stack/docker-compose.yml"

ERRORS=0
err() { echo "  FAIL: $*" >&2; ERRORS=$((ERRORS + 1)); }
ok() { [[ "${DRIFT_VERBOSE:-0}" == "1" ]] && echo "  OK: $*" || true; }

command -v yq >/dev/null 2>&1 || { err "yq not installed"; exit 1; }
command -v ssh >/dev/null 2>&1 || { err "ssh not installed"; exit 1; }

for file in "$VPN_BINDING" "$MEDIA_BINDING" "$VM_BINDING" "$COMPOSE"; do
  [[ -f "$file" ]] || { err "missing required file: $file"; exit 1; }
done

provider="$(yq -r '.provider.id // ""' "$VPN_BINDING" 2>/dev/null || true)"
if [[ "$provider" != "privado" ]]; then
  err "vpn.provider.yaml provider.id='$provider' (expected 'privado')"
else
  ok "provider.id=privado"
fi

qbt_policy="$(yq -r '.routing.services.qbittorrent.route_mode // ""' "$VPN_BINDING" 2>/dev/null || true)"
slskd_policy="$(yq -r '.routing.services.slskd.route_mode // ""' "$VPN_BINDING" 2>/dev/null || true)"

if [[ "$slskd_policy" != "via_tunnel" ]]; then
  err "slskd route_mode='$slskd_policy' (expected 'via_tunnel')"
fi
if [[ "$qbt_policy" != "direct" && "$qbt_policy" != "via_tunnel" ]]; then
  err "qbittorrent route_mode='$qbt_policy' (expected 'direct' or 'via_tunnel')"
fi

media_qbt_policy="$(yq -r '.vpn_policy.services.qbittorrent.route_mode // ""' "$MEDIA_BINDING" 2>/dev/null || true)"
media_slskd_policy="$(yq -r '.vpn_policy.services.slskd.route_mode // ""' "$MEDIA_BINDING" 2>/dev/null || true)"

if [[ "$media_qbt_policy" != "$qbt_policy" ]]; then
  err "media.services vpn_policy qBittorrent='$media_qbt_policy' != vpn.provider '$qbt_policy'"
fi
if [[ "$media_slskd_policy" != "$slskd_policy" ]]; then
  err "media.services vpn_policy slskd='$media_slskd_policy' != vpn.provider '$slskd_policy'"
fi

compose_provider="$(yq -r '.services.gluetun.environment[]? | select(test("^VPN_SERVICE_PROVIDER="))' "$COMPOSE" 2>/dev/null || true)"
compose_user="$(yq -r '.services.gluetun.environment[]? | select(test("^OPENVPN_USER="))' "$COMPOSE" 2>/dev/null || true)"
compose_pass="$(yq -r '.services.gluetun.environment[]? | select(test("^OPENVPN_PASSWORD="))' "$COMPOSE" 2>/dev/null || true)"
compose_slskd_network="$(yq -r '.services.slskd.network_mode // ""' "$COMPOSE" 2>/dev/null || true)"
compose_qbt_network="$(yq -r '.services.qbittorrent.network_mode // "bridge"' "$COMPOSE" 2>/dev/null || true)"

[[ "$compose_provider" == "VPN_SERVICE_PROVIDER=privado" ]] || err "gluetun provider env mismatch: '$compose_provider'"
[[ "$compose_user" == 'OPENVPN_USER=${PRIVADO_VPN_USER}' ]] || err "gluetun OPENVPN_USER env mismatch: '$compose_user'"
[[ "$compose_pass" == 'OPENVPN_PASSWORD=${PRIVADO_VPN_PASS}' ]] || err "gluetun OPENVPN_PASSWORD env mismatch: '$compose_pass'"
[[ "$compose_slskd_network" == "service:gluetun" ]] || err "slskd network_mode='$compose_slskd_network' (expected 'service:gluetun')"

if [[ "$qbt_policy" == "direct" ]]; then
  if [[ "$compose_qbt_network" == "service:gluetun" ]]; then
    err "qBittorrent policy=direct but compose routes via gluetun"
  else
    ok "qBittorrent compose route mode is direct ($compose_qbt_network)"
  fi
elif [[ "$qbt_policy" == "via_tunnel" ]]; then
  [[ "$compose_qbt_network" == "service:gluetun" ]] || err "qBittorrent policy=via_tunnel but compose network_mode='$compose_qbt_network'"
fi

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

ssh_ref="$(get_vm_ssh_ref "download-stack" 2>/dev/null || true)"
if [[ -z "$ssh_ref" ]]; then
  err "download-stack: no ssh target found in vm.lifecycle.yaml"
fi

inspect_container() {
  local container="$1"
  local cmd out
  cmd="docker inspect --type container --format '{{.State.Status}}|{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}|{{.HostConfig.NetworkMode}}|{{.Id}}' $container"
  out="$(ssh -o ConnectTimeout=10 -o BatchMode=yes "$ssh_ref" "$cmd" 2>&1 || true)"

  if echo "$out" | grep -qi "permission denied while trying to connect to the docker api"; then
    out="$(ssh -o ConnectTimeout=10 -o BatchMode=yes "$ssh_ref" "sudo -n $cmd" 2>&1 || true)"
    if echo "$out" | grep -qi "^sudo: "; then
      err "$container: docker socket permission denied and sudo fallback unavailable"
      return 1
    fi
  fi

  if echo "$out" | grep -qi "No such object"; then
    err "$container: container not found on download-stack"
    return 1
  fi

  if [[ -z "$out" ]]; then
    err "$container: empty docker inspect response"
    return 1
  fi

  printf '%s\n' "$out"
}

if [[ -n "$ssh_ref" ]]; then
  gluetun_info="$(inspect_container "gluetun" || true)"
  slskd_info="$(inspect_container "slskd" || true)"
  qbt_info="$(inspect_container "qbittorrent" || true)"
  gluetun_id=""

  if [[ -n "$gluetun_info" ]]; then
    IFS='|' read -r gluetun_state gluetun_health gluetun_network gluetun_id <<< "$gluetun_info"
    [[ "$gluetun_state" == "running" ]] || err "gluetun state='$gluetun_state' (expected running)"
    [[ "$gluetun_health" == "healthy" ]] || err "gluetun health='$gluetun_health' (expected healthy)"
    ok "gluetun state=$gluetun_state health=$gluetun_health network_mode=$gluetun_network"
  fi

  if [[ -n "$slskd_info" ]]; then
    IFS='|' read -r slskd_state slskd_health slskd_network _slskd_id <<< "$slskd_info"
    [[ "$slskd_state" == "running" ]] || err "slskd state='$slskd_state' (expected running)"
    if [[ "$slskd_network" != "container:gluetun" ]]; then
      if [[ -n "$gluetun_id" && "$slskd_network" != "container:$gluetun_id" ]]; then
        err "slskd network_mode='$slskd_network' (expected container:gluetun or container:$gluetun_id)"
      elif [[ -z "$gluetun_id" && "$slskd_network" != container:* ]]; then
        err "slskd network_mode='$slskd_network' (expected container:* routing)"
      fi
    fi
    ok "slskd state=$slskd_state health=$slskd_health network_mode=$slskd_network"
  fi

  if [[ -n "$qbt_info" ]]; then
    IFS='|' read -r qbt_state qbt_health qbt_network _qbt_id <<< "$qbt_info"
    [[ "$qbt_state" == "running" ]] || err "qbittorrent state='$qbt_state' (expected running)"

    if [[ "$qbt_policy" == "direct" ]]; then
      if [[ "$qbt_network" == "container:gluetun" ]]; then
        err "qbittorrent policy=direct but runtime network_mode='$qbt_network'"
      else
        ok "qbittorrent runtime route mode is direct ($qbt_network)"
      fi
    elif [[ "$qbt_policy" == "via_tunnel" ]]; then
      if [[ "$qbt_network" != "container:gluetun" ]]; then
        if [[ -n "$gluetun_id" && "$qbt_network" != "container:$gluetun_id" ]]; then
          err "qbittorrent policy=via_tunnel but runtime network_mode='$qbt_network'"
        elif [[ -z "$gluetun_id" && "$qbt_network" != container:* ]]; then
          err "qbittorrent policy=via_tunnel but runtime network_mode='$qbt_network'"
        fi
      fi
    fi
  fi
fi

if [[ "$ERRORS" -gt 0 ]]; then
  echo "D223 FAIL: $ERRORS check(s) failed"
  exit 1
fi

echo "D223 PASS"
exit 0

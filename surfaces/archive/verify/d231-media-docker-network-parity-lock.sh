#!/usr/bin/env bash
# TRIAGE: D231 media-docker-network-parity-lock — Lidarr connected to both music-net and default compose network
# D231: Media Docker Network Parity Lock
# Enforces: Lidarr container attached to >=2 networks (music-net + default); DNS connectivity to sabnzbd on default network
set -euo pipefail

source "${SPINE_ROOT:-$HOME/code/agentic-spine}/surfaces/verify/lib/tailscale-guard.sh"
require_tailscale_for "download-stack"

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
VM_BINDING="$ROOT/ops/bindings/vm.lifecycle.yaml"

ERRORS=0
err() { echo "  FAIL: $*" >&2; ERRORS=$((ERRORS + 1)); }
ok() { [[ "${DRIFT_VERBOSE:-0}" == "1" ]] && echo "  OK: $*" || true; }

# Resolve SSH target for download-stack
DS_IP=$(yq -r '.vms[] | select(.hostname == "download-stack") | .lan_ip // .tailscale_ip' "$VM_BINDING" 2>/dev/null || echo "")
DS_USER=$(yq -r '.vms[] | select(.hostname == "download-stack") | .ssh_user // "ubuntu"' "$VM_BINDING" 2>/dev/null || echo "ubuntu")

if [[ -z "$DS_IP" || "$DS_IP" == "null" ]]; then
  echo "SKIP: download-stack not found in vm.lifecycle binding"
  exit 0
fi

SSH_REF="${DS_USER}@${DS_IP}"
SSH_OPTS="-o ConnectTimeout=10 -o BatchMode=yes"

# Check if Lidarr container is running
LIDARR_RUNNING=$(ssh $SSH_OPTS "$SSH_REF" 'sudo docker inspect lidarr --format "{{.State.Running}}" 2>/dev/null || echo "false"' 2>/dev/null || echo "false")

if [[ "$LIDARR_RUNNING" != "true" ]]; then
  echo "SKIP: Lidarr container not running on download-stack"
  exit 0
fi

# Check 1: Lidarr connected to at least 2 networks (music-net + default compose network)
NETWORKS_JSON=$(ssh $SSH_OPTS "$SSH_REF" 'sudo docker inspect lidarr --format "{{json .NetworkSettings.Networks}}" 2>/dev/null || echo "{}"' 2>/dev/null || echo "{}")

NETWORK_COUNT=$(echo "$NETWORKS_JSON" | jq 'keys | length' 2>/dev/null || echo "0")
NETWORK_NAMES=$(echo "$NETWORKS_JSON" | jq -r 'keys | join(", ")' 2>/dev/null || echo "none")

if [[ "$NETWORK_COUNT" -lt 2 ]]; then
  err "Lidarr attached to $NETWORK_COUNT network(s) ($NETWORK_NAMES) — expected >=2 (music-net + default compose network)"
else
  ok "Lidarr attached to $NETWORK_COUNT networks: $NETWORK_NAMES"
fi

# Check 2: Verify music-net is one of the attached networks
HAS_MUSIC_NET=$(echo "$NETWORKS_JSON" | jq 'has("music-net")' 2>/dev/null || echo "false")
if [[ "$HAS_MUSIC_NET" != "true" ]]; then
  err "Lidarr not connected to music-net (required for slskd/soularr communication)"
else
  ok "Lidarr connected to music-net"
fi

# Check 3: DNS connectivity — Lidarr can resolve sabnzbd (proves default compose network works)
SAB_RESOLVE=$(ssh $SSH_OPTS "$SSH_REF" 'sudo docker exec lidarr getent hosts sabnzbd 2>/dev/null | head -1 || echo ""' 2>/dev/null || echo "")

if [[ -z "$SAB_RESOLVE" ]]; then
  err "Lidarr cannot resolve 'sabnzbd' via DNS (default compose network connectivity broken)"
else
  ok "Lidarr can resolve sabnzbd: $SAB_RESOLVE"
fi

# --- Result ---
if [[ "$ERRORS" -gt 0 ]]; then
  echo "D231 FAIL: $ERRORS check(s) failed"
  exit 1
fi

echo "D231 PASS"
exit 0

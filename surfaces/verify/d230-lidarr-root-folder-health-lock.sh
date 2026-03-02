#!/usr/bin/env bash
# TRIAGE: D230 lidarr-root-folder-health-lock — Lidarr root folder accessible and no RootFolderCheck health errors
# D230: Lidarr Root Folder Health Lock
# Enforces: At least one Lidarr root folder exists and is accessible; no RootFolderCheck health alerts
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

# Get Lidarr API key from config.xml inside container
API_KEY=$(ssh $SSH_OPTS "$SSH_REF" 'sudo docker exec lidarr cat /config/config.xml 2>/dev/null | grep -oP "(?<=<ApiKey>)[^<]+" || echo ""' 2>/dev/null || echo "")

if [[ -z "$API_KEY" ]]; then
  err "Could not extract Lidarr API key from /config/config.xml"
else
  # Check 1: Root folder exists and is accessible
  ROOT_FOLDER_JSON=$(ssh $SSH_OPTS "$SSH_REF" "curl -sS -m 10 -H 'X-Api-Key: ${API_KEY}' 'http://localhost:8686/api/v1/rootfolder' 2>/dev/null" || echo "[]")

  FOLDER_COUNT=$(echo "$ROOT_FOLDER_JSON" | jq 'length' 2>/dev/null || echo "0")
  if [[ "$FOLDER_COUNT" -eq 0 ]]; then
    err "Lidarr has no root folders configured"
  else
    ok "Lidarr has $FOLDER_COUNT root folder(s)"

    # Check each folder's accessible flag
    INACCESSIBLE=$(echo "$ROOT_FOLDER_JSON" | jq '[.[] | select(.accessible == false)] | length' 2>/dev/null || echo "0")
    if [[ "$INACCESSIBLE" -gt 0 ]]; then
      PATHS=$(echo "$ROOT_FOLDER_JSON" | jq -r '.[] | select(.accessible == false) | .path' 2>/dev/null || echo "unknown")
      err "Lidarr has $INACCESSIBLE inaccessible root folder(s): $PATHS"
    else
      ok "All Lidarr root folders accessible"
    fi
  fi

  # Check 2: No RootFolderCheck health errors
  HEALTH_JSON=$(ssh $SSH_OPTS "$SSH_REF" "curl -sS -m 10 -H 'X-Api-Key: ${API_KEY}' 'http://localhost:8686/api/v1/health' 2>/dev/null" || echo "[]")

  ROOT_ERRORS=$(echo "$HEALTH_JSON" | jq '[.[] | select(.source == "RootFolderCheck")] | length' 2>/dev/null || echo "0")
  if [[ "$ROOT_ERRORS" -gt 0 ]]; then
    MESSAGES=$(echo "$HEALTH_JSON" | jq -r '.[] | select(.source == "RootFolderCheck") | .message' 2>/dev/null || echo "unknown")
    err "Lidarr health has $ROOT_ERRORS RootFolderCheck error(s): $MESSAGES"
  else
    ok "No RootFolderCheck health errors"
  fi
fi

# --- Result ---
if [[ "$ERRORS" -gt 0 ]]; then
  echo "D230 FAIL: $ERRORS check(s) failed"
  exit 1
fi

echo "D230 PASS"
exit 0

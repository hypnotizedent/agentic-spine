#!/usr/bin/env bash
# TRIAGE: D228 jellyfin-introskipper-config-lock — IntroSkipper plugin settings prevent runaway analysis loops
# D228: Jellyfin IntroSkipper Config Lock
# Enforces: AutoDetectIntros=false, AnalyzeMovies=false, MaxParallelism<=2, unnecessary scan modes disabled
set -euo pipefail

source "${SPINE_ROOT:-$HOME/code/agentic-spine}/surfaces/verify/lib/tailscale-guard.sh"
require_tailscale

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
VM_BINDING="$ROOT/ops/bindings/vm.lifecycle.yaml"

ERRORS=0
err() { echo "  FAIL: $*" >&2; ERRORS=$((ERRORS + 1)); }
ok() { [[ "${DRIFT_VERBOSE:-0}" == "1" ]] && echo "  OK: $*" || true; }

STREAMING_IP=$(yq -r '.vms[] | select(.hostname == "streaming-stack") | .tailscale_ip // .lan_ip' "$VM_BINDING" 2>/dev/null || echo "")
STREAMING_USER=$(yq -r '.vms[] | select(.hostname == "streaming-stack") | .ssh_user // "ubuntu"' "$VM_BINDING" 2>/dev/null || echo "ubuntu")

if [[ -z "$STREAMING_IP" ]]; then
  err "streaming-stack IP not found in vm.lifecycle binding"
  echo "D228 FAIL: $ERRORS check(s) failed"
  exit 1
fi

SSH_REF="${STREAMING_USER}@${STREAMING_IP}"
SSH_OPTS="-o ConnectTimeout=10 -o BatchMode=yes"

# Fetch IntroSkipper config from Jellyfin container
CONFIG=$(ssh $SSH_OPTS "$SSH_REF" 'sudo docker exec jellyfin cat /config/plugins/configurations/IntroSkipper.xml 2>/dev/null' 2>/dev/null || echo "")

if [[ -z "$CONFIG" ]]; then
  echo "D228 SKIP: IntroSkipper plugin not installed or Jellyfin unreachable"
  exit 0
fi

# Helper: extract XML element value
xml_val() {
  local tag="$1"
  echo "$CONFIG" | grep -oP "(?<=<${tag}>)[^<]+" 2>/dev/null || echo ""
}

# --- Critical checks: prevent analysis loop ---

auto_detect=$(xml_val "AutoDetectIntros")
if [[ "$auto_detect" == "true" ]]; then
  err "AutoDetectIntros=true (causes re-analysis loop on library changes — must be false)"
else
  ok "AutoDetectIntros=false"
fi

analyze_movies=$(xml_val "AnalyzeMovies")
if [[ "$analyze_movies" == "true" ]]; then
  err "AnalyzeMovies=true (wasteful NFS reads scanning movies for intros — must be false)"
else
  ok "AnalyzeMovies=false"
fi

max_parallel=$(xml_val "MaxParallelism")
if [[ -n "$max_parallel" && "$max_parallel" -gt 2 ]]; then
  err "MaxParallelism=$max_parallel (>2 causes excessive NFS contention — must be <=2)"
else
  ok "MaxParallelism=${max_parallel:-default} (<=2)"
fi

# --- Scan mode checks: recap/preview/commercial add load with minimal value ---

scan_recap=$(xml_val "ScanRecap")
if [[ "$scan_recap" == "true" ]]; then
  err "ScanRecap=true (rarely useful, adds NFS load — should be false)"
else
  ok "ScanRecap=false"
fi

scan_preview=$(xml_val "ScanPreview")
if [[ "$scan_preview" == "true" ]]; then
  err "ScanPreview=true (rarely useful, adds NFS load — should be false)"
else
  ok "ScanPreview=false"
fi

scan_commercial=$(xml_val "ScanCommercial")
if [[ "$scan_commercial" == "true" ]]; then
  err "ScanCommercial=true (not applicable to streaming content — should be false)"
else
  ok "ScanCommercial=false"
fi

# --- Result ---
if [[ "$ERRORS" -gt 0 ]]; then
  echo "D228 FAIL: $ERRORS check(s) failed"
  exit 1
fi

echo "D228 PASS"
exit 0

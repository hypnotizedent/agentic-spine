#!/usr/bin/env bash
# TRIAGE: D109 media-compose-config-match-lock — Live containers match declared services in binding
# D109: Media Compose Config Match Lock
# Enforces: Running containers match services declared in media.services.yaml
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
BINDING="$ROOT/ops/bindings/media.services.yaml"

ERRORS=0
err() { echo "  FAIL: $*" >&2; ERRORS=$((ERRORS + 1)); }
ok() { [[ "${DRIFT_VERBOSE:-0}" == "1" ]] && echo "  OK: $*" || true; }

command -v yq >/dev/null 2>&1 || { err "yq not installed"; exit 1; }
command -v ssh >/dev/null 2>&1 || { err "ssh not installed"; exit 1; }

MEDIA_VMS=("download-stack" "streaming-stack")

for vm in "${MEDIA_VMS[@]}"; do
  declared_services=$(yq -r ".services | to_entries[] | select(.value.vm == \"$vm\") | .key" "$BINDING" 2>/dev/null | sort)

  running_containers=$(ssh -o ConnectTimeout=10 -o BatchMode=yes "$vm" "docker ps --format '{{.Names}}'" 2>/dev/null | sort || echo "")

  if [[ -z "$running_containers" ]]; then
    err "$vm: could not fetch running containers"
    continue
  fi

  for svc in $declared_services; do
    status=$(yq -r ".services[\"$svc\"].status // \"active\"" "$BINDING" 2>/dev/null)

    if [[ "$status" == "parked" || "$status" == "stopped" ]]; then
      if echo "$running_containers" | grep -q "^${svc}$"; then
        ok "$svc on $vm: parked but still running (expected)"
      else
        ok "$svc on $vm: parked and stopped"
      fi
    else
      if echo "$running_containers" | grep -q "^${svc}$"; then
        ok "$svc on $vm: running"
      else
        err "$svc on $vm: declared active but not running"
      fi
    fi
  done
done

if [[ "$ERRORS" -gt 0 ]]; then
  echo "D109 FAIL: $ERRORS check(s) failed"
  exit 1
fi

ok "All declared services match running state"
exit 0

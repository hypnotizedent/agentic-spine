#!/usr/bin/env bash
set -euo pipefail

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
REGISTRY="${SPINE_ROOT}/ops/bindings/launchd.scheduler.registry.yaml"

if [[ ! -f "$REGISTRY" ]]; then
  echo "[launchd-health-check] missing registry: $REGISTRY" >&2
  exit 2
fi
if ! command -v yq >/dev/null 2>&1; then
  echo "[launchd-health-check] missing yq" >&2
  exit 2
fi
if ! command -v launchctl >/dev/null 2>&1; then
  echo "[launchd-health-check] missing launchctl" >&2
  exit 2
fi

mapfile -t labels < <(yq -r '.labels[] | select(.state == "active" and .monitor == true) | .label' "$REGISTRY")
if [[ "${#labels[@]}" -eq 0 ]]; then
  echo "[launchd-health-check] no monitorable labels in registry"
  exit 0
fi

uid_val="$(id -u)"
missing=0
for label in "${labels[@]}"; do
  if launchctl print "gui/${uid_val}/${label}" >/dev/null 2>&1; then
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] OK ${label}"
  else
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] MISSING ${label}"
    missing=$((missing + 1))
  fi
done

echo "[launchd-health-check] labels=${#labels[@]} missing=${missing}"
[[ "$missing" -eq 0 ]]

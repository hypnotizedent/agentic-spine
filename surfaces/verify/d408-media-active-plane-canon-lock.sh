#!/usr/bin/env bash
# D408: Media Active Plane Canon Lock
# Enforces: media-home is the only active media plane; split-era VMs must not
#           be modeled as active read/write planes in the service binding.
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
BINDING="$ROOT/ops/bindings/media.services.yaml"

ERRORS=0
err() { echo "  FAIL: $*" >&2; ERRORS=$((ERRORS + 1)); }
ok() { [[ "${DRIFT_VERBOSE:-0}" == "1" ]] && echo "  OK: $*" || true; }

if [[ ! -f "$BINDING" ]]; then
  err "media.services.yaml not found"
  echo "D408 FAIL: 1 check(s) failed"
  exit 1
fi

command -v yq >/dev/null 2>&1 || { err "yq not installed"; exit 1; }

# Check 1: active_plane.vm must be media-home
ACTIVE_VM=$(yq -r '.operating_model.active_plane.vm // "MISSING"' "$BINDING" 2>/dev/null)
if [[ "$ACTIVE_VM" != "media-home" ]]; then
  err "operating_model.active_plane.vm is '$ACTIVE_VM', expected 'media-home'"
else
  ok "active_plane.vm = media-home"
fi

# Check 2: streaming-stack must not appear as a service VM for active (non-parked) streaming services
STREAMING_ACTIVE=$(yq -r '.services | to_entries[] | select(.value.vm == "streaming-stack" and .value.status == "active") | .key' "$BINDING" 2>/dev/null)
if [[ -n "$STREAMING_ACTIVE" ]]; then
  err "streaming-stack has active services (split-era active canon): $STREAMING_ACTIVE"
else
  ok "No active services on streaming-stack"
fi

# Check 3: download-stack must not have streaming category services
DL_STREAMING=$(yq -r '.services | to_entries[] | select(.value.vm == "download-stack" and .value.category == "streaming") | .key' "$BINDING" 2>/dev/null)
if [[ -n "$DL_STREAMING" ]]; then
  err "download-stack has streaming services (wrong plane): $DL_STREAMING"
else
  ok "No streaming services on download-stack"
fi

# Check 4: ports section must not have a streaming-stack key (renamed to media-home)
HAS_SS_PORTS=$(yq -r '.ports | has("streaming-stack")' "$BINDING" 2>/dev/null)
if [[ "$HAS_SS_PORTS" == "true" ]]; then
  err "ports section still uses 'streaming-stack' key — should be 'media-home'"
else
  ok "ports section uses media-home key"
fi

if [[ "$ERRORS" -gt 0 ]]; then
  echo "D408 FAIL: $ERRORS check(s) failed"
  exit 1
fi

ok "Media active plane canon lock: all checks passed"
exit 0

#!/usr/bin/env bash
# D408: Media Active Plane Canon Lock
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
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

ACTIVE_VM="$(yq -r '.operating_model.active_plane.vm // "MISSING"' "$BINDING" 2>/dev/null)"
if [[ "$ACTIVE_VM" != "media-home" ]]; then
  err "operating_model.active_plane.vm is '$ACTIVE_VM', expected 'media-home'"
else
  ok "active_plane.vm = media-home"
fi

STREAMING_ACTIVE="$(yq -r '.services | to_entries[] | select(.value.vm == "streaming-stack" and .value.status == "active") | .key' "$BINDING" 2>/dev/null || true)"
if [[ -n "$STREAMING_ACTIVE" ]]; then
  err "streaming-stack still has active services: $STREAMING_ACTIVE"
else
  ok "No active services on streaming-stack"
fi

DL_STREAMING="$(yq -r '.services | to_entries[] | select(.value.vm == "download-stack" and .value.category == "streaming") | .key' "$BINDING" 2>/dev/null || true)"
if [[ -n "$DL_STREAMING" ]]; then
  err "download-stack has streaming-category services: $DL_STREAMING"
else
  ok "No streaming-category services on download-stack"
fi

HAS_OLD_PORTS="$(yq -r '.ports | has("streaming-stack")' "$BINDING" 2>/dev/null || true)"
if [[ "$HAS_OLD_PORTS" == "true" ]]; then
  err "ports section still uses 'streaming-stack' key"
else
  ok "ports section uses media-home key"
fi

if [[ "$ERRORS" -gt 0 ]]; then
  echo "D408 FAIL: $ERRORS check(s) failed"
  exit 1
fi

ok "Media active plane canon lock passed"
exit 0

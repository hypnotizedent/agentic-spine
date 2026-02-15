#!/usr/bin/env bash
# TRIAGE: D110 media-ha-duplicate-audit-lock — Flag HA add-ons that duplicate shop media services
# D110: Media HA Duplicate Audit Lock
# Enforces: HA add-ons duplicating shop services are flagged for review
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
BINDING="$ROOT/ops/bindings/media.services.yaml"
HA_ADDONS="$ROOT/ops/bindings/ha.addons.yaml"

ERRORS=0
err() { echo "  FAIL: $*" >&2; ERRORS=$((ERRORS + 1)); }
ok() { [[ "${DRIFT_VERBOSE:-0}" == "1" ]] && echo "  OK: $*" || true; }
warn() { echo "  WARN: $*" >&2; }

command -v yq >/dev/null 2>&1 || { err "yq not installed"; exit 1; }

if [[ ! -f "$BINDING" ]]; then
  err "media.services.yaml binding not found"
  echo "D110 FAIL: 1 check(s) failed"
  exit 1
fi

if [[ ! -f "$HA_ADDONS" ]]; then
  warn "ha.addons.yaml not found — cannot audit HA overlap"
  echo "D110 WARN: ha.addons.yaml missing (run ha.addons.snapshot)"
  exit 0
fi

OVERLAPS=$(yq -r '.ha_overlaps.overlaps[] | .ha_addon' "$BINDING" 2>/dev/null || echo "")

if [[ -z "$OVERLAPS" ]]; then
  ok "No HA overlaps defined in binding"
  exit 0
fi

HA_INSTALLED=$(yq -r '.addons[] | .slug' "$HA_ADDONS" 2>/dev/null | sort || echo "")

for overlap in $OVERLAPS; do
  if echo "$HA_INSTALLED" | grep -q "^${overlap}$"; then
    recommendation=$(yq -r ".ha_overlaps.overlaps[] | select(.ha_addon == \"$overlap\") | .recommendation" "$BINDING" 2>/dev/null)
    reason=$(yq -r ".ha_overlaps.overlaps[] | select(.ha_addon == \"$overlap\") | .reason" "$BINDING" 2>/dev/null)
    shop_service=$(yq -r ".ha_overlaps.overlaps[] | select(.ha_addon == \"$overlap\") | .shop_service" "$BINDING" 2>/dev/null)

    if [[ "$recommendation" == "decommission" ]]; then
      err "HA add-on '$overlap' duplicates shop service '$shop_service' — recommend: $recommendation"
    else
      warn "HA add-on '$overlap' duplicates shop service '$shop_service' — recommend: $recommendation ($reason)"
    fi
  else
    ok "HA add-on '$overlap' not installed — no overlap"
  fi
done

if [[ "$ERRORS" -gt 0 ]]; then
  echo "D110 FAIL: $ERRORS HA add-on overlap(s) require action"
  exit 1
fi

ok "HA duplicate audit passed"
exit 0

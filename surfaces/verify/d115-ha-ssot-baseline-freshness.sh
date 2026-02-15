#!/usr/bin/env bash
# TRIAGE: D115 ha-ssot-baseline-freshness — Run ha.ssot.baseline.build to refresh
# D115: HA SSOT Baseline Freshness
# Enforces: Unified baseline exists, is fresh (<= 14 days), all required sub-bindings on disk
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
BASELINE="$ROOT/ops/bindings/ha.ssot.baseline.yaml"

ERRORS=0
err() { echo "  FAIL: $*" >&2; ERRORS=$((ERRORS + 1)); }
ok() { [[ "${DRIFT_VERBOSE:-0}" == "1" ]] && echo "  OK: $*" || true; }

command -v yq >/dev/null 2>&1 || { err "yq not installed"; exit 1; }

# ── Check baseline exists and is non-empty ───────────────────────────────────
if [[ ! -s "$BASELINE" ]]; then
  err "ha.ssot.baseline.yaml does not exist or is empty"
  echo "D115 FAIL: $ERRORS check(s) failed"
  exit 1
fi
ok "baseline exists"

# ── Check generated timestamp freshness (<= 14 days) ────────────────────────
GENERATED=$(yq -r '.generated // ""' "$BASELINE" 2>/dev/null)
if [[ -z "$GENERATED" ]]; then
  err "baseline has no generated timestamp"
else
  # Parse ISO 8601 date and compare to now
  GEN_EPOCH=$(date -j -f '%Y-%m-%dT%H:%M:%SZ' "$GENERATED" '+%s' 2>/dev/null || echo "0")
  NOW_EPOCH=$(date '+%s')
  if [[ "$GEN_EPOCH" -eq 0 ]]; then
    err "cannot parse generated timestamp: $GENERATED"
  else
    AGE_DAYS=$(( (NOW_EPOCH - GEN_EPOCH) / 86400 ))
    if [[ "$AGE_DAYS" -gt 14 ]]; then
      err "baseline is ${AGE_DAYS} days old (max 14)"
    else
      ok "baseline age: ${AGE_DAYS} days"
    fi
  fi
fi

# ── Check all required sub-bindings exist on disk ────────────────────────────
REQUIRED_BINDINGS=(
  "ha.addons.yaml"
  "ha.automations.yaml"
  "ha.helpers.yaml"
  "ha.integrations.yaml"
  "ha.scenes.yaml"
  "ha.scripts.yaml"
  "ha.hacs.yaml"
  "ha.entity.state.baseline.yaml"
  "ha.device.map.yaml"
  "z2m.devices.yaml"
  "zwave.devices.yaml"
)

for binding in "${REQUIRED_BINDINGS[@]}"; do
  if [[ ! -s "$ROOT/ops/bindings/$binding" ]]; then
    err "required sub-binding missing: $binding"
  else
    ok "sub-binding: $binding"
  fi
done

# ── Check unexpected unavailable threshold ───────────────────────────────────
UNEXPECTED=$(yq -r '.health.entities_unexpected_unavailable // 0' "$BASELINE" 2>/dev/null)
if [[ "$UNEXPECTED" -ge 50 ]]; then
  err "entities_unexpected_unavailable = $UNEXPECTED (threshold: < 50)"
else
  ok "unexpected unavailable: $UNEXPECTED (< 50)"
fi

# ── Result ───────────────────────────────────────────────────────────────────
if [[ "$ERRORS" -gt 0 ]]; then
  echo "D115 FAIL: $ERRORS check(s) failed"
  exit 1
fi

ok "HA SSOT baseline fresh and complete"
exit 0

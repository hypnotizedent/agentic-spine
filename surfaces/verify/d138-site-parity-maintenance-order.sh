#!/usr/bin/env bash
# TRIAGE: Update ops/bindings/startup.sequencing.yaml site ordering metadata
# D138: Startup sequencing site parity and maintenance ordering across shop/home
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
SEQ="$ROOT/ops/bindings/startup.sequencing.yaml"

ERRORS=0
err() { echo "  $*"; ERRORS=$((ERRORS + 1)); }

command -v yq >/dev/null 2>&1 || { err "yq not installed"; echo "D138 FAIL: 1 check(s) failed"; exit 1; }
[[ -f "$SEQ" ]] || { err "startup.sequencing.yaml not found"; echo "D138 FAIL: 1 check(s) failed"; exit 1; }

# Check version >= 2 (site tags were added in v2)
version="$(yq e '.version // 0' "$SEQ" 2>/dev/null)"
if [[ "$version" -lt 2 ]]; then
  err "startup.sequencing.yaml version=$version (expected >= 2 for site tags)"
fi

# Collect all phases and verify site tags
phase_count="$(yq e '.phases | length' "$SEQ" 2>/dev/null || echo "0")"
if [[ "$phase_count" -eq 0 ]]; then
  err "no phases found in startup.sequencing.yaml"
  echo "D138 FAIL: $ERRORS check(s) failed"
  exit 1
fi

shop_found=0
home_found=0

idx=0
while [[ "$idx" -lt "$phase_count" ]]; do
  phase_num="$(yq e ".phases[$idx].phase // \"\"" "$SEQ" 2>/dev/null)"
  site="$(yq e ".phases[$idx].site // \"\"" "$SEQ" 2>/dev/null)"

  if [[ -z "$site" || "$site" == "null" ]]; then
    err "Phase $phase_num missing required 'site' tag"
  else
    case "$site" in
      shop) shop_found=1 ;;
      home) home_found=1 ;;
      *) err "Phase $phase_num has invalid site='$site' (expected: shop|home)" ;;
    esac
  fi

  idx=$((idx + 1))
done

if [[ "$shop_found" -eq 0 ]]; then
  err "No shop site phases found (at least one required)"
fi

if [[ "$home_found" -eq 0 ]]; then
  err "No home site phases found (at least one required for site parity)"
fi

if [[ "$ERRORS" -gt 0 ]]; then
  echo "D138 FAIL: $ERRORS parity errors found"
  exit 1
fi

echo "D138 PASS: site parity enforced ($phase_count phases, shop+home represented)"
exit 0

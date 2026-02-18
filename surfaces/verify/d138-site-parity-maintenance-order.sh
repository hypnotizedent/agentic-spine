#!/usr/bin/env bash
# TRIAGE: Add site tags and cross-site representation to startup.sequencing.yaml
# D138: Startup sequencing has site tags and both shop/home sites represented
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
SEQ="$ROOT/ops/bindings/startup.sequencing.yaml"

ERRORS=0
err() { echo "  $*"; ERRORS=$((ERRORS + 1)); }

[[ -f "$SEQ" ]] || { err "startup.sequencing.yaml not found"; echo "D138 FAIL: 1 check(s) failed"; exit 1; }
command -v yq >/dev/null 2>&1 || { err "yq not installed"; echo "D138 FAIL: 1 check(s) failed"; exit 1; }

# ── Version check ──────────────────────────────────────────────────────
version="$(yq e '.version' "$SEQ" 2>/dev/null || echo "0")"
if [[ "$version" -lt 2 ]]; then
  err "startup.sequencing.yaml version=$version (expected >=2)"
fi

# ── Phase site tags ────────────────────────────────────────────────────
phase_count="$(yq e '.phases | length' "$SEQ" 2>/dev/null || echo "0")"
if [[ "$phase_count" -eq 0 ]]; then
  err "No phases found in startup.sequencing.yaml"
else
  has_shop=false
  has_home=false

  for i in $(seq 0 $((phase_count - 1))); do
    phase_id="$(yq e ".phases[$i].phase" "$SEQ" 2>/dev/null || echo "unknown")"
    site="$(yq e ".phases[$i].site" "$SEQ" 2>/dev/null || echo "")"

    if [[ -z "$site" || "$site" == "null" ]]; then
      err "Phase $phase_id missing 'site' tag"
      continue
    fi

    case "$site" in
      shop) has_shop=true ;;
      home) has_home=true ;;
      *) err "Phase $phase_id has invalid site='$site' (expected shop|home)" ;;
    esac
  done

  if [[ "$has_shop" != "true" ]]; then
    err "No phases tagged with site=shop"
  fi
  if [[ "$has_home" != "true" ]]; then
    err "No phases tagged with site=home"
  fi
fi

if [[ "$ERRORS" -gt 0 ]]; then
  echo "D138 FAIL: $ERRORS site parity issues found"
  exit 1
fi

echo "D138 PASS: startup sequencing has site tags for all $phase_count phases (shop + home)"
exit 0

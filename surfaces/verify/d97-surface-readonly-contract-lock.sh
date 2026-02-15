#!/usr/bin/env bash
# TRIAGE: Surface readonly contract missing or incomplete — check ops/bindings/surface.readonly.contract.yaml
# D97: surface-readonly-contract-lock
# Enforces: surface readonly contract exists with all surfaces declared and no mutating access
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"

ERRORS=0
err() { echo "  FAIL: $*" >&2; ERRORS=$((ERRORS + 1)); }
ok() { [[ "${DRIFT_VERBOSE:-0}" == "1" ]] && echo "  OK: $*" || true; }

CONTRACT="$ROOT/ops/bindings/surface.readonly.contract.yaml"
CAPABILITIES="$ROOT/ops/capabilities.yaml"

# ── Check 1: Contract exists ──
if [[ ! -f "$CONTRACT" ]]; then
  err "surface.readonly.contract.yaml does not exist"
  echo "D97 FAIL: $ERRORS check(s) failed"
  exit 1
fi
ok "contract binding exists"

# ── Check 2: Version field present ──
if grep -q '^version:' "$CONTRACT"; then
  ok "version field present"
else
  err "version field missing from contract"
fi

# ── Check 3: Required surfaces declared ──
REQUIRED_SURFACES=(spine_status gap_reconciliation loop_summary rag_status proposal_queue)
for surface in "${REQUIRED_SURFACES[@]}"; do
  if grep -q "^  ${surface}:" "$CONTRACT"; then
    ok "surface $surface declared"
  else
    err "surface $surface not declared in contract"
  fi
done

# ── Check 4: No surface declares mutating access ──
while IFS= read -r line; do
  access_val="$(echo "$line" | sed 's/.*access: *//')"
  if echo "$access_val" | grep -qi "mutating\|write\|delete"; then
    err "surface declares mutating access: $access_val"
  fi
done < <(grep '    access:' "$CONTRACT")
ok "no mutating access declared"

# ── Check 5: Existing surfaces reference valid capabilities ──
while IFS= read -r line; do
  cap_name="$(echo "$line" | sed 's/.*capability: *"//' | sed 's/".*//')"
  if [[ -n "$cap_name" && "$cap_name" != "null" ]]; then
    if grep -q "${cap_name}:" "$CAPABILITIES" 2>/dev/null; then
      ok "capability $cap_name exists"
    else
      err "surface references missing capability: $cap_name"
    fi
  fi
done < <(grep '    capability:' "$CONTRACT" | grep -v 'null')

# ── Check 6: Surfaces with exists: false have gap or notes ──
# Extract surface blocks and check exists: false entries
in_surfaces=false
current_surface=""
current_exists=""
while IFS= read -r line; do
  if echo "$line" | grep -q '^surfaces:'; then
    in_surfaces=true
    continue
  fi
  if [[ "$in_surfaces" == "true" ]]; then
    if echo "$line" | grep -qE '^  [a-z].*:$'; then
      # Check previous surface
      if [[ -n "$current_surface" && "$current_exists" == "false" ]]; then
        block="$(sed -n "/^  ${current_surface}:/,/^  [a-z]/p" "$CONTRACT" | head -20)"
        if echo "$block" | grep -q "gap:"; then
          ok "$current_surface (not yet exists) has gap reference"
        else
          err "$current_surface exists=false but no gap reference"
        fi
      fi
      current_surface="$(echo "$line" | sed 's/^ *//' | sed 's/:.*//')"
      current_exists=""
    fi
    if echo "$line" | grep -q 'exists:'; then
      current_exists="$(echo "$line" | sed 's/.*exists: *//')"
    fi
    if echo "$line" | grep -q '^enforcement:'; then
      in_surfaces=false
    fi
  fi
done < "$CONTRACT"
# Check last surface
if [[ -n "$current_surface" && "$current_exists" == "false" ]]; then
  block="$(sed -n "/^  ${current_surface}:/,/^  [a-z]/p" "$CONTRACT" | head -20)"
  if echo "$block" | grep -q "gap:"; then
    ok "$current_surface (not yet exists) has gap reference"
  else
    err "$current_surface exists=false but no gap reference"
  fi
fi

# ── Check 7: Enforcement section present ──
if grep -q '^enforcement:' "$CONTRACT"; then
  ok "enforcement section present"
else
  err "enforcement section missing"
fi

# ── Check 8: Product doc exists ──
if [[ -f "$ROOT/docs/product/AOF_SURFACE_READONLY_CONTRACT.md" ]]; then
  ok "product doc exists"
else
  err "docs/product/AOF_SURFACE_READONLY_CONTRACT.md does not exist"
fi

# ── Result ──
if [[ "$ERRORS" -gt 0 ]]; then
  echo "D97 FAIL: $ERRORS check(s) failed"
  exit 1
fi
exit 0

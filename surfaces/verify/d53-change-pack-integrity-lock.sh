#!/usr/bin/env bash
# D53: Change pack integrity lock
#
# Validates:
# 1. CHANGE_PACK_TEMPLATE.md exists
# 2. cutover.sequencing.yaml exists
# 3. Open cutover loops have companion .changepack.md files
# 4. Companion files contain required sections
#
# Origin: GAP-OP-065 (UDR6 cutover exposed missing preflight)
set -euo pipefail

SP="${SPINE_ROOT:-$HOME/code/agentic-spine}"

ERRORS=0

# Check 1: Template exists
if [[ ! -f "$SP/docs/governance/CHANGE_PACK_TEMPLATE.md" ]]; then
  echo "FAIL: docs/governance/CHANGE_PACK_TEMPLATE.md missing" >&2
  ERRORS=$((ERRORS + 1))
fi

# Check 2: Sequencing rules exist
if [[ ! -f "$SP/ops/bindings/cutover.sequencing.yaml" ]]; then
  echo "FAIL: ops/bindings/cutover.sequencing.yaml missing" >&2
  ERRORS=$((ERRORS + 1))
fi

# Check 3: Open cutover loops have companion .changepack.md
LOOP_DIR="$SP/mailroom/state/loop-scopes"
for scope in "$LOOP_DIR"/*CUTOVER*.scope.md; do
  [[ -f "$scope" ]] || continue

  # Skip closed loops
  if grep -qiE 'Status.*CLOSED' "$scope" 2>/dev/null; then
    continue
  fi

  base="$(basename "$scope" .scope.md)"
  companion="$LOOP_DIR/${base}.changepack.md"

  if [[ ! -f "$companion" ]]; then
    echo "FAIL: open cutover loop $base has no companion .changepack.md" >&2
    ERRORS=$((ERRORS + 1))
  fi
done

# Check 4: Companion files contain required sections
REQUIRED_SECTIONS=(
  "Change Description"
  "IP Map"
  "Rollback Map"
  "Pre-Cutover Verification Matrix"
  "Cutover Sequence"
  "LAN-Only Devices"
  "Post-Cutover Verification Matrix"
  "Sign-Off"
)

for pack in "$LOOP_DIR"/*.changepack.md; do
  [[ -f "$pack" ]] || continue
  packname="$(basename "$pack")"

  for section in "${REQUIRED_SECTIONS[@]}"; do
    if ! grep -q "## $section" "$pack" 2>/dev/null; then
      echo "FAIL: $packname missing required section: $section" >&2
      ERRORS=$((ERRORS + 1))
    fi
  done
done

[[ "$ERRORS" -eq 0 ]] && exit 0 || exit 1

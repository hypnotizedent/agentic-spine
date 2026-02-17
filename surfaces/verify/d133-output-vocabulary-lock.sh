#!/usr/bin/env bash
# TRIAGE: Fix gate scripts to include their gate ID (D<N>) in echo/printf output statements. Remove the gate from LEGACY_EXCEPTIONS once fixed.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
VERIFY_DIR="$ROOT/surfaces/verify"

fail() {
  echo "D133 FAIL: $*" >&2
  exit 1
}

# Legacy gates that do not include their gate ID in output statements.
# New gates must use canonical D<N> PASS:/FAIL: output patterns.
# Remove entries as gates are migrated to canonical output vocabulary.
LEGACY_EXCEPTIONS="
d113
d114
"

ERRORS=0
CHECKED=0
EXCEPTED=0

for script in "$VERIFY_DIR"/d[0-9]*-*.sh; do
  [[ -f "$script" ]] || continue
  base="$(basename "$script")"

  # Extract gate number from filename
  gate_num="${base#d}"
  gate_num="${gate_num%%-*}"
  gate_id="D${gate_num}"
  short="d${gate_num}"

  # Skip legacy exceptions
  if echo "$LEGACY_EXCEPTIONS" | grep -qw "$short"; then
    EXCEPTED=$((EXCEPTED + 1))
    continue
  fi

  CHECKED=$((CHECKED + 1))

  # Gate script must reference its own gate ID in at least one output statement
  if ! grep -E "(echo|printf|print).*${gate_id}" "$script" >/dev/null 2>&1; then
    echo "  violation: $base has no output referencing $gate_id" >&2
    ERRORS=$((ERRORS + 1))
  fi
done

if [[ "$ERRORS" -gt 0 ]]; then
  fail "${ERRORS} output vocabulary violation(s) (${CHECKED} checked, ${EXCEPTED} excepted)"
fi

echo "D133 PASS: output vocabulary valid (${CHECKED} gates checked, ${EXCEPTED} legacy exceptions)"
exit 0

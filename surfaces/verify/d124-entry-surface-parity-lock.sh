#!/usr/bin/env bash
# D124: Entry surface thin-pointer integrity.
# Verifies entry stubs remain thin pointers with no inline governance or startup blocks.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${SPINE_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
CONTRACT="$ROOT/ops/bindings/entry.surface.contract.yaml"

fail() {
  echo "D124 FAIL: $*" >&2
  exit 1
}

command -v yq >/dev/null 2>&1 || fail "required tool missing: yq"
[[ -f "$CONTRACT" ]] || fail "missing contract: $CONTRACT"
yq e '.' "$CONTRACT" >/dev/null 2>&1 || fail "invalid YAML: $CONTRACT"

errors=0
err() {
  echo "  FAIL: $*" >&2
  errors=$((errors + 1))
}

# Verify entry model is thin-pointer
entry_model="$(yq e -r '.entry_model // ""' "$CONTRACT")"
[[ "$entry_model" == "thin-pointer" ]] || fail "entry_model is '$entry_model', expected 'thin-pointer'"

# Read prohibited patterns from contract
prohibited_patterns=()
while IFS= read -r pat; do
  [[ -n "$pat" ]] && prohibited_patterns+=("$pat")
done < <(yq e -r '.prohibited_in_stubs[]?' "$CONTRACT" 2>/dev/null || true)

# Check each surface
while IFS=$'\t' read -r sid path role; do
  [[ -z "$sid" || -z "$path" ]] && continue

  abs="$path"
  if [[ "$abs" == "~/"* ]]; then
    abs="$HOME/${abs#\~/}"
  elif [[ "$abs" != /* ]]; then
    abs="$ROOT/$abs"
  fi

  [[ -f "$abs" ]] || {
    err "surface '$sid' missing file: $path"
    continue
  }

  # All surfaces: must not contain SPINE_STARTUP_BLOCK markers
  if grep -qF 'SPINE_STARTUP_BLOCK' "$abs"; then
    err "surface '$sid' contains prohibited SPINE_STARTUP_BLOCK marker"
  fi

  # Thin-pointer surfaces: must not contain inline startup commands
  if [[ "$role" == "thin-pointer" ]]; then
    # Check for inline startup block patterns (marker-delimited blocks)
    if grep -qF '<!-- SPINE_STARTUP_BLOCK -->' "$abs"; then
      err "surface '$sid' (thin-pointer) contains startup block delimiters"
    fi
    # Check line count — thin pointers should be compact (< 30 lines)
    line_count=$(wc -l < "$abs" | tr -d ' ')
    if [[ "$line_count" -gt 30 ]]; then
      echo "  WARN: surface '$sid' (thin-pointer) has $line_count lines — may contain inline governance" >&2
    fi
  fi

done < <(yq e -r '.surfaces[] | [.id, .path, (.role // "unknown")] | @tsv' "$CONTRACT" 2>/dev/null)

if [[ "$errors" -gt 0 ]]; then
  fail "$errors thin-pointer integrity issue(s) detected"
fi

echo "D124 PASS: entry surface thin-pointer integrity verified"

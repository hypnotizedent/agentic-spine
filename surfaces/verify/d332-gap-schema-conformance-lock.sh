#!/usr/bin/env bash
# TRIAGE: Enforces gap.schema.yaml conformance on operational.gaps.yaml entries. Unknown keys = violation.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
SCHEMA="$ROOT/ops/bindings/gap.schema.yaml"
GAPS_FILE="$ROOT/ops/bindings/operational.gaps.yaml"

fail() {
  echo "D332 FAIL: $*" >&2
  exit 1
}

command -v yq >/dev/null 2>&1 || fail "missing dependency: yq"

[[ -f "$SCHEMA" ]] || fail "missing schema: $SCHEMA"
[[ -f "$GAPS_FILE" ]] || fail "missing gaps file: $GAPS_FILE"

# Collect allowed keys from schema (required + optional field names)
mapfile -t ALLOWED_KEYS < <(
  {
    yq e -r '.required_fields[].name' "$SCHEMA" 2>/dev/null
    yq e -r '.optional_fields[].name' "$SCHEMA" 2>/dev/null
  } | awk 'NF && !seen[$0]++'
)

[[ "${#ALLOWED_KEYS[@]}" -gt 0 ]] || fail "no fields found in schema"

contains() {
  local needle="$1"
  shift || true
  local item
  for item in "$@"; do
    [[ "$item" == "$needle" ]] && return 0
  done
  return 1
}

# Extract all unique keys used across gap entries
mapfile -t ENTRY_KEYS < <(yq e -r '.gaps[] | keys | .[]' "$GAPS_FILE" 2>/dev/null | awk '!seen[$0]++')

# Check for unknown keys
UNKNOWN=()
for key in "${ENTRY_KEYS[@]}"; do
  [[ -n "$key" ]] || continue
  if ! contains "$key" "${ALLOWED_KEYS[@]}"; then
    UNKNOWN+=("$key")
  fi
done

if [[ "${#UNKNOWN[@]}" -gt 0 ]]; then
  echo "D332 FAIL: ${#UNKNOWN[@]} unknown key(s) in operational.gaps.yaml not in gap.schema.yaml:" >&2
  printf '  - %s\n' "${UNKNOWN[@]}" >&2
  exit 1
fi

# Schema version check
SCHEMA_VERSION="$(yq e -r '.schema_version // "unknown"' "$SCHEMA")"
TOTAL_GAPS="$(yq e '.gaps | length' "$GAPS_FILE")"
ALLOWED_COUNT="${#ALLOWED_KEYS[@]}"

echo "D332 PASS: gap-schema-conformance-lock (schema_version=$SCHEMA_VERSION, allowed_keys=$ALLOWED_COUNT, total_gaps=$TOTAL_GAPS, unknown_keys=0)"

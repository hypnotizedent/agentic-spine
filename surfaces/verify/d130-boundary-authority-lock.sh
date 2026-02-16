#!/usr/bin/env bash
# D130: Boundary Authority Lock
# STD-001: Boundary Authority Standard - single source of truth for authoritative surfaces
#
# Validates:
# 1. Boundary baseline exists and is parseable
# 2. README spine-ownership section includes all baseline authoritative surfaces (normalized check)
# 3. Mailroom contract tracked_contract_root points to /Users/ronnyworks/code/agentic-spine/mailroom
# 4. Runtime_root in contract matches boundary runtime-only destination prefix
#
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
BOUNDARY="$ROOT/ops/bindings/spine.boundary.baseline.yaml"
MAILROOM_CONTRACT="$ROOT/ops/bindings/mailroom.runtime.contract.yaml"
README="$ROOT/README.md"

fail() {
  echo "D130 FAIL: $*" >&2
  exit 1
}

require_file() {
  [[ -f "$1" ]] || fail "missing required file: $1"
}

require_file "$BOUNDARY"
require_file "$MAILROOM_CONTRACT"
require_file "$README"

command -v yq >/dev/null 2>&1 || fail "required tool missing: yq"
command -v rg >/dev/null 2>&1 || fail "required tool missing: rg"

yq e '.' "$BOUNDARY" >/dev/null 2>&1 || fail "invalid YAML: $BOUNDARY"
yq e '.' "$MAILROOM_CONTRACT" >/dev/null 2>&1 || fail "invalid YAML: $MAILROOM_CONTRACT"

# Check 1: Validate boundary baseline authoritative_surfaces
mapfile -t baseline_surfaces < <(yq e -r '.authoritative_surfaces[]?' "$BOUNDARY")
if [[ ${#baseline_surfaces[@]} -eq 0 ]]; then
  fail "boundary baseline has no authoritative_surfaces defined"
fi

# Check 2: README spine-ownership section includes baseline surfaces
# Extract surfaces from README "Spine owns:" section
mapfile -t readme_surfaces < <(
  rg -A 10 '^Spine owns:' "$README" 2>/dev/null | \
    rg '^\s*- ' | \
    sed 's/^\s*- //' | \
    sed 's/`//g'
)

for baseline_surface in "${baseline_surfaces[@]}"; do
  # Normalize for comparison (remove trailing /**, convert to readme format)
  normalized=$(echo "$baseline_surface" | sed 's|/\*\*||' | sed 's|/$||')
  found=0
  for readme_surface in "${readme_surfaces[@]}"; do
    readme_normalized=$(echo "$readme_surface" | sed 's|/\*\*||' | sed 's|/$||' | tr -d '`')
    if [[ "$normalized" == "$readme_normalized"* || "$readme_normalized" == *"$normalized"* ]]; then
      found=1
      break
    fi
  done
  if [[ $found -eq 0 ]]; then
    fail "README spine-ownership missing baseline surface: $baseline_surface"
  fi
done

# Check 3: Mailroom contract tracked_contract_root points to correct path
expected_tracked_root="$ROOT/mailroom"
actual_tracked_root="$(yq e -r '.tracked_contract_root // ""' "$MAILROOM_CONTRACT")"
if [[ "$actual_tracked_root" != "$expected_tracked_root" ]]; then
  fail "mailroom contract tracked_contract_root mismatch: expected=$expected_tracked_root, got=$actual_tracked_root"
fi

# Check 4: Runtime_root in contract matches boundary runtime-only destination prefix
runtime_root="$(yq e -r '.runtime_root // ""' "$MAILROOM_CONTRACT")"
if [[ -z "$runtime_root" ]]; then
  fail "mailroom contract missing runtime_root"
fi

# Validate runtime-only destinations start with runtime_root
runtime_only_count="$(yq e '.rules.runtime_only | length' "$BOUNDARY" 2>/dev/null || echo 0)"
if [[ "$runtime_only_count" =~ ^[0-9]+$ ]] && [[ "$runtime_only_count" -gt 0 ]]; then
  for ((i=0; i<runtime_only_count; i++)); do
    dest="$(yq e -r ".rules.runtime_only[$i].destination // \"\"" "$BOUNDARY")"
    if [[ -n "$dest" && "$dest" != "$runtime_root"* ]]; then
      fail "runtime_only destination '$dest' not under contract runtime_root '$runtime_root'"
    fi
  done
fi

echo "D130 PASS: boundary authority consistent (baseline + README + mailroom contract)"
exit 0

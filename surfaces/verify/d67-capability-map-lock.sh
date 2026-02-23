#!/usr/bin/env bash
# TRIAGE: Update ops/bindings/capability_map.yaml to cover all entries in capabilities.yaml.
set -euo pipefail

# D67: Capability Map Lock
# Purpose: verify capability_map.yaml covers every capability in capabilities.yaml
# and that no phantom entries exist in the map that aren't in the source.
#
# Exit: 0 = PASS, 1 = FAIL

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE="$ROOT/ops/capabilities.yaml"
MAP="$ROOT/ops/bindings/capability_map.yaml"

fail() { echo "D67 FAIL: $*" >&2; exit 1; }

[[ -f "$SOURCE" ]] || fail "capabilities.yaml missing"
[[ -f "$MAP" ]] || fail "capability_map.yaml missing"
command -v yq >/dev/null 2>&1 || fail "required tool missing: yq"

# Extract capability names from source
mapfile -t source_caps < <(yq e '.capabilities | keys | .[]' "$SOURCE" 2>/dev/null | sort)

# Extract capability names from map
mapfile -t map_caps < <(yq e '.capabilities | keys | .[]' "$MAP" 2>/dev/null | sort)

source_count=${#source_caps[@]}
map_count=${#map_caps[@]}

[[ "$source_count" -eq 0 ]] && fail "no capabilities found in source"
[[ "$map_count" -eq 0 ]] && fail "no capabilities found in map"

# Use comm on sorted lists instead of O(n^2) nested loops
source_sorted="$(printf '%s\n' "${source_caps[@]}" | sort)"
map_sorted="$(printf '%s\n' "${map_caps[@]}" | sort)"

# Items in source but not in map (missing)
missing=0
while IFS= read -r cap; do
  [[ -z "$cap" ]] && continue
  echo "  MISSING from map: $cap" >&2
  missing=$((missing + 1))
done < <(comm -23 <(echo "$source_sorted") <(echo "$map_sorted"))

# Items in map but not in source (phantom)
phantom=0
while IFS= read -r mcap; do
  [[ -z "$mcap" ]] && continue
  echo "  PHANTOM in map: $mcap" >&2
  phantom=$((phantom + 1))
done < <(comm -13 <(echo "$source_sorted") <(echo "$map_sorted"))

if [[ $missing -gt 0 || $phantom -gt 0 ]]; then
  fail "map drift: $missing missing, $phantom phantom (source=$source_count map=$map_count)"
fi

echo "D67 PASS: capability map covers all $source_count capabilities"

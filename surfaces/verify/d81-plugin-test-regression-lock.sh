#!/usr/bin/env bash
# TRIAGE: New plugins must have tests/ dir with test scripts, or an explicit exemption.
# D81: Plugin test regression lock
# Prevents new plugins from being added to MANIFEST.yaml without
# either test files in ops/plugins/<name>/tests/ or an explicit
# exemption in ops/bindings/plugin-test-exemptions.yaml.
#
# Existing untested plugins are grandfathered via exemptions.
# New plugins MUST add tests or an exemption entry.
set -euo pipefail

SP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MANIFEST="$SP/ops/plugins/MANIFEST.yaml"
EXEMPTIONS="$SP/ops/bindings/plugin-test-exemptions.yaml"

FAIL=0
err() { echo "  FAIL: $1" >&2; FAIL=1; }

[[ -f "$MANIFEST" ]] || { err "MANIFEST.yaml not found"; exit 1; }
[[ -f "$EXEMPTIONS" ]] || { err "plugin-test-exemptions.yaml not found"; exit 1; }
command -v yq >/dev/null 2>&1 || { err "yq not found"; exit 1; }

plugin_count=$(yq '.plugins | length' "$MANIFEST")
UNCOVERED=0

for ((i=0; i<plugin_count; i++)); do
  name=$(yq -r ".plugins[$i].name" "$MANIFEST")
  scripts_count=$(yq ".plugins[$i].scripts | length" "$MANIFEST")

  # Skip empty plugins (no scripts to test)
  [[ "$scripts_count" -eq 0 ]] && continue

  # Check for test files
  test_dir="$SP/ops/plugins/$name/tests"
  has_tests=0
  if [[ -d "$test_dir" ]]; then
    test_count=$(find "$test_dir" -type f -name '*.sh' 2>/dev/null | wc -l | tr -d ' ')
    [[ "$test_count" -gt 0 ]] && has_tests=1
  fi

  [[ "$has_tests" -eq 1 ]] && continue

  # Check exemption binding
  is_exempt=$(yq ".exemptions[] | select(.plugin == \"$name\") | .exempt" "$EXEMPTIONS" 2>/dev/null || true)
  if [[ "$is_exempt" == "true" ]]; then
    continue
  fi

  err "plugin '$name' has $scripts_count scripts but no tests/ dir and no exemption"
  UNCOVERED=$((UNCOVERED + 1))
done

if [[ "$UNCOVERED" -gt 0 ]]; then
  echo "  $UNCOVERED plugin(s) need tests or exemption in plugin-test-exemptions.yaml" >&2
fi

exit "$FAIL"

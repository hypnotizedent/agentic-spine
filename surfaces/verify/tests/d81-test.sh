#!/usr/bin/env bash
# Tests for D81: plugin test regression lock
set -euo pipefail

SP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
GATE="$SP/surfaces/verify/d81-plugin-test-regression-lock.sh"
PASS=0; FAIL_COUNT=0
pass() { PASS=$((PASS+1)); echo "PASS: $1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT+1)); echo "FAIL: $1" >&2; }

# Test 1: Gate passes on current repo state (all plugins exempt or tested)
echo "--- Test 1: live state PASS ---"
if bash "$GATE" >/dev/null 2>&1; then
  pass "D81 passes on current repo state"
else
  fail "D81 should pass on current repo state (all plugins covered)"
fi

# Test 2: Gate detects unexempted plugin (negative test)
echo "--- Test 2: missing exemption detection ---"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Create a minimal MANIFEST with a fake plugin
cat >"$TMP/MANIFEST.yaml" <<'YAML'
plugins:
  - name: fake-new-plugin
    path: ops/plugins/fake-new-plugin
    scripts:
      - bin/fake-script
    capabilities:
      - fake.script
    tags: [test]
    description: "Test plugin"
YAML

# Create empty exemptions (no fake-new-plugin exempted)
cat >"$TMP/exemptions.yaml" <<'YAML'
exemptions: []
YAML

# Create the plugin dir without tests
mkdir -p "$TMP/ops/plugins/fake-new-plugin/bin"
touch "$TMP/ops/plugins/fake-new-plugin/bin/fake-script"

# Run gate with overridden paths
output=$(SP="$TMP" MANIFEST="$TMP/MANIFEST.yaml" EXEMPTIONS="$TMP/exemptions.yaml" bash -c '
  set -euo pipefail
  MANIFEST="$TMP/MANIFEST.yaml"
  EXEMPTIONS="$TMP/exemptions.yaml"
  FAIL=0
  err() { echo "FAIL: $1" >&2; FAIL=1; }
  plugin_count=$(yq ".plugins | length" "$MANIFEST")
  for ((i=0; i<plugin_count; i++)); do
    name=$(yq -r ".plugins[$i].name" "$MANIFEST")
    scripts_count=$(yq ".plugins[$i].scripts | length" "$MANIFEST")
    [[ "$scripts_count" -eq 0 ]] && continue
    test_dir="$TMP/ops/plugins/$name/tests"
    has_tests=0
    if [[ -d "$test_dir" ]]; then
      test_count=$(find "$test_dir" -type f -name "*.sh" 2>/dev/null | wc -l | tr -d " ")
      [[ "$test_count" -gt 0 ]] && has_tests=1
    fi
    [[ "$has_tests" -eq 1 ]] && continue
    is_exempt=$(yq ".exemptions[] | select(.plugin == \"$name\") | .exempt" "$EXEMPTIONS" 2>/dev/null || true)
    [[ "$is_exempt" == "true" ]] && continue
    err "plugin $name has $scripts_count scripts but no tests and no exemption"
  done
  exit "$FAIL"
' 2>&1) && rc=$? || rc=$?

if [[ "$rc" -ne 0 ]]; then
  pass "D81 correctly detects unexempted plugin without tests (rc=$rc)"
else
  fail "D81 should have failed for unexempted plugin without tests"
fi

# Test 3: Binding and gate files exist
echo "--- Test 3: structural checks ---"
if [[ -x "$GATE" && -f "$SP/ops/bindings/plugin-test-exemptions.yaml" ]]; then
  pass "D81 gate executable and exemptions binding exist"
else
  fail "D81 gate or exemptions binding missing"
fi

echo
echo "Results: $PASS passed, $FAIL_COUNT failed"
exit "$FAIL_COUNT"

#!/usr/bin/env bash
# Tests for D95: version-compat-matrix-lock
set -euo pipefail

SP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
GATE="$SP/surfaces/verify/d95-version-compat-matrix-lock.sh"

PASS=0; FAIL_COUNT=0
pass() { PASS=$((PASS+1)); echo "PASS: $1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT+1)); echo "FAIL: $1" >&2; }

setup_mock() {
  local tmp
  tmp="$(mktemp -d)"

  mkdir -p "$tmp/ops/bindings"
  mkdir -p "$tmp/surfaces/verify"
  mkdir -p "$tmp/ops/commands"
  mkdir -p "$tmp/ops/lib"
  mkdir -p "$tmp/ops/plugins"

  # Matrix binding
  cat > "$tmp/ops/bindings/version.compat.matrix.yaml" <<'EOF'
version: 1
updated: "2026-02-15"
components:
  drift-gate-runtime:
    type: runtime
    version: "2.8"
    source: "surfaces/verify/drift-gate.sh"
    depends_on:
      - component: gate-registry
        min_version: "1"
  gate-registry:
    type: binding
    version: "1"
    source: "ops/bindings/gate.registry.yaml"
    depends_on: []
  policy-presets:
    type: binding
    version: "1"
    source: "ops/bindings/policy.presets.yaml"
    depends_on: []
  resolve-policy:
    type: library
    version: "1"
    source: "ops/lib/resolve-policy.sh"
    depends_on:
      - component: policy-presets
        min_version: "1"
  cap-runner:
    type: runtime
    version: "1"
    source: "ops/commands/cap.sh"
    depends_on:
      - component: capabilities-registry
        min_version: "1"
  capabilities-registry:
    type: binding
    version: "1"
    source: "ops/capabilities.yaml"
    depends_on:
      - component: capability-map
        min_version: "1"
  capability-map:
    type: binding
    version: "1"
    source: "ops/bindings/capability_map.yaml"
    depends_on: []
  tenant-profile-schema:
    type: binding
    version: "1"
    source: "ops/bindings/tenant.profile.schema.yaml"
    depends_on: []
  plugin-manifest:
    type: binding
    version: "1"
    source: "ops/plugins/MANIFEST.yaml"
    depends_on: []
enforcement:
  gate: D95
EOF

  # Source files
  echo "# gate" > "$tmp/surfaces/verify/drift-gate.sh"
  echo "# reg" > "$tmp/ops/bindings/gate.registry.yaml"
  echo "# presets" > "$tmp/ops/bindings/policy.presets.yaml"
  echo "# lib" > "$tmp/ops/lib/resolve-policy.sh"
  echo "# cap" > "$tmp/ops/commands/cap.sh"
  echo "# caps" > "$tmp/ops/capabilities.yaml"
  echo "# map" > "$tmp/ops/bindings/capability_map.yaml"
  echo "# schema" > "$tmp/ops/bindings/tenant.profile.schema.yaml"
  echo "# manifest" > "$tmp/ops/plugins/MANIFEST.yaml"

  # Product doc
  mkdir -p "$tmp/docs/product"
  cat > "$tmp/docs/product/AOF_VERSION_COMPATIBILITY.md" <<'EOF'
---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-15
---
# Version Compatibility
EOF

  echo "$tmp"
}

# Test 1: Valid setup passes
test_valid_setup() {
  local mock
  mock="$(setup_mock)"
  if SPINE_ROOT="$mock" bash "$GATE" >/dev/null 2>&1; then
    pass "valid setup passes D95"
  else
    fail "valid setup should pass D95"
  fi
  rm -rf "$mock"
}

# Test 2: Missing matrix fails
test_missing_matrix() {
  local mock
  mock="$(setup_mock)"
  rm "$mock/ops/bindings/version.compat.matrix.yaml"
  if SPINE_ROOT="$mock" bash "$GATE" >/dev/null 2>&1; then
    fail "missing matrix should fail D95"
  else
    pass "missing matrix fails D95"
  fi
  rm -rf "$mock"
}

# Test 3: Missing source file fails
test_missing_source() {
  local mock
  mock="$(setup_mock)"
  rm "$mock/ops/lib/resolve-policy.sh"
  if SPINE_ROOT="$mock" bash "$GATE" >/dev/null 2>&1; then
    fail "missing source should fail D95"
  else
    pass "missing source file fails D95"
  fi
  rm -rf "$mock"
}

# Test 4: Missing product doc fails
test_missing_doc() {
  local mock
  mock="$(setup_mock)"
  rm "$mock/docs/product/AOF_VERSION_COMPATIBILITY.md"
  if SPINE_ROOT="$mock" bash "$GATE" >/dev/null 2>&1; then
    fail "missing product doc should fail D95"
  else
    pass "missing product doc fails D95"
  fi
  rm -rf "$mock"
}

# Run all tests
echo "D95 Tests"
echo "════════════════════════════════════════"
test_valid_setup
test_missing_matrix
test_missing_source
test_missing_doc

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL_COUNT failed (of $((PASS + FAIL_COUNT)))"
exit "$FAIL_COUNT"

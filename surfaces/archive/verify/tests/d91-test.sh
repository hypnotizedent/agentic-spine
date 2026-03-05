#!/usr/bin/env bash
# Tests for D91: AOF product foundation lock
set -euo pipefail

SP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
GATE="$SP/surfaces/verify/d91-aof-product-foundation-lock.sh"

PASS=0; FAIL_COUNT=0
pass() { PASS=$((PASS+1)); echo "PASS: $1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT+1)); echo "FAIL: $1" >&2; }

# Helper: create minimal mock SPINE_ROOT
setup_mock() {
  local tmp
  tmp="$(mktemp -d)"

  # Create product docs with frontmatter
  mkdir -p "$tmp/docs/product"
  for doc in AOF_PRODUCT_CONTRACT.md AOF_ACCEPTANCE_GATES.md AOF_DEPLOYMENT_PLAYBOOK.md AOF_SUPPORT_SLO.md; do
    cat > "$tmp/docs/product/$doc" <<'DOCEOF'
---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-15
---
# Test doc
DOCEOF
  done

  # Create bindings
  mkdir -p "$tmp/ops/bindings"
  cat > "$tmp/ops/bindings/tenant.profile.schema.yaml" <<'SCHEMAEOF'
version: 1
schema:
  identity:
    required: true
  secrets:
    required: true
  policy:
    required: true
  runtime:
    required: true
  surfaces:
    required: true
  evidence:
    required: true
SCHEMAEOF

  cat > "$tmp/ops/bindings/policy.presets.yaml" <<'PRESETSEOF'
version: 1
presets:
  strict:
    knobs: {}
  balanced:
    knobs: {}
  permissive:
    knobs: {}
PRESETSEOF

  # Create capabilities.yaml with tenant entries
  cat > "$tmp/ops/capabilities.yaml" <<'CAPSEOF'
capabilities:
  tenant.profile.validate:
    description: "test"
  tenant.provision.dry-run:
    description: "test"
CAPSEOF

  # Create capability_map.yaml
  cat > "$tmp/ops/bindings/capability_map.yaml" <<'MAPEOF'
  tenant.profile.validate:
    plugin: tenant
  tenant.provision.dry-run:
    plugin: tenant
MAPEOF

  # Create tenant scripts
  mkdir -p "$tmp/ops/plugins/tenant/bin"
  echo '#!/bin/bash' > "$tmp/ops/plugins/tenant/bin/tenant-profile-validate"
  echo '#!/bin/bash' > "$tmp/ops/plugins/tenant/bin/tenant-provision-dry-run"
  chmod +x "$tmp/ops/plugins/tenant/bin/tenant-profile-validate"
  chmod +x "$tmp/ops/plugins/tenant/bin/tenant-provision-dry-run"

  # Create AOF validate script
  mkdir -p "$tmp/ops/plugins/aof/bin"
  cat > "$tmp/ops/plugins/aof/bin/validate-environment.sh" <<'AOFEOF'
#!/usr/bin/env bash
set -euo pipefail

ENV_FILE=".environment.yaml"
IDENTITY_FILE=".identity.yaml"
STRICT=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --environment-file) ENV_FILE="${2:-}"; shift 2 ;;
    --identity-file) IDENTITY_FILE="${2:-}"; shift 2 ;;
    --strict) STRICT=1; shift ;;
    *) shift ;;
  esac
done

[[ "$STRICT" -eq 1 ]] || exit 1
[[ -f "$ENV_FILE" ]] || exit 1
[[ -f "$IDENTITY_FILE" ]] || exit 1
exit 0
AOFEOF
  chmod +x "$tmp/ops/plugins/aof/bin/validate-environment.sh"

  # Create root AOF contracts
  cat > "$tmp/.environment.yaml" <<'ENVEOF'
version: "1.0"
environment:
  name: "test-env"
  tier: "product"
contracts:
  preflight:
    - step: "validate"
ENVEOF
  cat > "$tmp/.identity.yaml" <<'IDEOF'
identity:
  node_id: "test-node"
  environment: "test-env"
  spine_version: "v1.0.0"
IDEOF

  # Create MANIFEST.yaml
  mkdir -p "$tmp/ops/plugins"
  cat > "$tmp/ops/plugins/MANIFEST.yaml" <<'MANEOF'
plugins:
  - name: tenant
    path: ops/plugins/tenant
MANEOF

  # Create docs README with product reference
  mkdir -p "$tmp/docs"
  echo "See product/ for AOF docs" > "$tmp/docs/README.md"

  # Create governance index
  mkdir -p "$tmp/docs/governance"
  echo "See product/ for AOF" > "$tmp/docs/governance/GOVERNANCE_INDEX.md"

  echo "$tmp"
}

# Test 1: Full valid setup passes
test_valid_setup() {
  local mock
  mock="$(setup_mock)"
  if SPINE_ROOT="$mock" bash "$GATE" >/dev/null 2>&1; then
    pass "valid setup passes D91"
  else
    fail "valid setup should pass D91"
  fi
  rm -rf "$mock"
}

# Test 2: Missing product doc fails
test_missing_product_doc() {
  local mock
  mock="$(setup_mock)"
  rm "$mock/docs/product/AOF_PRODUCT_CONTRACT.md"
  if SPINE_ROOT="$mock" bash "$GATE" >/dev/null 2>&1; then
    fail "missing product doc should fail D91"
  else
    pass "missing product doc fails D91"
  fi
  rm -rf "$mock"
}

# Test 3: Missing frontmatter fails
test_missing_frontmatter() {
  local mock
  mock="$(setup_mock)"
  echo "# No frontmatter" > "$mock/docs/product/AOF_PRODUCT_CONTRACT.md"
  if SPINE_ROOT="$mock" bash "$GATE" >/dev/null 2>&1; then
    fail "missing frontmatter should fail D91"
  else
    pass "missing frontmatter fails D91"
  fi
  rm -rf "$mock"
}

# Test 4: Missing schema section fails
test_missing_schema_section() {
  local mock
  mock="$(setup_mock)"
  # Remove evidence section from schema
  grep -v 'evidence' "$mock/ops/bindings/tenant.profile.schema.yaml" > "$mock/ops/bindings/tenant.profile.schema.yaml.tmp"
  mv "$mock/ops/bindings/tenant.profile.schema.yaml.tmp" "$mock/ops/bindings/tenant.profile.schema.yaml"
  if SPINE_ROOT="$mock" bash "$GATE" >/dev/null 2>&1; then
    fail "missing schema section should fail D91"
  else
    pass "missing schema section fails D91"
  fi
  rm -rf "$mock"
}

# Test 5: Missing preset fails
test_missing_preset() {
  local mock
  mock="$(setup_mock)"
  grep -v 'strict' "$mock/ops/bindings/policy.presets.yaml" > "$mock/ops/bindings/policy.presets.yaml.tmp"
  mv "$mock/ops/bindings/policy.presets.yaml.tmp" "$mock/ops/bindings/policy.presets.yaml"
  if SPINE_ROOT="$mock" bash "$GATE" >/dev/null 2>&1; then
    fail "missing preset should fail D91"
  else
    pass "missing preset fails D91"
  fi
  rm -rf "$mock"
}

# Test 6: Non-executable script fails
test_non_executable_script() {
  local mock
  mock="$(setup_mock)"
  chmod -x "$mock/ops/plugins/tenant/bin/tenant-profile-validate"
  if SPINE_ROOT="$mock" bash "$GATE" >/dev/null 2>&1; then
    fail "non-executable script should fail D91"
  else
    pass "non-executable script fails D91"
  fi
  rm -rf "$mock"
}

# Test 7: Missing docs README reference fails
test_missing_readme_ref() {
  local mock
  mock="$(setup_mock)"
  echo "No product reference here" > "$mock/docs/README.md"
  if SPINE_ROOT="$mock" bash "$GATE" >/dev/null 2>&1; then
    fail "missing README product ref should fail D91"
  else
    pass "missing README product ref fails D91"
  fi
  rm -rf "$mock"
}

# Test 8: Missing environment contract fails
test_missing_environment_contract() {
  local mock
  mock="$(setup_mock)"
  rm "$mock/.environment.yaml"
  if SPINE_ROOT="$mock" bash "$GATE" >/dev/null 2>&1; then
    fail "missing .environment.yaml should fail D91"
  else
    pass "missing .environment.yaml fails D91"
  fi
  rm -rf "$mock"
}

# Run all tests
echo "D91 Tests"
echo "════════════════════════════════════════"
test_valid_setup
test_missing_product_doc
test_missing_frontmatter
test_missing_schema_section
test_missing_preset
test_non_executable_script
test_missing_readme_ref
test_missing_environment_contract

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL_COUNT failed (of $((PASS + FAIL_COUNT)))"
exit "$FAIL_COUNT"

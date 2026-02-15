#!/usr/bin/env bash
# Tests for D93: tenant-storage-boundary-lock
set -euo pipefail

SP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
GATE="$SP/surfaces/verify/d93-tenant-storage-boundary-lock.sh"

PASS=0; FAIL_COUNT=0
pass() { PASS=$((PASS+1)); echo "PASS: $1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT+1)); echo "FAIL: $1" >&2; }

setup_mock() {
  local tmp
  tmp="$(mktemp -d)"

  # Binding
  mkdir -p "$tmp/ops/bindings"
  cat > "$tmp/ops/bindings/tenant.storage.contract.yaml" <<'EOF'
version: 1
updated: "2026-02-15"
owner: "@ronny"
isolation_mode: logical
boundaries:
  receipts:
    description: "Execution receipts"
    current_path: "receipts/sessions/"
    tenant_path_template: "receipts/tenants/{tenant_id}/sessions/"
    sensitivity: high
  ledger:
    description: "Ledger"
    current_path: "receipts/ledger/"
    tenant_path_template: "receipts/tenants/{tenant_id}/ledger/"
    sensitivity: high
  mailroom_inbox:
    description: "Inbox"
    current_path: "mailroom/inbox/"
    tenant_path_template: "mailroom/tenants/{tenant_id}/inbox/"
    sensitivity: medium
  mailroom_outbox:
    description: "Outbox"
    current_path: "mailroom/outbox/"
    tenant_path_template: "mailroom/tenants/{tenant_id}/outbox/"
    sensitivity: medium
  loop_scopes:
    description: "Loops"
    current_path: "mailroom/state/loop-scopes/"
    tenant_path_template: "mailroom/tenants/{tenant_id}/state/loop-scopes/"
    sensitivity: low
enforcement:
  gate: D93
EOF

  # Product doc
  mkdir -p "$tmp/docs/product"
  cat > "$tmp/docs/product/AOF_TENANT_STORAGE_MODEL.md" <<'EOF'
---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-15
---
# Tenant Storage Model
EOF

  echo "$tmp"
}

# Test 1: Valid setup passes
test_valid_setup() {
  local mock
  mock="$(setup_mock)"
  if SPINE_ROOT="$mock" bash "$GATE" >/dev/null 2>&1; then
    pass "valid setup passes D93"
  else
    fail "valid setup should pass D93"
  fi
  rm -rf "$mock"
}

# Test 2: Missing contract fails
test_missing_contract() {
  local mock
  mock="$(setup_mock)"
  rm "$mock/ops/bindings/tenant.storage.contract.yaml"
  if SPINE_ROOT="$mock" bash "$GATE" >/dev/null 2>&1; then
    fail "missing contract should fail D93"
  else
    pass "missing contract fails D93"
  fi
  rm -rf "$mock"
}

# Test 3: Missing product doc fails
test_missing_doc() {
  local mock
  mock="$(setup_mock)"
  rm "$mock/docs/product/AOF_TENANT_STORAGE_MODEL.md"
  if SPINE_ROOT="$mock" bash "$GATE" >/dev/null 2>&1; then
    fail "missing product doc should fail D93"
  else
    pass "missing product doc fails D93"
  fi
  rm -rf "$mock"
}

# Test 4: Missing boundary fails
test_missing_boundary() {
  local mock
  mock="$(setup_mock)"
  sed -i.bak '/^  ledger:/,/^  [a-z]/d' "$mock/ops/bindings/tenant.storage.contract.yaml"
  if SPINE_ROOT="$mock" bash "$GATE" >/dev/null 2>&1; then
    fail "missing boundary should fail D93"
  else
    pass "missing boundary fails D93"
  fi
  rm -rf "$mock"
}

# Run all tests
echo "D93 Tests"
echo "════════════════════════════════════════"
test_valid_setup
test_missing_contract
test_missing_doc
test_missing_boundary

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL_COUNT failed (of $((PASS + FAIL_COUNT)))"
exit "$FAIL_COUNT"

#!/usr/bin/env bash
# Tests for D96: evidence-retention-policy-lock
set -euo pipefail

SP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
GATE="$SP/surfaces/verify/d96-evidence-retention-policy-lock.sh"

PASS=0; FAIL_COUNT=0
pass() { PASS=$((PASS+1)); echo "PASS: $1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT+1)); echo "FAIL: $1" >&2; }

setup_mock() {
  local tmp
  tmp="$(mktemp -d)"

  mkdir -p "$tmp/ops/bindings"
  mkdir -p "$tmp/receipts"

  # Policy binding
  cat > "$tmp/ops/bindings/evidence.retention.policy.yaml" <<'EOF'
version: 1
updated: "2026-02-15"
retention_classes:
  session_receipts:
    description: "Receipts"
    path_pattern: "receipts/sessions/RCAP-*"
    retention_days: 30
    export_format: tar.gz
    purge_eligible: true
    purge_requires: manual_approval
    sensitivity: standard
  ledger_entries:
    description: "Ledger"
    path_pattern: "receipts/ledger/*.yaml"
    retention_days: 365
    export_format: yaml
    purge_eligible: false
    purge_requires: null
    sensitivity: high
  loop_scopes:
    description: "Loop scopes"
    path_pattern: "mailroom/state/loop-scopes/*.scope.md"
    retention_days: 90
    export_format: tar.gz
    purge_eligible: true
    purge_requires: manual_approval
    sensitivity: standard
  gap_registry:
    description: "Gap registry"
    path_pattern: "ops/bindings/operational.gaps.yaml"
    retention_days: 365
    export_format: yaml
    purge_eligible: false
    purge_requires: null
    sensitivity: high
  proposals:
    description: "Proposals"
    path_pattern: "mailroom/outbox/proposals/*"
    retention_days: 30
    export_format: tar.gz
    purge_eligible: true
    purge_requires: auto
    sensitivity: standard
export:
  default_format: tar.gz
  include_metadata: true
enforcement:
  gate: D96
EOF

  # Product doc
  mkdir -p "$tmp/docs/product"
  cat > "$tmp/docs/product/AOF_EVIDENCE_RETENTION_EXPORT.md" <<'EOF'
---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-15
---
# Evidence Retention
EOF

  echo "$tmp"
}

# Test 1: Valid setup passes
test_valid_setup() {
  local mock
  mock="$(setup_mock)"
  if SPINE_ROOT="$mock" bash "$GATE" >/dev/null 2>&1; then
    pass "valid setup passes D96"
  else
    fail "valid setup should pass D96"
  fi
  rm -rf "$mock"
}

# Test 2: Missing policy fails
test_missing_policy() {
  local mock
  mock="$(setup_mock)"
  rm "$mock/ops/bindings/evidence.retention.policy.yaml"
  if SPINE_ROOT="$mock" bash "$GATE" >/dev/null 2>&1; then
    fail "missing policy should fail D96"
  else
    pass "missing policy fails D96"
  fi
  rm -rf "$mock"
}

# Test 3: Missing product doc fails
test_missing_doc() {
  local mock
  mock="$(setup_mock)"
  rm "$mock/docs/product/AOF_EVIDENCE_RETENTION_EXPORT.md"
  if SPINE_ROOT="$mock" bash "$GATE" >/dev/null 2>&1; then
    fail "missing product doc should fail D96"
  else
    pass "missing product doc fails D96"
  fi
  rm -rf "$mock"
}

# Test 4: Missing receipts base dir fails
test_missing_receipts() {
  local mock
  mock="$(setup_mock)"
  rm -rf "$mock/receipts"
  if SPINE_ROOT="$mock" bash "$GATE" >/dev/null 2>&1; then
    fail "missing receipts dir should fail D96"
  else
    pass "missing receipts dir fails D96"
  fi
  rm -rf "$mock"
}

# Run all tests
echo "D96 Tests"
echo "════════════════════════════════════════"
test_valid_setup
test_missing_policy
test_missing_doc
test_missing_receipts

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL_COUNT failed (of $((PASS + FAIL_COUNT)))"
exit "$FAIL_COUNT"

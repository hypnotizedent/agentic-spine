#!/usr/bin/env bash
# Tests for D97: surface-readonly-contract-lock
set -euo pipefail

SP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
GATE="$SP/surfaces/verify/d97-surface-readonly-contract-lock.sh"

PASS=0; FAIL_COUNT=0
pass() { PASS=$((PASS+1)); echo "PASS: $1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT+1)); echo "FAIL: $1" >&2; }

setup_mock() {
  local tmp
  tmp="$(mktemp -d)"

  mkdir -p "$tmp/ops/bindings"

  # Contract binding
  cat > "$tmp/ops/bindings/surface.readonly.contract.yaml" <<'EOF'
version: 1
updated: "2026-02-15"
surfaces:
  spine_status:
    description: "Spine status"
    capability: "spine.status"
    format: text
    access: local
    exists: true
  gap_reconciliation:
    description: "Gap reconciliation"
    capability: "gaps.status"
    format: text
    access: local
    exists: true
  loop_summary:
    description: "Loop summary"
    capability: "loops.status"
    format: text
    access: local
    exists: true
  rag_status:
    description: "RAG status"
    capability: "rag.anythingllm.status"
    format: text
    access: local
    exists: true
  proposal_queue:
    description: "Proposal queue"
    capability: "proposals.status"
    format: text
    access: local
    exists: true
  mobile_dashboard:
    description: "Mobile dashboard"
    capability: null
    format: json
    access: remote
    exists: false
    gap: "Planned for Phase B"
enforcement:
  gate: D97
EOF

  # Capabilities (mock with matching entries)
  cat > "$tmp/ops/capabilities.yaml" <<'EOF'
capabilities:
  spine.status:
    description: "Status"
  gaps.status:
    description: "Gaps"
  loops.status:
    description: "Loops"
  rag.anythingllm.status:
    description: "RAG"
  proposals.status:
    description: "Proposals"
EOF

  # Product doc
  mkdir -p "$tmp/docs/product"
  cat > "$tmp/docs/product/AOF_SURFACE_READONLY_CONTRACT.md" <<'EOF'
---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-15
---
# Surface Readonly Contract
EOF

  echo "$tmp"
}

# Test 1: Valid setup passes
test_valid_setup() {
  local mock
  mock="$(setup_mock)"
  if SPINE_ROOT="$mock" bash "$GATE" >/dev/null 2>&1; then
    pass "valid setup passes D97"
  else
    fail "valid setup should pass D97"
  fi
  rm -rf "$mock"
}

# Test 2: Missing contract fails
test_missing_contract() {
  local mock
  mock="$(setup_mock)"
  rm "$mock/ops/bindings/surface.readonly.contract.yaml"
  if SPINE_ROOT="$mock" bash "$GATE" >/dev/null 2>&1; then
    fail "missing contract should fail D97"
  else
    pass "missing contract fails D97"
  fi
  rm -rf "$mock"
}

# Test 3: Missing product doc fails
test_missing_doc() {
  local mock
  mock="$(setup_mock)"
  rm "$mock/docs/product/AOF_SURFACE_READONLY_CONTRACT.md"
  if SPINE_ROOT="$mock" bash "$GATE" >/dev/null 2>&1; then
    fail "missing product doc should fail D97"
  else
    pass "missing product doc fails D97"
  fi
  rm -rf "$mock"
}

# Test 4: Mutating access fails
test_mutating_access() {
  local mock
  mock="$(setup_mock)"
  sed -i.bak 's/access: local/access: mutating/' "$mock/ops/bindings/surface.readonly.contract.yaml"
  if SPINE_ROOT="$mock" bash "$GATE" >/dev/null 2>&1; then
    fail "mutating access should fail D97"
  else
    pass "mutating access fails D97"
  fi
  rm -rf "$mock"
}

# Run all tests
echo "D97 Tests"
echo "════════════════════════════════════════"
test_valid_setup
test_missing_contract
test_missing_doc
test_mutating_access

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL_COUNT failed (of $((PASS + FAIL_COUNT)))"
exit "$FAIL_COUNT"

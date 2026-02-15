#!/usr/bin/env bash
# Tests for D94: policy-runtime-enforcement-lock
set -euo pipefail

SP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
GATE="$SP/surfaces/verify/d94-policy-runtime-enforcement-lock.sh"

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

  # Contract binding
  cat > "$tmp/ops/bindings/policy.runtime.contract.yaml" <<'EOF'
version: 1
updated: "2026-02-15"
owner: "@ronny"
knobs:
  drift_gate_mode:
    description: "Gate failure mode"
    enforcement_point: drift-gate.sh
    enforcement_mode: runtime
    wired: true
    wired_in: "surfaces/verify/drift-gate.sh"
    validates_via: "DRIFT_GATE_MODE variable"
  approval_default:
    description: "Approval mode"
    enforcement_point: cap.sh
    enforcement_mode: runtime
    wired: true
    wired_in: "ops/commands/cap.sh"
    validates_via: "APPROVAL_DEFAULT override"
  session_closeout_sla_hours:
    description: "Closeout SLA"
    enforcement_point: drift-gate.sh
    enforcement_mode: runtime
    wired: true
    wired_in: "surfaces/verify/drift-gate.sh"
    validates_via: "SLA_HOURS variable"
  warn_policy:
    description: "Warning escalation"
    enforcement_point: drift-gate.sh
    enforcement_mode: runtime
    wired: true
    wired_in: "surfaces/verify/drift-gate.sh"
    validates_via: "WARN_POLICY variable"
  stale_ssot_max_days:
    description: "SSOT freshness"
    enforcement_point: drift-gate.sh
    enforcement_mode: runtime
    wired: false
    wired_in: null
    validates_via: null
    gap: "Not yet wired"
  gap_auto_claim:
    description: "Auto-claim"
    enforcement_point: gaps.sh
    enforcement_mode: runtime
    wired: false
    wired_in: null
    validates_via: null
    gap: "Not yet wired"
  proposal_required:
    description: "Proposal flow"
    enforcement_point: cap.sh
    enforcement_mode: runtime
    wired: false
    wired_in: null
    validates_via: null
    gap: "Not yet wired"
  receipt_retention_days:
    description: "Retention"
    enforcement_point: evidence.export
    enforcement_mode: runtime
    wired: false
    wired_in: null
    validates_via: null
    gap: "Not yet wired"
  commit_sign_required:
    description: "Commit signing"
    enforcement_point: pre-commit hook
    enforcement_mode: runtime
    wired: false
    wired_in: null
    validates_via: null
    gap: "Not yet wired"
  multi_agent_writes:
    description: "Multi-agent write policy"
    enforcement_point: cap.sh
    enforcement_mode: runtime
    wired: false
    wired_in: null
    validates_via: null
    gap: "Not yet wired"
enforcement:
  gate: D94
EOF

  # Presets binding
  cat > "$tmp/ops/bindings/policy.presets.yaml" <<'EOF'
version: 1
presets:
  balanced:
    knobs: {}
EOF

  # Wired source files
  echo "# drift-gate" > "$tmp/surfaces/verify/drift-gate.sh"
  echo "# cap" > "$tmp/ops/commands/cap.sh"

  # Product doc
  mkdir -p "$tmp/docs/product"
  cat > "$tmp/docs/product/AOF_POLICY_RUNTIME_ENFORCEMENT.md" <<'EOF'
---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-15
---
# Policy Runtime Enforcement
EOF

  echo "$tmp"
}

# Test 1: Valid setup passes
test_valid_setup() {
  local mock
  mock="$(setup_mock)"
  if SPINE_ROOT="$mock" bash "$GATE" >/dev/null 2>&1; then
    pass "valid setup passes D94"
  else
    fail "valid setup should pass D94"
  fi
  rm -rf "$mock"
}

# Test 2: Missing contract fails
test_missing_contract() {
  local mock
  mock="$(setup_mock)"
  rm "$mock/ops/bindings/policy.runtime.contract.yaml"
  if SPINE_ROOT="$mock" bash "$GATE" >/dev/null 2>&1; then
    fail "missing contract should fail D94"
  else
    pass "missing contract fails D94"
  fi
  rm -rf "$mock"
}

# Test 3: Missing knob fails
test_missing_knob() {
  local mock
  mock="$(setup_mock)"
  sed -i.bak '/^  multi_agent_writes:/,/gap:/d' "$mock/ops/bindings/policy.runtime.contract.yaml"
  if SPINE_ROOT="$mock" bash "$GATE" >/dev/null 2>&1; then
    fail "missing knob should fail D94"
  else
    pass "missing knob fails D94"
  fi
  rm -rf "$mock"
}

# Test 4: Missing product doc fails
test_missing_doc() {
  local mock
  mock="$(setup_mock)"
  rm "$mock/docs/product/AOF_POLICY_RUNTIME_ENFORCEMENT.md"
  if SPINE_ROOT="$mock" bash "$GATE" >/dev/null 2>&1; then
    fail "missing product doc should fail D94"
  else
    pass "missing product doc fails D94"
  fi
  rm -rf "$mock"
}

# Run all tests
echo "D94 Tests"
echo "════════════════════════════════════════"
test_valid_setup
test_missing_contract
test_missing_knob
test_missing_doc

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL_COUNT failed (of $((PASS + FAIL_COUNT)))"
exit "$FAIL_COUNT"

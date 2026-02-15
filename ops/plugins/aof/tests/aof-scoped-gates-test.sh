#!/usr/bin/env bash
# aof-scoped-gates-test — Verify tier-scoped gate enforcement logic.
set -euo pipefail

SP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
SCOPED_GATES="$SP/ops/bindings/drift-gates.scoped.yaml"

PASS=0
FAIL=0
pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

# Source the scope logic from drift-gate.sh by extracting the relevant functions.
# We simulate different tiers by setting AOF_SCOPED / AOF_OUT_OF_SCOPE_GATES.

compute_out_of_scope() {
  local tier="$1"
  local enforced="" out_of_scope=""

  while IFS= read -r cat; do
    [[ -z "$cat" || "$cat" == "null" ]] && continue
    enforced="${enforced} ${cat} "
  done < <(yq -r ".environment_tiers.$tier.enforce[]?" "$SCOPED_GATES" 2>/dev/null || true)

  local all_cats="identity environment receipts services spine_core"
  for _cat in $all_cats; do
    if [[ "$enforced" != *" $_cat "* ]]; then
      while IFS= read -r _gate; do
        [[ -z "$_gate" || "$_gate" == "null" ]] && continue
        out_of_scope="${out_of_scope} ${_gate} "
      done < <(yq -r ".gate_to_legacy_mapping.$_cat[]?" "$SCOPED_GATES" 2>/dev/null || true)
    fi
  done

  echo "$out_of_scope"
}

is_gate_in_scope_test() {
  local gate_id="$1"
  local out_of_scope="$2"
  if [[ "$out_of_scope" == *" $gate_id "* ]]; then
    return 1
  fi
  return 0
}

test_minimal_only_identity() {
  local oos
  oos="$(compute_out_of_scope minimal)"
  # D61/D65 are identity — should be in scope
  if is_gate_in_scope_test "D61" "$oos" && is_gate_in_scope_test "D65" "$oos"; then
    pass "minimal: identity gates (D61,D65) in scope"
  else
    fail "minimal: identity gates should be in scope"
  fi
  # D6 is receipts — should be out of scope
  if ! is_gate_in_scope_test "D6" "$oos"; then
    pass "minimal: receipts gate (D6) out of scope"
  else
    fail "minimal: receipts gate (D6) should be out of scope"
  fi
  # D54 is environment — should be out of scope
  if ! is_gate_in_scope_test "D54" "$oos"; then
    pass "minimal: environment gate (D54) out of scope"
  else
    fail "minimal: environment gate (D54) should be out of scope"
  fi
  # D1 is spine_core — should be out of scope
  if ! is_gate_in_scope_test "D1" "$oos"; then
    pass "minimal: spine_core gate (D1) out of scope"
  else
    fail "minimal: spine_core gate (D1) should be out of scope for minimal"
  fi
}

test_production_all_enforced() {
  local oos
  oos="$(compute_out_of_scope production)"
  # All categories enforced — no gates should be out of scope
  if [[ -z "$(echo "$oos" | tr -d ' ')" ]]; then
    pass "production: all gates in scope (empty out-of-scope)"
  else
    fail "production: expected no out-of-scope gates, got: $oos"
  fi
}

test_product_tier() {
  local oos
  oos="$(compute_out_of_scope product)"
  # Product enforces: identity, receipts, spine_core
  # Out of scope: environment (D54,D59) and services (D23,D63)
  if ! is_gate_in_scope_test "D54" "$oos" && ! is_gate_in_scope_test "D59" "$oos"; then
    pass "product: environment gates (D54,D59) out of scope"
  else
    fail "product: environment gates should be out of scope"
  fi
  if ! is_gate_in_scope_test "D23" "$oos" && ! is_gate_in_scope_test "D63" "$oos"; then
    pass "product: services gates (D23,D63) out of scope"
  else
    fail "product: services gates should be out of scope"
  fi
  # spine_core gates (D1,D2,D3,D7,D12) should be in scope
  local all_in=1
  for g in D1 D2 D3 D7 D12; do
    if ! is_gate_in_scope_test "$g" "$oos"; then
      all_in=0
      break
    fi
  done
  if [[ "$all_in" -eq 1 ]]; then
    pass "product: spine_core gates in scope"
  else
    fail "product: spine_core gates should be in scope"
  fi
}

test_unmapped_gate_always_enforced() {
  # D84 is not in gate_to_legacy_mapping — should always be in scope
  local oos
  oos="$(compute_out_of_scope minimal)"
  if is_gate_in_scope_test "D84" "$oos"; then
    pass "unmapped gate (D84) always enforced for minimal"
  else
    fail "unmapped gate (D84) should always be enforced"
  fi
  oos="$(compute_out_of_scope ephemeral)"
  if is_gate_in_scope_test "D84" "$oos"; then
    pass "unmapped gate (D84) always enforced for ephemeral"
  else
    fail "unmapped gate (D84) should always be enforced"
  fi
}

read_fail_action() {
  local tier="$1"
  yq -r ".environment_tiers.$tier.fail_action // \"block\"" "$SCOPED_GATES" 2>/dev/null || echo block
}

test_fail_action_production_is_block() {
  local fa
  fa="$(read_fail_action production)"
  if [[ "$fa" == "block" ]]; then
    pass "production fail_action=block"
  else
    fail "production fail_action expected block, got $fa"
  fi
}

test_fail_action_lab_is_warn() {
  local fa
  fa="$(read_fail_action lab)"
  if [[ "$fa" == "warn" ]]; then
    pass "lab fail_action=warn"
  else
    fail "lab fail_action expected warn, got $fa"
  fi
}

test_fail_action_minimal_is_warn() {
  local fa
  fa="$(read_fail_action minimal)"
  if [[ "$fa" == "warn" ]]; then
    pass "minimal fail_action=warn"
  else
    fail "minimal fail_action expected warn, got $fa"
  fi
}

test_fail_action_product_is_block() {
  local fa
  fa="$(read_fail_action product)"
  if [[ "$fa" == "block" ]]; then
    pass "product fail_action=block"
  else
    fail "product fail_action expected block, got $fa"
  fi
}

echo "aof-scoped-gates Tests"
echo "════════════════════════════════════════"
test_minimal_only_identity
test_production_all_enforced
test_product_tier
test_unmapped_gate_always_enforced
test_fail_action_production_is_block
test_fail_action_lab_is_warn
test_fail_action_minimal_is_warn
test_fail_action_product_is_block
echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed (of $((PASS + FAIL)))"
exit "$FAIL"

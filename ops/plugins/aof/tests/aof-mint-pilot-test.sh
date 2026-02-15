#!/usr/bin/env bash
# aof-mint-pilot-test — End-to-end pilot: bootstrap → validate → ack → status
# Simulates mint-modules workspace lifecycle using product profile.
set -euo pipefail

SP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
BOOTSTRAP="$SP/ops/plugins/aof/bin/bootstrap-spine.sh"
VALIDATE="$SP/ops/plugins/aof/bin/validate-environment.sh"
READCHECK="$SP/ops/plugins/aof/bin/contract-read-check.sh"

PASS=0
FAIL=0
pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

TMP=""
cleanup() { [[ -n "$TMP" ]] && rm -rf "$TMP" 2>/dev/null || true; }
trap cleanup EXIT INT TERM

TMP="$(mktemp -d)"

test_bootstrap_product() {
  if SPINE_ROOT="$SP" bash "$BOOTSTRAP" --environment-name mint-modules --profile product --target "$TMP" >/dev/null 2>&1; then
    pass "bootstrap with product profile"
  else
    fail "bootstrap with product profile"
  fi
}

test_env_file_exists() {
  if [[ -f "$TMP/.environment.yaml" ]]; then
    pass ".environment.yaml created"
  else
    fail ".environment.yaml not created"
  fi
}

test_identity_file_exists() {
  if [[ -f "$TMP/.identity.yaml" ]]; then
    pass ".identity.yaml created"
  else
    fail ".identity.yaml not created"
  fi
}

test_tier_is_product() {
  local tier
  tier="$(yq -r '.environment.tier // "missing"' "$TMP/.environment.yaml" 2>/dev/null || echo missing)"
  if [[ "$tier" == "product" ]]; then
    pass "tier=product in .environment.yaml"
  else
    fail "expected tier=product, got tier=$tier"
  fi
}

test_env_name_is_mint_modules() {
  local name
  name="$(yq -r '.environment.name // "missing"' "$TMP/.environment.yaml" 2>/dev/null || echo missing)"
  if [[ "$name" == "mint-modules" ]]; then
    pass "environment.name=mint-modules"
  else
    fail "expected environment.name=mint-modules, got $name"
  fi
}

test_validate_passes() {
  if (cd "$TMP" && bash "$VALIDATE" --environment-file .environment.yaml --identity-file .identity.yaml >/dev/null 2>&1); then
    pass "validate passes on bootstrapped contracts"
  else
    fail "validate should pass on bootstrapped contracts"
  fi
}

test_readcheck_blocks_before_ack() {
  local rc
  set +e
  (cd "$TMP" && bash "$READCHECK" >/dev/null 2>&1)
  rc=$?
  set -e
  if [[ "$rc" -eq 2 ]]; then
    pass "contract check blocks before ack (exit 2)"
  else
    fail "contract check should exit 2 before ack (got $rc)"
  fi
}

test_ack_succeeds() {
  if (cd "$TMP" && bash "$READCHECK" --ack >/dev/null 2>&1); then
    pass "contract ack succeeds"
  else
    fail "contract ack should succeed"
  fi
}

test_readcheck_passes_after_ack() {
  local rc
  set +e
  (cd "$TMP" && bash "$READCHECK" >/dev/null 2>&1)
  rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    pass "contract check passes after ack"
  else
    fail "contract check should pass after ack (got $rc)"
  fi
}

test_status_shows_current() {
  local output
  output="$(cd "$TMP" && bash "$READCHECK" --status 2>&1)"
  if echo "$output" | grep -q "current"; then
    pass "status shows marker_state=current"
  else
    fail "status should show current after ack"
  fi
}

echo "aof-mint-pilot Tests"
echo "════════════════════════════════════════"
test_bootstrap_product
test_env_file_exists
test_identity_file_exists
test_tier_is_product
test_env_name_is_mint_modules
test_validate_passes
test_readcheck_blocks_before_ack
test_ack_succeeds
test_readcheck_passes_after_ack
test_status_shows_current
echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed (of $((PASS + FAIL)))"
exit "$FAIL"

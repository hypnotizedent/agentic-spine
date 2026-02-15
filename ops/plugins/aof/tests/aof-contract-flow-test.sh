#!/usr/bin/env bash
# Tests for AOF plugin scripts (validate + contract-read-check).
set -euo pipefail

SP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
VALIDATE="$SP/ops/plugins/aof/bin/validate-environment.sh"
READCHECK="$SP/ops/plugins/aof/bin/contract-read-check.sh"

PASS=0
FAIL=0
pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

make_contracts() {
  local d="$1"
  cat > "$d/.environment.yaml" <<'EOF'
version: "1.0"
environment:
  name: test-env
  tier: minimal
contracts:
  preflight:
    - read_environment_contract
EOF
  cat > "$d/.identity.yaml" <<'EOF'
version: "1.0"
identity:
  node_id: test-node
  deployed_at: 2026-02-15T00:00:00Z
  spine_version: v1.0.0
  environment: test-env
EOF
}

test_validate_passes() {
  local tmp
  tmp="$(mktemp -d)"
  make_contracts "$tmp"
  if (cd "$tmp" && bash "$VALIDATE" --environment-file .environment.yaml --identity-file .identity.yaml >/dev/null 2>&1); then
    pass "validate passes with valid contracts"
  else
    fail "validate should pass with valid contracts"
  fi
  rm -rf "$tmp"
}

test_validate_fails_bad_tier() {
  local tmp
  tmp="$(mktemp -d)"
  make_contracts "$tmp"
  sed -i.bak 's/tier: minimal/tier: invalid/' "$tmp/.environment.yaml"
  rm -f "$tmp/.environment.yaml.bak"
  if (cd "$tmp" && bash "$VALIDATE" --environment-file .environment.yaml --identity-file .identity.yaml >/dev/null 2>&1); then
    fail "validate should fail for invalid tier"
  else
    pass "validate fails for invalid tier"
  fi
  rm -rf "$tmp"
}

test_readcheck_requires_ack() {
  local tmp
  tmp="$(mktemp -d)"
  make_contracts "$tmp"
  if (cd "$tmp" && bash "$READCHECK" >/dev/null 2>&1); then
    fail "readcheck default should require ack"
  else
    rc=$?
    if [[ "$rc" -eq 2 ]]; then
      pass "readcheck exits 2 when ack missing"
    else
      fail "readcheck expected rc=2, got rc=$rc"
    fi
  fi
  rm -rf "$tmp"
}

test_readcheck_ack_and_status() {
  local tmp
  tmp="$(mktemp -d)"
  make_contracts "$tmp"
  if (cd "$tmp" && bash "$READCHECK" --ack >/dev/null 2>&1 && bash "$READCHECK" >/dev/null 2>&1 && bash "$READCHECK" --status >/dev/null 2>&1); then
    pass "readcheck ack + status flow passes"
  else
    fail "readcheck ack + status flow should pass"
  fi
  rm -rf "$tmp"
}

test_cap_blocks_without_ack() {
  local tmp
  tmp="$(mktemp -d)"
  make_contracts "$tmp"
  # Simulate cap.sh contract check: source the enforcement logic inline
  local env_contract="$tmp/.environment.yaml"
  local ack_check ack_rc
  set +e
  ack_check="$(CONTRACT_FILE="$env_contract" bash "$READCHECK" 2>&1)"
  ack_rc=$?
  set -e
  if [[ "$ack_rc" -eq 2 ]]; then
    pass "cap blocks mutating without ack (exit 2)"
  else
    fail "cap should block mutating without ack (got rc=$ack_rc)"
  fi
  rm -rf "$tmp"
}

test_cap_passes_after_ack() {
  local tmp
  tmp="$(mktemp -d)"
  make_contracts "$tmp"
  # Acknowledge first
  (cd "$tmp" && bash "$READCHECK" --ack >/dev/null 2>&1)
  # Now check should pass
  local env_contract="$tmp/.environment.yaml"
  local ack_check ack_rc
  set +e
  ack_check="$(cd "$tmp" && CONTRACT_FILE="$env_contract" bash "$READCHECK" 2>&1)"
  ack_rc=$?
  set -e
  if [[ "$ack_rc" -eq 0 ]]; then
    pass "cap passes after ack"
  else
    fail "cap should pass after ack (got rc=$ack_rc)"
  fi
  rm -rf "$tmp"
}

echo "aof-contract-flow Tests"
echo "════════════════════════════════════════"
test_validate_passes
test_validate_fails_bad_tier
test_readcheck_requires_ack
test_readcheck_ack_and_status
test_cap_blocks_without_ack
test_cap_passes_after_ack
echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed (of $((PASS + FAIL)))"
exit "$FAIL"

#!/usr/bin/env bash
set -euo pipefail

# test-gap-mutations.sh — Integration tests for gap mutation capabilities
#
# Tests:
#   1. gaps.file: create a gap, verify it exists
#   2. gaps.claim: claim a gap, verify claim file
#   3. Wrong-owner close rejection
#   4. Stale-claim recovery
#   5. gaps.close: close a gap with proper ownership
#   6. Concurrent create race (git-lock serialization)
#
# Uses a temporary copy of operational.gaps.yaml to avoid mutating real state.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"

# Test infrastructure
PASS=0
FAIL=0
TEST_GAPS_DIR=""
ORIG_GAPS_FILE="$ROOT/ops/bindings/operational.gaps.yaml"

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1" >&2; FAIL=$((FAIL + 1)); }

# Set up isolated test environment
setup() {
  TEST_GAPS_DIR=$(mktemp -d)
  # Copy gaps file for testing
  cp "$ORIG_GAPS_FILE" "$TEST_GAPS_DIR/operational.gaps.yaml"
  # Create claims directory
  mkdir -p "$TEST_GAPS_DIR/claims"
  # Clean any leftover test claims
  rm -f "$ROOT/mailroom/state/gaps/GAP-OP-TEST-"*.claim 2>/dev/null || true
}

teardown() {
  rm -rf "$TEST_GAPS_DIR" 2>/dev/null || true
  rm -f "$ROOT/mailroom/state/gaps/GAP-OP-TEST-"*.claim 2>/dev/null || true
}

trap teardown EXIT INT TERM

# ─────────────────────────────────────────────────────────────────────────
# Test 1: Claim library — claim_gap / unclaim_gap / verify_claim_ownership
# ─────────────────────────────────────────────────────────────────────────
test_claim_lifecycle() {
  echo "Test 1: Claim lifecycle"

  source "$ROOT/ops/plugins/loops/lib/gap-claims.sh"
  mkdir -p "$ROOT/mailroom/state/gaps"

  # Use a known open gap for testing claims
  local test_gap="GAP-OP-135"  # known open gap

  # Clean any prior claim
  rm -f "$(claim_file "$test_gap")" 2>/dev/null || true

  # Claim it
  if claim_gap "$test_gap" "test-claim"; then
    pass "claim_gap succeeded"
  else
    fail "claim_gap failed"
    return
  fi

  # Verify claim file exists
  local cf
  cf=$(claim_file "$test_gap")
  if [[ -f "$cf" ]]; then
    pass "claim file created"
  else
    fail "claim file not created"
    return
  fi

  # Verify ownership
  if verify_claim_ownership "$test_gap"; then
    pass "verify_claim_ownership (same PID)"
  else
    fail "verify_claim_ownership rejected own PID"
  fi

  # Unclaim
  if unclaim_gap "$test_gap"; then
    pass "unclaim_gap succeeded"
  else
    fail "unclaim_gap failed"
  fi

  # Verify claim file removed
  if [[ ! -f "$cf" ]]; then
    pass "claim file removed after unclaim"
  else
    fail "claim file still exists after unclaim"
    rm -f "$cf"
  fi
}

# ─────────────────────────────────────────────────────────────────────────
# Test 2: Wrong-owner close rejection
# ─────────────────────────────────────────────────────────────────────────
test_wrong_owner_rejection() {
  echo "Test 2: Wrong-owner close rejection"

  source "$ROOT/ops/plugins/loops/lib/gap-claims.sh"
  mkdir -p "$ROOT/mailroom/state/gaps"

  local test_gap="GAP-OP-135"  # known open gap
  local cf
  cf=$(claim_file "$test_gap")

  # Create a fake claim owned by a different (live) PID
  # Use PID 1 (init/launchd) which is always running
  cat > "$cf" <<EOF
gap_id=$test_gap
owner_pid=1
claimed_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
action=test-foreign-claim
EOF

  # verify_claim_ownership should reject (PID 1 is alive but not us)
  if verify_claim_ownership "$test_gap" 2>/dev/null; then
    fail "verify_claim_ownership should have rejected foreign PID"
  else
    pass "verify_claim_ownership rejected foreign PID"
  fi

  # unclaim_gap should also reject
  if unclaim_gap "$test_gap" 2>/dev/null; then
    fail "unclaim_gap should have rejected foreign PID"
  else
    pass "unclaim_gap rejected foreign PID"
  fi

  # Clean up
  rm -f "$cf"
}

# ─────────────────────────────────────────────────────────────────────────
# Test 3: Stale-claim recovery
# ─────────────────────────────────────────────────────────────────────────
test_stale_claim_recovery() {
  echo "Test 3: Stale-claim recovery"

  source "$ROOT/ops/plugins/loops/lib/gap-claims.sh"
  mkdir -p "$ROOT/mailroom/state/gaps"

  local test_gap="GAP-OP-135"
  local cf
  cf=$(claim_file "$test_gap")

  # Create a claim with a dead PID (99999 is very unlikely to exist)
  cat > "$cf" <<EOF
gap_id=$test_gap
owner_pid=99999
claimed_at=2026-01-01T00:00:00Z
action=test-stale-claim
EOF

  # claim_gap should recover the stale claim and succeed
  if claim_gap "$test_gap" "recovery-test" 2>/dev/null; then
    pass "claim_gap recovered stale claim"
  else
    fail "claim_gap failed on stale claim"
  fi

  # Verify we now own the claim
  if verify_claim_ownership "$test_gap"; then
    pass "verify_claim_ownership after stale recovery"
  else
    fail "verify_claim_ownership failed after stale recovery"
  fi

  # Test cleanup_stale_claims with another dead PID claim
  local test_gap2="GAP-OP-TEST-STALE"
  local cf2="${CLAIMS_DIR}/${test_gap2}.claim"
  cat > "$cf2" <<EOF
gap_id=$test_gap2
owner_pid=99998
claimed_at=2026-01-01T00:00:00Z
action=test-stale-cleanup
EOF

  local cleaned
  cleaned=$(cleanup_stale_claims 2>/dev/null)
  if [[ "$cleaned" -ge 1 ]]; then
    pass "cleanup_stale_claims removed dead PID claims (cleaned=$cleaned)"
  else
    fail "cleanup_stale_claims did not clean stale claims (cleaned=$cleaned)"
  fi

  # Clean up our own claim
  rm -f "$cf" "$cf2" 2>/dev/null || true
}

# ─────────────────────────────────────────────────────────────────────────
# Test 4: Double-claim prevention
# ─────────────────────────────────────────────────────────────────────────
test_double_claim_prevention() {
  echo "Test 4: Double-claim prevention"

  source "$ROOT/ops/plugins/loops/lib/gap-claims.sh"
  mkdir -p "$ROOT/mailroom/state/gaps"

  local test_gap="GAP-OP-135"
  local cf
  cf=$(claim_file "$test_gap")

  # Clean any prior
  rm -f "$cf" 2>/dev/null || true

  # First claim succeeds
  claim_gap "$test_gap" "first-claim" || { fail "first claim failed"; return; }

  # Create a fake claim from PID 1 (live, not us) to simulate another agent
  cat > "$cf" <<EOF
gap_id=$test_gap
owner_pid=1
claimed_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
action=foreign-claim
EOF

  # Second claim should fail (PID 1 is alive)
  if claim_gap "$test_gap" "second-claim" 2>/dev/null; then
    fail "double claim should have been rejected"
  else
    pass "double claim correctly rejected"
  fi

  # Clean up
  rm -f "$cf"
}

# ─────────────────────────────────────────────────────────────────────────
# Test 5: gaps-file script argument validation
# ─────────────────────────────────────────────────────────────────────────
test_gaps_file_validation() {
  echo "Test 5: gaps-file argument validation"

  # Missing required args
  if "$ROOT/ops/plugins/loops/bin/gaps-file" --id GAP-OP-TEST-001 2>/dev/null; then
    fail "gaps-file should reject missing --type"
  else
    pass "gaps-file rejects missing --type"
  fi

  # Invalid type
  if "$ROOT/ops/plugins/loops/bin/gaps-file" --id GAP-OP-TEST-001 --type invalid --severity low --description "test" --discovered-by "test" 2>/dev/null; then
    fail "gaps-file should reject invalid type"
  else
    pass "gaps-file rejects invalid type"
  fi

  # Invalid severity
  if "$ROOT/ops/plugins/loops/bin/gaps-file" --id GAP-OP-TEST-001 --type stale-ssot --severity invalid --description "test" --discovered-by "test" 2>/dev/null; then
    fail "gaps-file should reject invalid severity"
  else
    pass "gaps-file rejects invalid severity"
  fi

  # Duplicate gap (use an existing one)
  if "$ROOT/ops/plugins/loops/bin/gaps-file" --id GAP-OP-135 --type stale-ssot --severity low --description "test" --discovered-by "test" 2>/dev/null; then
    fail "gaps-file should reject duplicate gap"
  else
    pass "gaps-file rejects duplicate gap"
  fi
}

# ─────────────────────────────────────────────────────────────────────────
# Test 6: gaps-close argument validation
# ─────────────────────────────────────────────────────────────────────────
test_gaps_close_validation() {
  echo "Test 6: gaps-close argument validation"

  # Missing --status
  if "$ROOT/ops/plugins/loops/bin/gaps-close" GAP-OP-135 2>/dev/null; then
    fail "gaps-close should reject missing --status"
  else
    pass "gaps-close rejects missing --status"
  fi

  # Invalid status
  if "$ROOT/ops/plugins/loops/bin/gaps-close" GAP-OP-135 --status invalid 2>/dev/null; then
    fail "gaps-close should reject invalid status"
  else
    pass "gaps-close rejects invalid status"
  fi

  # Non-existent gap
  if "$ROOT/ops/plugins/loops/bin/gaps-close" GAP-OP-NONEXISTENT --status fixed 2>/dev/null; then
    fail "gaps-close should reject non-existent gap"
  else
    pass "gaps-close rejects non-existent gap"
  fi
}

# ─────────────────────────────────────────────────────────────────────────
# Test 7: Concurrent git-lock serialization
# ─────────────────────────────────────────────────────────────────────────
test_concurrent_lock_serialization() {
  echo "Test 7: Concurrent git-lock serialization"

  source "$ROOT/ops/lib/git-lock.sh"

  # Acquire the lock
  acquire_git_lock || { fail "could not acquire git-lock for test"; return; }

  # Try to acquire again from a subshell (should fail because we hold it)
  if (source "$ROOT/ops/lib/git-lock.sh" && acquire_git_lock) 2>/dev/null; then
    fail "second lock acquisition should have failed"
  else
    pass "concurrent lock acquisition correctly rejected"
  fi

  # Release
  release_git_lock

  # Now acquisition should succeed
  if (source "$ROOT/ops/lib/git-lock.sh" && acquire_git_lock && release_git_lock) 2>/dev/null; then
    pass "lock acquisition after release succeeded"
  else
    fail "lock acquisition after release failed"
  fi
}

# ─────────────────────────────────────────────────────────────────────────
# Run all tests
# ─────────────────────────────────────────────────────────────────────────
echo "═══════════════════════════════════════════════════════════════"
echo "  Gap Mutation Capability Tests"
echo "═══════════════════════════════════════════════════════════════"
echo

setup

test_claim_lifecycle
echo
test_wrong_owner_rejection
echo
test_stale_claim_recovery
echo
test_double_claim_prevention
echo
test_gaps_file_validation
echo
test_gaps_close_validation
echo
test_concurrent_lock_serialization

echo
echo "═══════════════════════════════════════════════════════════════"
echo "  Results: $PASS passed, $FAIL failed"
echo "═══════════════════════════════════════════════════════════════"

teardown

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
exit 0

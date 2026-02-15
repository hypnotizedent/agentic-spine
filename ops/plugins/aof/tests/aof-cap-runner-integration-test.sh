#!/usr/bin/env bash
# aof-cap-runner-integration-test — Verify contract ack enforcement via actual cap runner.
# Places a temporary .environment.yaml at SPINE_CODE root, exercises cap run, cleans up.
set -euo pipefail

SP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
OPS="$SP/bin/ops"

PASS=0
FAIL=0
pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

# Guard: .environment.yaml must NOT already exist at repo root
if [[ -f "$SP/.environment.yaml" ]]; then
  echo "SKIP: $SP/.environment.yaml already exists — cannot run integration test safely"
  exit 0
fi

cleanup() {
  rm -f "$SP/.environment.yaml" 2>/dev/null || true
  # Remove any ack marker created during test (pattern: .contract_read_YYYYMMDD)
  rm -f "$SP"/.contract_read_* 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# Bootstrap a minimal .environment.yaml at repo root
cat > "$SP/.environment.yaml" <<'EOF'
version: "1.0"
environment:
  name: integration-test
  tier: minimal
contracts:
  preflight:
    - read_environment_contract
EOF

test_readonly_cap_not_blocked() {
  local output
  # aof.contract.status is read-only — should never be blocked by contract check
  output="$("$OPS" cap run aof.contract.status 2>&1 || true)"
  if echo "$output" | grep -q "BLOCKED: AOF contract"; then
    fail "read-only cap (aof.contract.status) should not be blocked"
  else
    pass "read-only cap not blocked by contract check"
  fi
}

test_mutating_cap_blocked_without_ack() {
  local output
  # gaps.file is mutating + approval:auto — contract check fires before execution
  # It will fail at argument validation, but BLOCKED should appear first
  output="$("$OPS" cap run gaps.file --id NOOP --type runtime-bug --severity low --description "noop" --discovered-by "test" --doc "test" 2>&1 || true)"
  if echo "$output" | grep -q "BLOCKED: AOF contract acknowledgment required"; then
    pass "mutating cap blocked without ack"
  else
    fail "mutating cap should show BLOCKED message (got: $(echo "$output" | head -5))"
  fi
}

test_ack_cap_exempt_from_check() {
  local output rc
  set +e
  output="$("$OPS" cap run aof.contract.acknowledge 2>&1 <<< "yes")"
  rc=$?
  set -e
  if echo "$output" | grep -q "BLOCKED: AOF contract"; then
    fail "aof.contract.acknowledge should be exempt from contract check"
  else
    pass "aof.contract.acknowledge exempt from check"
  fi
}

test_mutating_cap_passes_after_ack() {
  local output
  # After ack, mutating caps should not show BLOCKED
  # gaps.file will fail at its own validation, but that's fine — we check for BLOCKED absence
  output="$("$OPS" cap run gaps.file --id NOOP --type runtime-bug --severity low --description "noop" --discovered-by "test" --doc "test" 2>&1 || true)"
  if echo "$output" | grep -q "BLOCKED: AOF contract acknowledgment required"; then
    fail "mutating cap should not be blocked after ack"
  else
    pass "mutating cap not blocked after ack"
  fi
}

echo "aof-cap-runner-integration Tests"
echo "════════════════════════════════════════"
test_readonly_cap_not_blocked
test_mutating_cap_blocked_without_ack
test_ack_cap_exempt_from_check
test_mutating_cap_passes_after_ack
echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed (of $((PASS + FAIL)))"
cleanup
exit "$FAIL"

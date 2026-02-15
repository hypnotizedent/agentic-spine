#!/usr/bin/env bash
# aof-operator-caps-test — Verify AOF operator capabilities produce expected output.
set -euo pipefail

SP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"

PASS=0
FAIL=0
pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

test_status_runs() {
  local output
  output="$(bash "$SP/ops/plugins/aof/bin/aof-status.sh" 2>&1)"
  if echo "$output" | grep -q "AOF STATUS"; then
    pass "aof-status produces header"
  else
    fail "aof-status missing header"
  fi
}

test_status_shows_policy() {
  local output
  output="$(bash "$SP/ops/plugins/aof/bin/aof-status.sh" 2>&1)"
  if echo "$output" | grep -q "Policy:"; then
    pass "aof-status shows policy"
  else
    fail "aof-status missing policy line"
  fi
}

test_status_shows_cap_count() {
  local output
  output="$(bash "$SP/ops/plugins/aof/bin/aof-status.sh" 2>&1)"
  if echo "$output" | grep -q "Capabilities:.*aof\.\*"; then
    pass "aof-status shows cap count"
  else
    fail "aof-status missing cap count"
  fi
}

test_status_shows_gates() {
  local output
  output="$(bash "$SP/ops/plugins/aof/bin/aof-status.sh" 2>&1)"
  if echo "$output" | grep -q "Gates:.*active"; then
    pass "aof-status shows gate count"
  else
    fail "aof-status missing gate count"
  fi
}

test_version_runs() {
  local output
  output="$(bash "$SP/ops/plugins/aof/bin/aof-version.sh" 2>&1)"
  if echo "$output" | grep -q "AOF VERSION"; then
    pass "aof-version produces header"
  else
    fail "aof-version missing header"
  fi
}

test_version_shows_commit() {
  local output
  output="$(bash "$SP/ops/plugins/aof/bin/aof-version.sh" 2>&1)"
  if echo "$output" | grep -q "Commit:"; then
    pass "aof-version shows commit"
  else
    fail "aof-version missing commit"
  fi
}

test_version_shows_contract() {
  local output
  output="$(bash "$SP/ops/plugins/aof/bin/aof-version.sh" 2>&1)"
  if echo "$output" | grep -q "Contract:.*present"; then
    pass "aof-version shows contract present"
  else
    fail "aof-version missing contract"
  fi
}

test_policy_runs() {
  local output
  output="$(bash "$SP/ops/plugins/aof/bin/aof-policy-show.sh" 2>&1)"
  if echo "$output" | grep -q "AOF POLICY"; then
    pass "aof-policy-show produces header"
  else
    fail "aof-policy-show missing header"
  fi
}

test_policy_shows_all_knobs() {
  local output
  output="$(bash "$SP/ops/plugins/aof/bin/aof-policy-show.sh" 2>&1)"
  local missing=0
  for knob in drift_gate_mode warn_policy approval_default session_closeout_sla_hours stale_ssot_max_days gap_auto_claim proposal_required receipt_retention_days commit_sign_required multi_agent_writes; do
    if ! echo "$output" | grep -q "$knob:"; then
      missing=$((missing + 1))
    fi
  done
  if [[ "$missing" -eq 0 ]]; then
    pass "aof-policy-show shows all 10 knobs"
  else
    fail "aof-policy-show missing $missing knobs"
  fi
}

test_policy_shows_presets() {
  local output
  output="$(bash "$SP/ops/plugins/aof/bin/aof-policy-show.sh" 2>&1)"
  if echo "$output" | grep -q "Available presets:"; then
    pass "aof-policy-show lists presets"
  else
    fail "aof-policy-show missing preset list"
  fi
}

test_tenant_runs() {
  local output
  output="$(bash "$SP/ops/plugins/aof/bin/aof-tenant-show.sh" 2>&1)"
  if echo "$output" | grep -q "AOF TENANT PROFILE"; then
    pass "aof-tenant-show produces header"
  else
    fail "aof-tenant-show missing header"
  fi
}

test_tenant_shows_identity() {
  local output
  output="$(bash "$SP/ops/plugins/aof/bin/aof-tenant-show.sh" 2>&1)"
  if echo "$output" | grep -q "Tenant ID:"; then
    pass "aof-tenant-show shows identity"
  else
    fail "aof-tenant-show missing identity"
  fi
}

test_verify_runs() {
  local output rc
  set +e
  output="$(bash "$SP/ops/plugins/aof/bin/aof-verify.sh" 2>&1)"
  rc=$?
  set -e
  if echo "$output" | grep -q "AOF VERIFY"; then
    pass "aof-verify produces header"
  else
    fail "aof-verify missing header"
  fi
}

test_verify_runs_d91_d97() {
  local output rc
  set +e
  output="$(bash "$SP/ops/plugins/aof/bin/aof-verify.sh" 2>&1)"
  rc=$?
  set -e
  local gate_count
  gate_count="$(echo "$output" | grep -c "^D9[1-7]" || echo 0)"
  if [[ "$gate_count" -eq 7 ]]; then
    pass "aof-verify runs all 7 product gates (D91-D97)"
  else
    fail "aof-verify ran $gate_count gates, expected 7"
  fi
}

test_verify_exit_zero_when_all_pass() {
  local rc
  set +e
  bash "$SP/ops/plugins/aof/bin/aof-verify.sh" >/dev/null 2>&1
  rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    pass "aof-verify exits 0 when all gates pass"
  else
    fail "aof-verify should exit 0, got $rc"
  fi
}

echo "aof-operator-caps Tests"
echo "════════════════════════════════════════"
test_status_runs
test_status_shows_policy
test_status_shows_cap_count
test_status_shows_gates
test_version_runs
test_version_shows_commit
test_version_shows_contract
test_policy_runs
test_policy_shows_all_knobs
test_policy_shows_presets
test_tenant_runs
test_tenant_shows_identity
test_verify_runs
test_verify_runs_d91_d97
test_verify_exit_zero_when_all_pass
echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed (of $((PASS + FAIL)))"
exit "$FAIL"

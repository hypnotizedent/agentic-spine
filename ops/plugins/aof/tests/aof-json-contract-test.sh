#!/usr/bin/env bash
# aof-json-contract-test — Verify AOF operator JSON output contracts.
set -euo pipefail

SP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"

PASS=0
FAIL=0
JSON_OUT=""
JSON_RC=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

run_json() {
  local script="$1"
  set +e
  JSON_OUT="$(bash "$script" --json 2>&1)"
  JSON_RC=$?
  set -e
}

test_json_parses() {
  local cap="$1"
  local script="$2"
  run_json "$script"
  if echo "$JSON_OUT" | jq -e . >/dev/null 2>&1; then
    pass "$cap --json emits valid JSON"
  else
    fail "$cap --json did not emit valid JSON"
  fi
}

test_envelope_keys() {
  local cap="$1"
  local script="$2"
  run_json "$script"
  if echo "$JSON_OUT" | jq -e --arg cap "$cap" '
      type == "object" and
      (keys | sort == ["capability", "data", "generated_at", "schema_version", "status"]) and
      .capability == $cap and
      (.schema_version | type == "string" and length > 0) and
      (.generated_at | type == "string" and length > 0) and
      (.status | type == "string" and length > 0) and
      (.data | type == "object")
    ' >/dev/null 2>&1; then
    pass "$cap envelope keys stable"
  else
    fail "$cap envelope missing/changed required keys"
  fi
}

test_status_data_keys() {
  run_json "$SP/ops/plugins/aof/bin/aof-status.sh"
  if echo "$JSON_OUT" | jq -e '
      .data | has("contract") and has("policy") and has("counts") and has("tenant")
    ' >/dev/null 2>&1; then
    pass "aof.status data keys present"
  else
    fail "aof.status data keys missing"
  fi
}

test_version_data_keys() {
  run_json "$SP/ops/plugins/aof/bin/aof-version.sh"
  if echo "$JSON_OUT" | jq -e '
      .data | has("git") and has("contract") and has("schema") and has("presets") and has("gates") and has("capabilities")
    ' >/dev/null 2>&1; then
    pass "aof.version data keys present"
  else
    fail "aof.version data keys missing"
  fi
}

test_policy_data_keys() {
  run_json "$SP/ops/plugins/aof/bin/aof-policy-show.sh"
  if echo "$JSON_OUT" | jq -e '
      .data | has("active_preset") and has("knobs") and has("discovery") and has("available_presets") and
      (.knobs | has("drift_gate_mode") and has("warn_policy") and has("approval_default") and has("session_closeout_sla_hours") and has("stale_ssot_max_days") and has("gap_auto_claim") and has("proposal_required") and has("receipt_retention_days") and has("commit_sign_required") and has("multi_agent_writes"))
    ' >/dev/null 2>&1; then
    pass "aof.policy.show data keys present"
  else
    fail "aof.policy.show data keys missing"
  fi
}

test_tenant_data_keys() {
  run_json "$SP/ops/plugins/aof/bin/aof-tenant-show.sh"
  if echo "$JSON_OUT" | jq -e '
      .data | has("source") and has("identity") and has("secrets") and has("policy") and has("runtime") and has("surfaces")
    ' >/dev/null 2>&1; then
    pass "aof.tenant.show data keys present"
  else
    fail "aof.tenant.show data keys missing"
  fi
}

test_verify_data_keys() {
  run_json "$SP/ops/plugins/aof/bin/aof-verify.sh"
  if echo "$JSON_OUT" | jq -e '
      .data | has("passed") and has("failed") and has("skipped") and has("total") and has("failed_gates")
    ' >/dev/null 2>&1; then
    pass "aof.verify data keys present"
  else
    fail "aof.verify data keys missing"
  fi
}

test_verify_summary_math() {
  run_json "$SP/ops/plugins/aof/bin/aof-verify.sh"
  if echo "$JSON_OUT" | jq -e '
      .data.total == (.data.passed + .data.failed + .data.skipped)
    ' >/dev/null 2>&1; then
    pass "aof.verify summary math is consistent"
  else
    fail "aof.verify summary math mismatch"
  fi
}

echo "aof-json-contract Tests"
echo "════════════════════════════════════════"
test_json_parses "aof.status" "$SP/ops/plugins/aof/bin/aof-status.sh"
test_json_parses "aof.version" "$SP/ops/plugins/aof/bin/aof-version.sh"
test_json_parses "aof.policy.show" "$SP/ops/plugins/aof/bin/aof-policy-show.sh"
test_json_parses "aof.tenant.show" "$SP/ops/plugins/aof/bin/aof-tenant-show.sh"
test_json_parses "aof.verify" "$SP/ops/plugins/aof/bin/aof-verify.sh"
test_envelope_keys "aof.status" "$SP/ops/plugins/aof/bin/aof-status.sh"
test_envelope_keys "aof.version" "$SP/ops/plugins/aof/bin/aof-version.sh"
test_envelope_keys "aof.policy.show" "$SP/ops/plugins/aof/bin/aof-policy-show.sh"
test_envelope_keys "aof.tenant.show" "$SP/ops/plugins/aof/bin/aof-tenant-show.sh"
test_envelope_keys "aof.verify" "$SP/ops/plugins/aof/bin/aof-verify.sh"
test_status_data_keys
test_version_data_keys
test_policy_data_keys
test_tenant_data_keys
test_verify_data_keys
test_verify_summary_math
echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed (of $((PASS + FAIL)))"
exit "$FAIL"

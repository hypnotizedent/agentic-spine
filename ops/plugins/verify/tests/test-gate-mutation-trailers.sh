#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
RUNNER="$ROOT/ops/plugins/verify/bin/gate-mutation-trailers"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

echo "gate-mutation-trailers tests"
echo "════════════════════════════════════════"

if [[ -x "$RUNNER" ]]; then
  pass "runner is executable"
else
  fail "runner is executable"
  echo "Results: $PASS passed, $FAIL failed"
  exit "$FAIL"
fi

if output="$("$RUNNER" --capability gate.registry.update --run-key CAP-20260218-000000__gate.registry.update__Rtest123 2>&1)"; then
  pass "text mode exits 0"
else
  fail "text mode exits 0"
  echo "$output" >&2
fi

if echo "$output" | grep -q '^Gate-Mutation: capability$'; then
  pass "text mode includes Gate-Mutation"
else
  fail "text mode includes Gate-Mutation"
fi

if echo "$output" | grep -q '^Gate-Capability: gate.registry.update$'; then
  pass "text mode includes Gate-Capability"
else
  fail "text mode includes Gate-Capability"
fi

if echo "$output" | grep -q '^Gate-Run-Key: CAP-20260218-000000__gate.registry.update__Rtest123$'; then
  pass "text mode includes Gate-Run-Key"
else
  fail "text mode includes Gate-Run-Key"
fi

if json_out="$("$RUNNER" --capability gate.topology.assign --run-key CAP-20260218-000000__gate.topology.assign__Rtest456 --json 2>&1)"; then
  pass "json mode exits 0"
else
  fail "json mode exits 0"
  echo "$json_out" >&2
fi

if echo "$json_out" | jq -e '.GateCapability == "gate.topology.assign"' >/dev/null; then
  pass "json mode includes GateCapability"
else
  fail "json mode includes GateCapability"
fi

if invalid_out="$("$RUNNER" --capability invalid.cap --run-key CAP-20260218-000000__invalid.cap__Rtest789 2>&1)"; then
  fail "invalid capability should fail"
  echo "$invalid_out" >&2
else
  pass "invalid capability fails"
fi

echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"

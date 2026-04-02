#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
RUNNER="$ROOT/ops/plugins/core/verify/bin/gate-mutation-trailers"
FIXTURE_ROOT="$(mktemp -d)"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

cleanup() {
  rm -rf "$FIXTURE_ROOT"
}
trap cleanup EXIT

echo "gate-mutation-trailers tests"
echo "════════════════════════════════════════"

if [[ -x "$RUNNER" ]]; then
  pass "runner is executable"
else
  fail "runner is executable"
  echo "Results: $PASS passed, $FAIL failed"
  exit "$FAIL"
fi

if grep -q 'd128-gate-mutation-policy' "$RUNNER"; then
  fail "runner no longer depends on retired d128 policy binding"
else
  pass "runner no longer depends on retired d128 policy binding"
fi

mkdir -p "$FIXTURE_ROOT/ops/bindings"
cat > "$FIXTURE_ROOT/ops/bindings/routing.dispatch.yaml" <<'YAML'
gate.registry.update:
  capability_id: gate.registry.update
  target:
    script: gate-registry-update
projection.reconcile:
  capability_id: projection.reconcile
  target:
    script: projection-reconcile
YAML

cat > "$FIXTURE_ROOT/ops/bindings/capability_map.yaml" <<'YAML'
gate.registry.update:
  plugin: verify
  safety: mutating
projection.reconcile:
  plugin: null
  safety: mutating
YAML

if fixture_out="$(SPINE_ROOT="$FIXTURE_ROOT" "$RUNNER" --capability gate.registry.update --run-key CAP-20260218-000000__gate.registry.update__Rfixture001 2>&1)"; then
  pass "fixture live-authority capability exits 0 without retired policy file"
else
  fail "fixture live-authority capability exits 0 without retired policy file"
  echo "$fixture_out" >&2
fi

if projection_out="$(SPINE_ROOT="$FIXTURE_ROOT" "$RUNNER" --capability projection.reconcile --run-key CAP-20260218-000000__projection.reconcile__Rfixture002 2>&1)"; then
  pass "fixture projection.reconcile exits 0 from live authorities"
else
  fail "fixture projection.reconcile exits 0 from live authorities"
  echo "$projection_out" >&2
fi

if stale_out="$(SPINE_ROOT="$FIXTURE_ROOT" "$RUNNER" --capability gate.topology.assign --run-key CAP-20260218-000000__gate.topology.assign__Rfixture003 2>&1)"; then
  fail "fixture missing live-authority capability should fail"
  echo "$stale_out" >&2
else
  pass "fixture missing live-authority capability fails"
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

if output_validate="$("$RUNNER" --capability gate.topology.validate --run-key CAP-20260218-000000__gate.topology.validate__Rtest654 2>&1)"; then
  pass "live-authority capability exits 0"
else
  fail "live-authority capability exits 0"
  echo "$output_validate" >&2
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

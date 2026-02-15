#!/usr/bin/env bash
# aof-bridge-consumer-test — Verify AOF caps are correctly wired for bridge /cap/run.
#
# Tests:
#   T1: All 5 aof.* caps present in cap_rpc.allowlist
#   T2: No aof.* cap is mutating (safe for RPC)
#   T3: RBAC operator role covers all aof.* caps (via wildcard)
#   T4: RBAC monitor role includes aof.status and aof.version
#   T5: RBAC monitor role excludes aof.policy.show, aof.tenant.show, aof.verify
#   T6-T10: Each aof.* cap run with --json returns valid JSON envelope + receipt
set -euo pipefail

SP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
BRIDGE_BINDING="$SP/ops/bindings/mailroom.bridge.yaml"
CAP_BINDING="$SP/ops/capabilities.yaml"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

AOF_CAPS="aof.status aof.version aof.policy.show aof.tenant.show aof.verify"

echo "aof-bridge-consumer Tests"
echo "════════════════════════════════════════"

# ── T1: All 5 aof.* caps in cap_rpc.allowlist ──
echo ""
echo "T1: All 5 aof.* caps present in cap_rpc.allowlist"
(
  allowlist="$(yq '.cap_rpc.allowlist[]' "$BRIDGE_BINDING")"
  for cap in $AOF_CAPS; do
    echo "$allowlist" | grep -q "^${cap}$" || { echo "  missing: $cap" >&2; exit 1; }
  done
) && pass "all aof.* caps in allowlist" || fail "aof.* cap missing from allowlist"

# ── T2: No aof.* cap is mutating ──
echo ""
echo "T2: No aof.* cap is mutating (safe for bridge RPC)"
(
  for cap in $AOF_CAPS; do
    safety="$(yq ".capabilities.\"$cap\".safety" "$CAP_BINDING")"
    if [[ "$safety" != "read-only" ]]; then
      echo "  $cap is $safety, not read-only" >&2
      exit 1
    fi
  done
) && pass "all aof.* caps are read-only" || fail "aof.* cap is not read-only"

# ── T3: RBAC operator covers all aof.* via wildcard ──
echo ""
echo "T3: RBAC operator role covers all aof.* caps"
(
  op_allow="$(yq -r '.cap_rpc.roles.operator.allow' "$BRIDGE_BINDING")"
  [[ "$op_allow" == "*" ]] || { echo "  operator allow is '$op_allow', not '*'" >&2; exit 1; }
) && pass "operator role has wildcard access" || fail "operator role missing wildcard"

# ── T4: RBAC monitor includes aof.status and aof.version ──
echo ""
echo "T4: RBAC monitor role includes aof.status and aof.version"
(
  mon_allow="$(yq '.cap_rpc.roles.monitor.allow[]' "$BRIDGE_BINDING")"
  echo "$mon_allow" | grep -q "^aof.status$" || { echo "  monitor missing aof.status" >&2; exit 1; }
  echo "$mon_allow" | grep -q "^aof.version$" || { echo "  monitor missing aof.version" >&2; exit 1; }
) && pass "monitor has aof.status + aof.version" || fail "monitor missing aof status caps"

# ── T5: RBAC monitor excludes sensitive aof.* caps ──
echo ""
echo "T5: RBAC monitor excludes aof.policy.show, aof.tenant.show, aof.verify"
(
  mon_allow="$(yq '.cap_rpc.roles.monitor.allow[]' "$BRIDGE_BINDING")"
  for cap in aof.policy.show aof.tenant.show aof.verify; do
    if echo "$mon_allow" | grep -q "^${cap}$"; then
      echo "  monitor should NOT have $cap" >&2
      exit 1
    fi
  done
) && pass "monitor excludes sensitive aof.* caps" || fail "monitor has sensitive aof.* caps"

# ── T6-T10: Each aof.* cap returns valid JSON envelope + receipt via cap run ──
cap_scripts=(
  "aof.status:$SP/ops/plugins/aof/bin/aof-status.sh"
  "aof.version:$SP/ops/plugins/aof/bin/aof-version.sh"
  "aof.policy.show:$SP/ops/plugins/aof/bin/aof-policy-show.sh"
  "aof.tenant.show:$SP/ops/plugins/aof/bin/aof-tenant-show.sh"
  "aof.verify:$SP/ops/plugins/aof/bin/aof-verify.sh"
)

for entry in "${cap_scripts[@]}"; do
  cap="${entry%%:*}"
  script="${entry#*:}"
  echo ""
  echo "T: $cap --json returns valid JSON envelope + receipt"
  (
    set +e
    out="$(bash "$script" --json 2>&1)"
    rc=$?
    set -e

    # Must be valid JSON
    if ! echo "$out" | jq -e . >/dev/null 2>&1; then
      echo "  $cap --json did not emit valid JSON" >&2
      exit 1
    fi

    # Must have standard envelope keys
    if ! echo "$out" | jq -e '
        type == "object" and
        has("capability") and has("status") and has("schema_version") and
        has("generated_at") and has("data")
      ' >/dev/null 2>&1; then
      echo "  $cap envelope missing required keys" >&2
      exit 1
    fi

    # Capability name must match
    actual_cap="$(echo "$out" | jq -r '.capability')"
    if [[ "$actual_cap" != "$cap" ]]; then
      echo "  $cap capability field mismatch: got $actual_cap" >&2
      exit 1
    fi
  ) && pass "$cap JSON envelope valid" || fail "$cap JSON envelope invalid"
done

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed (of $((PASS + FAIL)))"
exit "$FAIL"

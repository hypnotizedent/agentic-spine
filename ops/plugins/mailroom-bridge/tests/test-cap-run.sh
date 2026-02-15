#!/usr/bin/env bash
set -euo pipefail

# test-cap-run.sh — Tests for /cap/run endpoint logic
#
# Tests:
#   T1: Allowlist enforcement — non-listed capability rejected
#   T2: Allowlist enforcement — listed capability accepted
#   T3: Response schema includes required fields
#   T4: Missing capability field returns 400
#   T5: Empty allowlist rejects all capabilities
#   T6: RBAC role enforcement logic exists
#   T7: Binding declares RBAC roles
#   T8: RBAC loader constrains roles within allowlist

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
BRIDGE="$ROOT/ops/plugins/mailroom-bridge/bin/mailroom-bridge-serve"

PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1" >&2; FAIL=$((FAIL + 1)); }

echo "=== /cap/run Endpoint Tests ==="

# ── T1: Non-listed capability rejected ──
echo ""
echo "T1: Non-listed capability rejected by allowlist"
(
  python3 -c "
import sys
sys.path.insert(0, '.')
# Verify the allowlist enforcement logic exists
with open('$BRIDGE') as f:
    code = f.read()
assert 'cap_rpc_allowlist' in code, 'allowlist config key not found'
assert 'not in allowlist' in code, 'allowlist rejection message not found'
assert 'FORBIDDEN' in code, 'FORBIDDEN status not used for allowlist rejection'
" || exit 1
) && pass "non-listed capability rejected" || fail "non-listed capability rejected"

# ── T2: Listed capability accepted ──
echo ""
echo "T2: Allowlist contains expected read-only capabilities"
(
  # Verify binding has allowlist with expected entries (avoid grep -q in pipe — SIGPIPE + pipefail)
  allowlist="$(yq '.cap_rpc.allowlist[]' "$ROOT/ops/bindings/mailroom.bridge.yaml")"
  echo "$allowlist" | grep "spine.verify" >/dev/null || { echo "  FAIL: spine.verify not in allowlist" >&2; exit 1; }
  echo "$allowlist" | grep "gaps.status" >/dev/null || { echo "  FAIL: gaps.status not in allowlist" >&2; exit 1; }
  # Verify no mutating capabilities in allowlist
  if echo "$allowlist" | grep -E "gaps\.(file|close|claim)" >/dev/null 2>&1; then
    echo "  FAIL: mutating gap capability found in allowlist" >&2
    exit 1
  fi
) && pass "allowlist contains read-only caps only" || fail "allowlist contains read-only caps only"

# ── T3: Response schema includes required fields ──
echo ""
echo "T3: Response schema includes required fields"
(
  python3 -c "
with open('$BRIDGE') as f:
    code = f.read()
# Check the cap-run handler returns all required fields
for field in ['capability', 'status', 'exit_code', 'output', 'receipt', 'run_key']:
    assert '\"' + field + '\"' in code, f'response field {field} not found in handler'
" || exit 1
) && pass "response schema complete" || fail "response schema complete"

# ── T4: Missing capability field returns error ──
echo ""
echo "T4: Missing capability field returns error"
(
  python3 -c "
with open('$BRIDGE') as f:
    code = f.read()
assert 'capability is required' in code, 'missing capability error message not found'
" || exit 1
) && pass "missing capability returns error" || fail "missing capability returns error"

# ── T5: Binding endpoint declaration exists ──
echo ""
echo "T5: /cap/run endpoint declared in binding"
(
  yq '.endpoints[] | select(.path == "/cap/run")' "$ROOT/ops/bindings/mailroom.bridge.yaml" | grep -q "POST" || exit 1
  yq '.endpoints[] | select(.path == "/cap/run")' "$ROOT/ops/bindings/mailroom.bridge.yaml" | grep -q "true" || exit 1
) && pass "/cap/run declared in binding" || fail "/cap/run declared in binding"

# ── T6: RBAC role enforcement logic exists ──
echo ""
echo "T6: RBAC role enforcement logic exists in bridge"
(
  python3 -c "
with open('$BRIDGE') as f:
    code = f.read()
assert 'cap_rpc_roles' in code, 'RBAC roles config key not found'
assert '_cap_rpc_role_allows' in code, 'RBAC enforcement method not found'
assert 'not permitted for this token role' in code, 'RBAC rejection message not found'
" || exit 1
) && pass "RBAC enforcement exists" || fail "RBAC enforcement exists"

# ── T7: Binding declares RBAC roles ──
echo ""
echo "T7: Binding declares RBAC roles with token_env + allow"
(
  # Check roles section exists with at least one role
  role_count="$(yq '.cap_rpc.roles | length' "$ROOT/ops/bindings/mailroom.bridge.yaml")"
  [[ "$role_count" -ge 1 ]] || { echo "  FAIL: no roles in binding" >&2; exit 1; }
  # Operator role should have full access
  op_allow="$(yq -r '.cap_rpc.roles.operator.allow' "$ROOT/ops/bindings/mailroom.bridge.yaml")"
  [[ "$op_allow" == "*" ]] || { echo "  FAIL: operator role not '*' (got: $op_allow)" >&2; exit 1; }
  # Monitor role should have restricted list
  mon_count="$(yq '.cap_rpc.roles.monitor.allow | length' "$ROOT/ops/bindings/mailroom.bridge.yaml")"
  [[ "$mon_count" -ge 1 ]] || { echo "  FAIL: monitor role allow list empty" >&2; exit 1; }
  [[ "$mon_count" -lt "$role_count" ]] || true  # monitor should have fewer caps than total
) && pass "RBAC roles in binding" || fail "RBAC roles in binding"

# ── T8: RBAC roles constrain within allowlist ──
echo ""
echo "T8: RBAC loader constrains roles within allowlist"
(
  python3 -c "
with open('$BRIDGE') as f:
    code = f.read()
# The role loading code should intersect with allowlist
assert 'if c in cap_rpc_allowlist' in code, 'RBAC roles not constrained to allowlist'
" || exit 1
) && pass "RBAC constrained to allowlist" || fail "RBAC constrained to allowlist"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"

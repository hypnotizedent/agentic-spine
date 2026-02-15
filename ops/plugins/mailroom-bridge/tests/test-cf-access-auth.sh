#!/usr/bin/env bash
set -euo pipefail

# test-cf-access-auth.sh — Tests for Cloudflare Access service-token auth
#
# Tests:
#   T1: _cf_access_ok method exists in bridge source
#   T2: _auth_ok calls CF Access check before token check
#   T3: JWT decode handles 3-part token format
#   T4: Audience validation present (cf_access_aud)
#   T5: CF Access config loaded from binding
#   T6: Binding declares auth.cf_access section with required keys
#   T7: _cap_rpc_role_allows grants full access to CF-auth requests
#   T8: Endpoints binding lists CF Access headers

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
BRIDGE="$ROOT/ops/plugins/mailroom-bridge/bin/mailroom-bridge-serve"
BINDING="$ROOT/ops/bindings/mailroom.bridge.yaml"
ENDPOINTS="$ROOT/ops/bindings/mailroom.bridge.endpoints.yaml"

PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1" >&2; FAIL=$((FAIL + 1)); }

echo "=== CF Access Auth Tests ==="

# ── T1: _cf_access_ok method exists ──
echo ""
echo "T1: _cf_access_ok method exists in bridge source"
(
  python3 -c "
with open('$BRIDGE') as f:
    code = f.read()
assert 'def _cf_access_ok(self)' in code, '_cf_access_ok method not found'
assert 'Cloudflare Access JWT' in code, 'CF Access docstring not found'
" || exit 1
) && pass "_cf_access_ok method exists" || fail "_cf_access_ok method exists"

# ── T2: _auth_ok calls CF Access check before token check ──
echo ""
echo "T2: _auth_ok calls CF Access check before token check"
(
  python3 -c "
with open('$BRIDGE') as f:
    code = f.read()
# Find _auth_ok and verify _cf_access_ok is called before token logic
auth_ok_pos = code.index('def _auth_ok(self)')
cf_call_pos = code.index('_cf_access_ok()', auth_ok_pos)
token_pos = code.index('primary_token', cf_call_pos)
assert cf_call_pos < token_pos, 'CF Access check must come before token check in _auth_ok'
" || exit 1
) && pass "_auth_ok checks CF Access first" || fail "_auth_ok checks CF Access first"

# ── T3: JWT decode handles 3-part token format ──
echo ""
echo "T3: JWT decode handles 3-part token format"
(
  python3 -c "
with open('$BRIDGE') as f:
    code = f.read()
assert 'split(\".\")' in code, 'JWT split by dot not found'
assert 'len(parts) != 3' in code, '3-part JWT validation not found'
assert 'base64' in code, 'base64 decode not found'
assert 'urlsafe_b64decode' in code, 'urlsafe base64 decode not found'
" || exit 1
) && pass "JWT 3-part decode" || fail "JWT 3-part decode"

# ── T4: Audience validation present ──
echo ""
echo "T4: Audience validation present (cf_access_aud)"
(
  python3 -c "
with open('$BRIDGE') as f:
    code = f.read()
assert 'cf_access_aud' in code, 'cf_access_aud config key not found'
assert 'payload.get(\"aud\")' in code, 'aud claim check not found'
assert 'cf_access_aud not in token_aud' in code, 'audience mismatch rejection not found'
" || exit 1
) && pass "audience validation" || fail "audience validation"

# ── T5: CF Access config loaded from binding ──
echo ""
echo "T5: CF Access config loaded from binding in main()"
(
  python3 -c "
with open('$BRIDGE') as f:
    code = f.read()
# Verify config loading parses all 3 CF Access keys
assert 'cf_access_enabled' in code, 'cf_access_enabled config not loaded'
assert 'cf_access_jwt_header' in code, 'cf_access_jwt_header config not loaded'
assert '.auth.cf_access.enabled' in code, 'binding path for cf_access.enabled not found'
assert '.auth.cf_access.aud' in code, 'binding path for cf_access.aud not found'
assert '.auth.cf_access.jwt_header' in code, 'binding path for cf_access.jwt_header not found'
" || exit 1
) && pass "CF Access config loading" || fail "CF Access config loading"

# ── T6: Binding declares auth.cf_access section ──
echo ""
echo "T6: Binding declares auth.cf_access section with required keys"
(
  enabled="$(yq -r '.auth.cf_access.enabled' "$BINDING")"
  [[ "$enabled" == "true" || "$enabled" == "false" ]] || { echo "  FAIL: cf_access.enabled not boolean (got: $enabled)" >&2; exit 1; }
  jwt_header="$(yq -r '.auth.cf_access.jwt_header' "$BINDING")"
  [[ "$jwt_header" == "Cf-Access-Jwt-Assertion" ]] || { echo "  FAIL: jwt_header unexpected (got: $jwt_header)" >&2; exit 1; }
  # aud can be empty string but key must exist
  aud_exists="$(yq '.auth.cf_access | has("aud")' "$BINDING")"
  [[ "$aud_exists" == "true" ]] || { echo "  FAIL: cf_access.aud key missing" >&2; exit 1; }
) && pass "binding cf_access section" || fail "binding cf_access section"

# ── T7: _cap_rpc_role_allows grants full access to CF-auth ──
echo ""
echo "T7: _cap_rpc_role_allows grants full access to CF-auth requests"
(
  python3 -c "
with open('$BRIDGE') as f:
    code = f.read()
# Find _cap_rpc_role_allows and verify _cf_access_ok grants full access
role_allows_pos = code.index('def _cap_rpc_role_allows(self')
cf_check_pos = code.index('_cf_access_ok()', role_allows_pos)
return_true_pos = code.index('return True', cf_check_pos)
# Verify the CF check + return True comes before the roles logic
roles_pos = code.index('cap_rpc_roles', return_true_pos)
assert return_true_pos < roles_pos, 'CF Access full access must come before roles check'
" || exit 1
) && pass "CF-auth gets operator-level RBAC" || fail "CF-auth gets operator-level RBAC"

# ── T8: Endpoints binding lists CF Access headers ──
echo ""
echo "T8: Endpoints binding lists CF Access headers"
(
  headers="$(yq -r '.security.supported_headers[]' "$ENDPOINTS")"
  echo "$headers" | grep "CF-Access-Client-Id" >/dev/null || { echo "  FAIL: CF-Access-Client-Id not in supported_headers" >&2; exit 1; }
  echo "$headers" | grep "CF-Access-Client-Secret" >/dev/null || { echo "  FAIL: CF-Access-Client-Secret not in supported_headers" >&2; exit 1; }
  echo "$headers" | grep "Cf-Access-Jwt-Assertion" >/dev/null || { echo "  FAIL: Cf-Access-Jwt-Assertion not in supported_headers" >&2; exit 1; }
) && pass "endpoints binding CF headers" || fail "endpoints binding CF headers"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"

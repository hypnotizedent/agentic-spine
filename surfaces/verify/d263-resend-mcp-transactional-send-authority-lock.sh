#!/usr/bin/env bash
# TRIAGE: Transactional email send authority must remain in spine communications pipeline only. Resend MCP send_email and batch_send_emails are forbidden in governed paths.
# D257: resend-mcp-transactional-send-authority-lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

fail() {
  echo "D257 FAIL: $*" >&2
  exit 1
}

# Check 1: Expansion contract exists and declares spine send authority
CONTRACT="$ROOT/docs/canonical/COMMUNICATIONS_RESEND_EXPANSION_CONTRACT_V1.yaml"
[[ -f "$CONTRACT" ]] || fail "expansion contract missing: $CONTRACT"

command -v yq >/dev/null 2>&1 || fail "missing command: yq"

authority_owner=$(yq e '.transactional_send_authority.owner' "$CONTRACT" 2>/dev/null)
authority_enforcement=$(yq e '.transactional_send_authority.enforcement' "$CONTRACT" 2>/dev/null)

[[ "$authority_owner" == "spine" ]] || fail "transactional_send_authority.owner must be 'spine' (actual=$authority_owner)"
[[ "$authority_enforcement" == "strict" ]] || fail "transactional_send_authority.enforcement must be 'strict' (actual=$authority_enforcement)"

# Check 2: MCP coexistence policy classifies send_email as forbidden
POLICY="$ROOT/docs/canonical/COMMUNICATIONS_RESEND_MCP_COEXISTENCE_POLICY_V1.md"
[[ -f "$POLICY" ]] || fail "MCP coexistence policy missing: $POLICY"

command -v rg >/dev/null 2>&1 || fail "missing command: rg"

if ! rg -q 'send_email.*FORBIDDEN' "$POLICY" 2>/dev/null; then
  fail "MCP coexistence policy does not classify send_email as FORBIDDEN"
fi
if ! rg -q 'batch_send_emails.*FORBIDDEN' "$POLICY" 2>/dev/null; then
  fail "MCP coexistence policy does not classify batch_send_emails as FORBIDDEN"
fi

# Check 3: Provider contract still routes through spine
PROVIDERS="$ROOT/ops/bindings/communications.providers.contract.yaml"
[[ -f "$PROVIDERS" ]] || fail "provider contract missing: $PROVIDERS"

resend_status=$(yq e '.providers.resend.status' "$PROVIDERS" 2>/dev/null)
[[ "$resend_status" == "active" ]] || fail "providers.resend.status must be 'active' (actual=$resend_status)"

canonical_provider=$(yq e '.transactional.customer_notifications_canonical_provider' "$PROVIDERS" 2>/dev/null)
[[ "$canonical_provider" == "resend" ]] || fail "customer_notifications_canonical_provider must be 'resend' (actual=$canonical_provider)"

# Check 4: D147 gate script still exists (defense in depth)
D147_SCRIPT="$ROOT/surfaces/verify/d147-communications-canonical-routing-lock.sh"
[[ -f "$D147_SCRIPT" ]] || fail "D147 gate script missing (defense in depth requires canonical routing lock)"

echo "D257 PASS: transactional send authority lock valid (owner=spine, enforcement=strict, send_email=FORBIDDEN, provider=active)"

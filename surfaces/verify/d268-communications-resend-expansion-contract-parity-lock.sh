#!/usr/bin/env bash
# TRIAGE: Resend expansion contract and MCP coexistence policy must exist and be internally consistent.
# D262: communications-resend-expansion-contract-parity-lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

fail() {
  echo "D262 FAIL: $*" >&2
  exit 1
}

command -v yq >/dev/null 2>&1 || fail "missing command: yq"
command -v rg >/dev/null 2>&1 || fail "missing command: rg"

violations=0
fail_v() {
  echo "  VIOLATION: $*" >&2
  violations=$((violations + 1))
}

CONTRACT="$ROOT/docs/canonical/COMMUNICATIONS_RESEND_EXPANSION_CONTRACT_V1.yaml"
POLICY="$ROOT/docs/canonical/COMMUNICATIONS_RESEND_MCP_COEXISTENCE_POLICY_V1.md"
PROVIDERS="$ROOT/ops/bindings/communications.providers.contract.yaml"

# Check 1: Both files exist
[[ -f "$CONTRACT" ]] || fail_v "expansion contract missing: $CONTRACT"
[[ -f "$POLICY" ]] || fail_v "MCP coexistence policy missing: $POLICY"
[[ -f "$PROVIDERS" ]] || fail_v "provider contract missing: $PROVIDERS"

# Stop early if core files missing
[[ $violations -gt 0 ]] && { echo "D262 FAIL: $violations file(s) missing" >&2; exit 1; }

# Check 2: Contract has all required sections
for section in transactional_send_authority mcp_coexistence inbound contacts broadcasts n8n_bypass gaps; do
  val=$(yq e ".$section" "$CONTRACT" 2>/dev/null)
  [[ -n "$val" && "$val" != "null" ]] || fail_v "contract missing required section: $section"
done

# Check 3: Policy references correct gate IDs
for gate_id in D257 D262; do
  if ! rg -q "$gate_id" "$POLICY" 2>/dev/null; then
    fail_v "policy does not reference gate $gate_id"
  fi
done

# Check 4: Contract send authority agrees with provider contract
contract_owner=$(yq e '.transactional_send_authority.owner' "$CONTRACT" 2>/dev/null)
provider_canonical=$(yq e '.transactional.customer_notifications_canonical_provider' "$PROVIDERS" 2>/dev/null)

[[ "$contract_owner" == "spine" ]] || fail_v "contract send authority owner must be 'spine'"
[[ "$provider_canonical" == "resend" ]] || fail_v "provider canonical must be 'resend'"

# Check 5: Gap count in contract matches expected
gap_count=$(yq e '.gaps | length' "$CONTRACT" 2>/dev/null)
[[ "$gap_count" =~ ^[0-9]+$ && "$gap_count" -ge 6 ]] || fail_v "contract must reference at least 6 gaps (actual=$gap_count)"

# Check 6: Policy classifies forbidden tools
for tool in send_email batch_send_emails send_broadcast; do
  if ! rg -q "${tool}.*FORBIDDEN" "$POLICY" 2>/dev/null; then
    fail_v "policy does not classify $tool as FORBIDDEN"
  fi
done

if [[ $violations -gt 0 ]]; then
  echo "D262 FAIL: expansion contract parity lock: $violations violation(s)" >&2
  exit 1
fi

echo "D262 PASS: expansion contract parity lock valid (sections=7, gaps=$gap_count, forbidden_tools=3)"

#!/usr/bin/env bash
# TRIAGE: Contacts lifecycle governance must require manual approval, rate guards, and suppression enforcement before any contact mutations are enabled.
# D259: communications-contacts-governance-lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

fail() {
  echo "D259 FAIL: $*" >&2
  exit 1
}

command -v yq >/dev/null 2>&1 || fail "missing command: yq"
command -v rg >/dev/null 2>&1 || fail "missing command: rg"

CONTRACT="$ROOT/docs/canonical/COMMUNICATIONS_RESEND_EXPANSION_CONTRACT_V1.yaml"
[[ -f "$CONTRACT" ]] || fail "expansion contract missing: $CONTRACT"

violations=0
fail_v() {
  echo "  VIOLATION: $*" >&2
  violations=$((violations + 1))
}

# Check 1: contacts section exists
contacts_status=$(yq e '.contacts.status' "$CONTRACT" 2>/dev/null)
[[ -n "$contacts_status" && "$contacts_status" != "null" ]] || fail_v "contacts.status must be defined"

# Check 2: safety requirements include manual approval
req_count=$(yq e '.contacts.safety_requirements | length' "$CONTRACT" 2>/dev/null)
[[ "$req_count" =~ ^[0-9]+$ && "$req_count" -ge 3 ]] || fail_v "contacts must have at least 3 safety requirements"

# Check required safety controls
has_approval=false
has_rate_guard=false
has_suppression=false

while IFS= read -r req; do
  case "$req" in
    *"manual approval"*) has_approval=true ;;
    *"rate guard"*|*"max"*"batch"*) has_rate_guard=true ;;
    *"uppression"*) has_suppression=true ;;
  esac
done < <(yq e '.contacts.safety_requirements[]' "$CONTRACT" 2>/dev/null)

[[ "$has_approval" == "true" ]] || fail_v "contacts safety must require manual approval"
[[ "$has_rate_guard" == "true" ]] || fail_v "contacts safety must include rate guard"
[[ "$has_suppression" == "true" ]] || fail_v "contacts safety must enforce suppression list"

# Check 3: Gap reference exists
gap_ref=$(yq e '.contacts.gap' "$CONTRACT" 2>/dev/null)
[[ -n "$gap_ref" && "$gap_ref" != "null" ]] || fail_v "contacts.gap reference must be set"

# Check 4: MCP coexistence policy classifies contact mutations as governed
POLICY="$ROOT/docs/canonical/COMMUNICATIONS_RESEND_MCP_COEXISTENCE_POLICY_V1.md"
if [[ -f "$POLICY" ]]; then
  if ! rg -q 'create_contact.*manual approval' "$POLICY" 2>/dev/null; then
    fail_v "MCP coexistence policy must classify create_contact as requiring manual approval"
  fi
fi

if [[ $violations -gt 0 ]]; then
  echo "D259 FAIL: contacts governance lock: $violations violation(s)" >&2
  exit 1
fi

echo "D259 PASS: contacts governance lock valid (status=$contacts_status, safety_reqs=$req_count, gap=$gap_ref)"

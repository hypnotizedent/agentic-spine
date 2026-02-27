#!/usr/bin/env bash
# TRIAGE: Broadcast campaign governance must require manual approval, rate guards, budget limits, and suppression enforcement before any broadcast sends are enabled.
# D271: communications-broadcast-governance-lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

fail() {
  echo "D271 FAIL: $*" >&2
  exit 1
}

command -v yq >/dev/null 2>&1 || fail "missing command: yq"

CONTRACT="$ROOT/docs/CANONICAL/COMMUNICATIONS_RESEND_EXPANSION_CONTRACT_V1.yaml"
[[ -f "$CONTRACT" ]] || fail "expansion contract missing: $CONTRACT"

violations=0
fail_v() {
  echo "  VIOLATION: $*" >&2
  violations=$((violations + 1))
}

# Check 1: broadcasts section exists
broadcast_status=$(yq e '.broadcasts.status' "$CONTRACT" 2>/dev/null)
[[ -n "$broadcast_status" && "$broadcast_status" != "null" ]] || fail_v "broadcasts.status must be defined"

# Check 2: safety requirements include critical controls
req_count=$(yq e '.broadcasts.safety_requirements | length' "$CONTRACT" 2>/dev/null)
[[ "$req_count" =~ ^[0-9]+$ && "$req_count" -ge 5 ]] || fail_v "broadcasts must have at least 5 safety requirements"

has_send_approval=false
has_rate_guard=false
has_budget_guard=false
has_suppression=false
has_unsubscribe=false

while IFS= read -r req; do
  case "$req" in
    *"send requires"*"manual approval"*) has_send_approval=true ;;
    *"[Rr]ate guard"*|*"max"*"per hour"*|*"per day"*) has_rate_guard=true ;;
    *"[Bb]udget guard"*|*"max"*"recipients"*) has_budget_guard=true ;;
    *"uppression"*) has_suppression=true ;;
    *"unsubscribe"*) has_unsubscribe=true ;;
  esac
done < <(yq e '.broadcasts.safety_requirements[]' "$CONTRACT" 2>/dev/null)

[[ "$has_send_approval" == "true" ]] || fail_v "broadcast safety must require manual approval for sends"
[[ "$has_rate_guard" == "true" ]] || fail_v "broadcast safety must include rate guard"
[[ "$has_budget_guard" == "true" ]] || fail_v "broadcast safety must include budget guard"
[[ "$has_suppression" == "true" ]] || fail_v "broadcast safety must enforce suppression list"
[[ "$has_unsubscribe" == "true" ]] || fail_v "broadcast safety must require unsubscribe link"

# Check 3: MCP coexistence policy classifies broadcast sends as forbidden
POLICY="$ROOT/docs/CANONICAL/COMMUNICATIONS_RESEND_MCP_COEXISTENCE_POLICY_V1.md"
if [[ -f "$POLICY" ]]; then
  if ! rg -q 'send_broadcast.*FORBIDDEN' "$POLICY" 2>/dev/null; then
    fail_v "MCP coexistence policy must classify send_broadcast as FORBIDDEN"
  fi
fi

# Check 4: Gap reference exists
gap_ref=$(yq e '.broadcasts.gap' "$CONTRACT" 2>/dev/null)
[[ -n "$gap_ref" && "$gap_ref" != "null" ]] || fail_v "broadcasts.gap reference must be set"

if [[ $violations -gt 0 ]]; then
  echo "D271 FAIL: broadcast governance lock: $violations violation(s)" >&2
  exit 1
fi

echo "D271 PASS: broadcast governance lock valid (status=$broadcast_status, safety_reqs=$req_count, gap=$gap_ref)"

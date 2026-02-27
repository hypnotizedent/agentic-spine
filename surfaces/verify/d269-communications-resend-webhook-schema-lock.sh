#!/usr/bin/env bash
# TRIAGE: Resend webhook event schema requirements must be documented in expansion contract before any webhook ingest surface is wired.
# D269: communications-resend-webhook-schema-lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

fail() {
  echo "D269 FAIL: $*" >&2
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

# Check 1: inbound section exists with status
inbound_status=$(yq e '.inbound.status' "$CONTRACT" 2>/dev/null)
[[ -n "$inbound_status" && "$inbound_status" != "null" ]] || fail_v "inbound.status must be defined"

# Check 2: webhook_events list is non-empty
event_count=$(yq e '.inbound.webhook_events | length' "$CONTRACT" 2>/dev/null)
[[ "$event_count" =~ ^[0-9]+$ && "$event_count" -gt 0 ]] || fail_v "inbound.webhook_events must have at least one event type"

# Check 3: Required webhook events are present
for event in "email.sent" "email.delivered" "email.bounced" "email.complained"; do
  found=$(yq e ".inbound.webhook_events[] | select(. == \"$event\")" "$CONTRACT" 2>/dev/null)
  [[ -n "$found" ]] || fail_v "missing required webhook event: $event"
done

# Check 4: webhook_schema_requirements is non-empty
req_count=$(yq e '.inbound.webhook_schema_requirements | length' "$CONTRACT" 2>/dev/null)
[[ "$req_count" =~ ^[0-9]+$ && "$req_count" -gt 0 ]] || fail_v "inbound.webhook_schema_requirements must have at least one requirement"

# Check 5: Gap reference exists
gap_ref=$(yq e '.inbound.gap' "$CONTRACT" 2>/dev/null)
[[ -n "$gap_ref" && "$gap_ref" != "null" ]] || fail_v "inbound.gap reference must be set"

if [[ $violations -gt 0 ]]; then
  echo "D269 FAIL: webhook schema lock: $violations violation(s)" >&2
  exit 1
fi

echo "D269 PASS: webhook schema lock valid (events=$event_count, requirements=$req_count, gap=$gap_ref)"

#!/usr/bin/env bash
# Test: dispatch coordination truth (envelope + admission + receipt linkage)
# Validates dispatch.envelope.contract.yaml and related contract extensions

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../../" && pwd)"
cd "$ROOT"

echo "TEST: dispatch coordination truth"

# Test 1: dispatch.envelope.contract.yaml exists and is well-formed
echo "  - checking dispatch.envelope.contract.yaml..."
DISPATCH_CONTRACT="ops/bindings/dispatch.envelope.contract.yaml"
if [[ ! -f "$DISPATCH_CONTRACT" ]]; then
    echo "FAIL: $DISPATCH_CONTRACT not found"
    exit 1
fi
if ! yq eval '.status' "$DISPATCH_CONTRACT" | grep -q "authoritative"; then
    echo "FAIL: dispatch.envelope.contract.yaml status is not authoritative"
    exit 1
fi
echo "    PASS: dispatch.envelope.contract.yaml exists and is authoritative"

# Test 2: Required transport modes defined
echo "  - checking transport modes..."
transport_modes=$(yq eval '.transport_modes | keys | .[]' "$DISPATCH_CONTRACT" 2>/dev/null | paste -sd, -)
if ! echo "$transport_modes" | grep -q "operator_relay"; then
    echo "FAIL: transport_mode operator_relay not defined"
    exit 1
fi
if ! echo "$transport_modes" | grep -q "mailroom"; then
    echo "FAIL: transport_mode mailroom not defined"
    exit 1
fi
echo "    PASS: transport modes include operator_relay and mailroom"

# Test 3: session.admission.contract.yaml has work_admission_rules
echo "  - checking session.admission.contract.yaml extensions..."
ADMISSION_CONTRACT="ops/bindings/session.admission.contract.yaml"
if ! yq eval '.work_admission_rules' "$ADMISSION_CONTRACT" >/dev/null 2>&1; then
    echo "FAIL: work_admission_rules section missing from session.admission.contract.yaml"
    exit 1
fi
if ! yq eval '.rejection_semantics' "$ADMISSION_CONTRACT" >/dev/null 2>&1; then
    echo "FAIL: rejection_semantics section missing from session.admission.contract.yaml"
    exit 1
fi
echo "    PASS: session.admission.contract.yaml has work_admission_rules and rejection_semantics"

# Test 4: role.runtime.control.contract.yaml has delegated_receipt_linkage
echo "  - checking role.runtime.control.contract.yaml extensions..."
ROLE_CONTRACT="ops/bindings/role.runtime.control.contract.yaml"
if ! yq eval '.delegated_receipt_linkage' "$ROLE_CONTRACT" >/dev/null 2>&1; then
    echo "FAIL: delegated_receipt_linkage section missing from role.runtime.control.contract.yaml"
    exit 1
fi
if ! yq eval '.completion_determination' "$ROLE_CONTRACT" >/dev/null 2>&1; then
    echo "FAIL: completion_determination section missing from role.runtime.control.contract.yaml"
    exit 1
fi
if ! yq eval '.receipt_aggregation' "$ROLE_CONTRACT" >/dev/null 2>&1; then
    echo "FAIL: receipt_aggregation section missing from role.runtime.control.contract.yaml"
    exit 1
fi
echo "    PASS: role.runtime.control.contract.yaml has delegated_receipt_linkage, completion_determination, and receipt_aggregation"

# Test 5: Routing lanes defined in dispatch contract match session.admission lanes
echo "  - checking routing lane consistency..."
dispatch_lanes=$(yq eval '.routing.by_lane | keys | .[]' "$DISPATCH_CONTRACT" 2>/dev/null | sort | paste -sd, -)
admission_lanes=$(yq eval '.work_admission_rules.by_logical_lane | keys | .[]' "$ADMISSION_CONTRACT" 2>/dev/null | sort | paste -sd, -)
if [[ "$dispatch_lanes" != "$admission_lanes" ]]; then
    echo "FAIL: routing lanes mismatch between dispatch ($dispatch_lanes) and admission ($admission_lanes)"
    exit 1
fi
echo "    PASS: routing lanes consistent across contracts"

# Test 6: communication.protocol.contract.yaml references dispatch.envelope.contract.yaml
echo "  - checking communication.protocol.contract.yaml reference..."
COMM_CONTRACT="ops/bindings/communication.protocol.contract.yaml"
if ! grep -q "dispatch.envelope.contract.yaml" "$COMM_CONTRACT"; then
    echo "FAIL: communication.protocol.contract.yaml does not reference dispatch.envelope.contract.yaml"
    exit 1
fi
echo "    PASS: communication.protocol.contract.yaml references dispatch.envelope.contract.yaml"

# Test 7: Envelope schema has required fields
echo "  - checking envelope schema completeness..."
required_fields="envelope_id sender_node target_node work_scope transport_mode receipt_expectation created_at_utc"
for field in $required_fields; do
    if ! yq eval ".envelope_schema.required_fields | has(\"$field\")" "$DISPATCH_CONTRACT" | grep -q "true"; then
        echo "FAIL: envelope_schema missing required field: $field"
        exit 1
    fi
done
echo "    PASS: envelope schema has all required fields"

# Test 8: Completion states defined
echo "  - checking completion states..."
completion_states="complete awaiting_delegated_receipt blocked_delegated timeout_delegated"
for state in $completion_states; do
    if ! yq eval ".completion_determination.completion_states | has(\"$state\")" "$ROLE_CONTRACT" | grep -q "true"; then
        echo "FAIL: completion_determination missing state: $state"
        exit 1
    fi
done
echo "    PASS: all completion states defined"

echo "PASS: dispatch coordination truth"

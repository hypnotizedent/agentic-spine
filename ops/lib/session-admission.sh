#!/usr/bin/env bash
# session-admission.sh — resolve lane admission data from session.admission.contract.yaml
#
# Usage:
#   source ops/lib/session-admission.sh
#   spine_resolve_admission "claude_code"
#   # Sets: SA_GOVERNANCE_PROFILE, SA_ADMISSION_DELIVERY, SA_MUTATION_POSTURE,
#   #       SA_PARITY_STATUS, SA_ATTACH_REQUIRED, SA_RUNTIME_CONTEXT_DELIVERY,
#   #       SA_TERMINAL_IDENTITY_DELIVERY, SA_RECEIPT_REQUIREMENT
#
# Falls back to safe degraded values if resolution fails.

spine_resolve_admission() {
  local lane="${1:-}"
  local contract="${SPINE_SESSION_ADMISSION_CONTRACT:-${SPINE_ROOT:-.}/ops/bindings/session.admission.contract.yaml}"

  # Safe defaults (degraded posture)
  SA_GOVERNANCE_PROFILE="lightweight_degraded"
  SA_ADMISSION_DELIVERY="none"
  SA_MUTATION_POSTURE="no_governed_mutation"
  SA_PARITY_STATUS="degraded"
  SA_ATTACH_REQUIRED="false"
  SA_RUNTIME_CONTEXT_DELIVERY="none"
  SA_TERMINAL_IDENTITY_DELIVERY="none"
  SA_RECEIPT_REQUIREMENT="handoff_only"

  if [[ -z "$lane" ]]; then
    return 1
  fi

  if ! command -v yq >/dev/null 2>&1; then
    return 1
  fi

  if [[ ! -r "$contract" ]]; then
    return 1
  fi

  local resolved
  resolved="$(yq e -r ".lanes.\"${lane}\".governance_profile // \"\"" "$contract" 2>/dev/null || true)"
  if [[ -z "$resolved" || "$resolved" == "null" ]]; then
    return 1
  fi

  SA_GOVERNANCE_PROFILE="$resolved"
  SA_ADMISSION_DELIVERY="$(yq e -r ".lanes.\"${lane}\".admission_delivery // \"none\"" "$contract" 2>/dev/null || echo "none")"
  SA_MUTATION_POSTURE="$(yq e -r ".lanes.\"${lane}\".mutation_posture // \"no_governed_mutation\"" "$contract" 2>/dev/null || echo "no_governed_mutation")"
  SA_PARITY_STATUS="$(yq e -r ".lanes.\"${lane}\".parity_status // \"degraded\"" "$contract" 2>/dev/null || echo "degraded")"
  SA_ATTACH_REQUIRED="$(yq e -r ".lanes.\"${lane}\".attach_required // false" "$contract" 2>/dev/null || echo "false")"
  SA_RUNTIME_CONTEXT_DELIVERY="$(yq e -r ".lanes.\"${lane}\".runtime_context_delivery // \"none\"" "$contract" 2>/dev/null || echo "none")"
  SA_TERMINAL_IDENTITY_DELIVERY="$(yq e -r ".lanes.\"${lane}\".terminal_identity_delivery // \"none\"" "$contract" 2>/dev/null || echo "none")"
  SA_RECEIPT_REQUIREMENT="$(yq e -r ".lanes.\"${lane}\".receipt_requirement // \"handoff_only\"" "$contract" 2>/dev/null || echo "handoff_only")"

  return 0
}

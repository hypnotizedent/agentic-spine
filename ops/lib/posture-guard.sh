#!/usr/bin/env bash
set -euo pipefail

# Minimal execution-posture guard used by lifecycle mutation entrypoints.
# Authority: ops/bindings/execution.posture.contract.yaml

POSTURE_CONTRACT_DEFAULT="/Users/ronnyworks/code/agentic-spine/ops/bindings/execution.posture.contract.yaml"

_posture_contract_path() {
  local root="${1:-}"
  if [[ -n "$root" && -f "$root/ops/bindings/execution.posture.contract.yaml" ]]; then
    printf '%s\n' "$root/ops/bindings/execution.posture.contract.yaml"
    return 0
  fi
  printf '%s\n' "$POSTURE_CONTRACT_DEFAULT"
}

posture_guard_current_posture() {
  local contract
  contract="$(_posture_contract_path "${SPINE_REPO:-}")"
  local default_posture="discover"
  if command -v yq >/dev/null 2>&1 && [[ -f "$contract" ]]; then
    default_posture="$(yq e -r '.defaults.posture // "discover"' "$contract" 2>/dev/null || echo discover)"
  fi
  printf '%s\n' "${SPINE_EXECUTION_POSTURE:-$default_posture}"
}

posture_guard_reject_growth() {
  local capability="${1:-mutation}"
  local posture
  posture="$(posture_guard_current_posture)"
  [[ "$posture" == "converge" ]] || return 0

  local reason="${SPINE_POSTURE_OVERRIDE_REASON:-}"
  if [[ -n "$reason" ]]; then
    echo "WARN: posture override for $capability under converge posture: $reason" >&2
    return 0
  fi

  local contract
  contract="$(_posture_contract_path "${SPINE_REPO:-}")"
  local message="POSTURE BLOCKED: Active execution posture is 'converge'. Registry growth is denied."
  local exit_code="1"
  if command -v yq >/dev/null 2>&1 && [[ -f "$contract" ]]; then
    message="$(yq e -r '.mutation_policy.converge.rejection.message // ""' "$contract" 2>/dev/null || echo "$message")"
    [[ -n "$message" && "$message" != "null" ]] || message="POSTURE BLOCKED: Active execution posture is 'converge'. Registry growth is denied."
    exit_code="$(yq e -r '.mutation_policy.converge.rejection.exit_code // 1' "$contract" 2>/dev/null || echo 1)"
  fi

  echo "$message" >&2
  exit "${exit_code:-1}"
}

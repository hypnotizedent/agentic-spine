#!/usr/bin/env bash
# Enforce workbench proposal preflight operator surface and dry-run forwarding.
set -euo pipefail

PREFLIGHT_SCRIPT="/Users/ronnyworks/code/workbench/scripts/root/operator/proposals-preflight.sh"
RAYCAST_WRAPPER="/Users/ronnyworks/code/workbench/dotfiles/raycast/spine-proposals-preflight.sh"

declare -a VIOLATIONS=()

record_violation() {
  local path="$1"
  local rule="$2"
  local hint="$3"
  VIOLATIONS+=("${path} :: ${rule} :: ${hint}")
}

check_exists_and_executable() {
  local path="$1"
  local rule="$2"
  if [[ ! -f "$path" ]]; then
    record_violation "$path" "$rule" "file is missing"
    return
  fi
  if [[ ! -x "$path" ]]; then
    record_violation "$path" "$rule" "file must be executable"
  fi
}

check_contains_literal() {
  local path="$1"
  local needle="$2"
  local rule="$3"
  if ! rg -F -q -- "$needle" "$path"; then
    record_violation "$path" "$rule" "missing required content: $needle"
  fi
}

check_exists_and_executable "$PREFLIGHT_SCRIPT" "preflight_script_exists_executable"
if [[ -f "$PREFLIGHT_SCRIPT" ]]; then
  check_contains_literal "$PREFLIGHT_SCRIPT" "verify.pack.run workbench" "contains_verify_pack_workbench"
  check_contains_literal "$PREFLIGHT_SCRIPT" "verify.core.run" "contains_verify_core"
  check_contains_literal "$PREFLIGHT_SCRIPT" "proposals.status" "contains_proposals_status"
  check_contains_literal "$PREFLIGHT_SCRIPT" "--proposal" "supports_proposal_argument"
  check_contains_literal "$PREFLIGHT_SCRIPT" "proposals-apply" "contains_proposals_apply_forwarding"
  check_contains_literal "$PREFLIGHT_SCRIPT" "--dry-run" "contains_proposals_apply_dry_run_forwarding"
fi

check_exists_and_executable "$RAYCAST_WRAPPER" "raycast_wrapper_exists_executable"
if [[ -f "$RAYCAST_WRAPPER" ]]; then
  check_contains_literal "$RAYCAST_WRAPPER" "$PREFLIGHT_SCRIPT" "wrapper_delegates_to_preflight_script"
  check_contains_literal "$RAYCAST_WRAPPER" "--proposal" "wrapper_supports_proposal_forwarding"
fi

if [[ "${#VIOLATIONS[@]}" -gt 0 ]]; then
  for violation in "${VIOLATIONS[@]}"; do
    echo "D170 FAIL: ${violation}" >&2
  done
  echo "D170 FAIL: workbench proposal preflight enforcement violated (${#VIOLATIONS[@]} finding(s))" >&2
  exit 1
fi

echo "D170 PASS: workbench proposal preflight surfaces enforced"

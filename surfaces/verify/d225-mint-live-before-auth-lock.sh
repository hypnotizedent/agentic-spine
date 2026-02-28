#!/usr/bin/env bash
# TRIAGE: Align mint runtime claim-state docs with lifecycle registry before rerun.
# D225: Keep mint live baseline gate semantics valid across auth lifecycle modes.
# D225: mint-live-before-auth-lock
# Enforce "live modules first" sequencing:
# - mode A: auth remains deferred with explicit queue block markers
# - mode B: auth extracted complete with EQ-1 completion evidence
# - live module baseline is green
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CONTRACT="$ROOT/ops/bindings/mint.module.sequence.contract.yaml"
STATUS_SURFACE="$ROOT/ops/plugins/mint/bin/mint-live-baseline-status"

fail() {
  echo "D225 FAIL: $*" >&2
  exit 1
}

[[ -f "$CONTRACT" ]] || fail "missing contract: $CONTRACT"
[[ -x "$STATUS_SURFACE" ]] || fail "missing status surface: $STATUS_SURFACE"
command -v yq >/dev/null 2>&1 || fail "missing required dependency: yq"
command -v rg >/dev/null 2>&1 || fail "missing required dependency: rg"

auth_state="$(yq -r '.auth_module.state // ""' "$CONTRACT")"
blocked_gate="$(yq -r '.auth_module.blocked_by_gate // ""' "$CONTRACT")"
accepted_states="$(yq -r '.auth_module.accepted_states[]? // ""' "$CONTRACT" || true)"
[[ -n "$auth_state" && "$auth_state" != "null" ]] || fail "auth_module.state missing in contract"
[[ "$blocked_gate" == "D225" ]] || fail "auth_module.blocked_by_gate must be D225 (actual=$blocked_gate)"

if [[ -n "$accepted_states" ]]; then
  if ! printf '%s\n' "$accepted_states" | rg -qx "$auth_state"; then
    fail "auth_module.state not allowed by auth_module.accepted_states (state=$auth_state)"
  fi
else
  case "$auth_state" in
    deferred|extracted_complete) ;;
    *) fail "unsupported auth_module.state (actual=$auth_state)" ;;
  esac
fi

queue_file="$(yq -r '.queue_contract.file // ""' "$CONTRACT")"
[[ -n "$queue_file" && "$queue_file" != "null" ]] || fail "queue_contract.file missing in contract"
[[ -f "$queue_file" ]] || fail "queue file not found: $queue_file"

deferred_marker_a="$(yq -r '.auth_module.deferred_markers[0] // .queue_contract.required_markers[0] // "BLOCKED_BY_D225"' "$CONTRACT")"
deferred_marker_b="$(yq -r '.auth_module.deferred_markers[1] // .queue_contract.required_markers[1] // "AUTH_DEFERRED_UNTIL_LIVE_BASELINE"' "$CONTRACT")"
completion_heading="$(yq -r '.auth_module.completion.heading // "### EQ-1: Auth Module"' "$CONTRACT")"
completion_status_pattern="$(yq -r '.auth_module.completion.status_pattern // "Execution status.*COMPLETED"' "$CONTRACT")"

if [[ "$auth_state" == "deferred" ]]; then
  rg -q "$deferred_marker_a" "$queue_file" || fail "deferred mode missing marker: $deferred_marker_a"
  rg -q "$deferred_marker_b" "$queue_file" || fail "deferred mode missing marker: $deferred_marker_b"
elif [[ "$auth_state" == "extracted_complete" ]]; then
  eq1_section="$(awk -v heading="$completion_heading" '
    index($0, heading) {in_section=1}
    in_section {
      if ($0 ~ /^### EQ-[0-9]+:/ && index($0, heading) == 0) exit
      print
    }
  ' "$queue_file")"
  [[ -n "$eq1_section" ]] || fail "extracted_complete mode missing heading: $completion_heading"
  printf '%s\n' "$eq1_section" | rg -q "$completion_status_pattern" || fail "extracted_complete mode missing completion status pattern"
fi

"$STATUS_SURFACE" --strict >/dev/null 2>&1 || fail "mint live baseline status is not green"

if [[ "$auth_state" == "deferred" ]]; then
  echo "D225 PASS: live modules baseline is green and auth remains deferred-by-gate"
else
  echo "D225 PASS: live modules baseline is green and EQ-1 auth extraction is completed"
fi

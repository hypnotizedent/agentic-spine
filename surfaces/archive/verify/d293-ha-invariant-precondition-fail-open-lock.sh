#!/usr/bin/env bash
# TRIAGE: Invariant HA gates must not include report-mode fail-open precondition bypasses.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"

TARGETS=(
  "surfaces/verify/d113-coordinator-health-probe.sh"
  "surfaces/verify/d114-ha-automation-stability.sh"
  "surfaces/verify/d118-z2m-device-health.sh"
  "surfaces/verify/d120-ha-area-parity.sh"
)

FAIL=0
DETAILS=()

for rel in "${TARGETS[@]}"; do
  file="$ROOT/$rel"
  if [[ ! -f "$file" ]]; then
    DETAILS+=("missing:$rel")
    FAIL=1
    continue
  fi

  if rg -n 'HA_GATE_MODE|D11[348] REPORT|D120 REPORT' "$file" >/dev/null 2>&1; then
    DETAILS+=("report-bypass-pattern:$rel")
    FAIL=1
  fi

  pre_fn="$(awk '/^precondition_fail\(\)/,/^}/' "$file")"
  if [[ -z "$pre_fn" ]]; then
    DETAILS+=("missing-precondition_fail:$rel")
    FAIL=1
    continue
  fi
  if printf '%s\n' "$pre_fn" | rg -n 'exit[[:space:]]+0' >/dev/null 2>&1; then
    DETAILS+=("precondition-fail-open:$rel")
    FAIL=1
  fi
  if ! printf '%s\n' "$pre_fn" | rg -n 'exit[[:space:]]+1' >/dev/null 2>&1; then
    DETAILS+=("precondition-missing-exit1:$rel")
    FAIL=1
  fi
done

if [[ "$FAIL" -eq 1 ]]; then
  echo "D293 FAIL: invariant HA precondition fail-open risk detected (${DETAILS[*]})" >&2
  exit 1
fi

echo "D293 PASS: invariant HA precondition fail-open lock enforced (${#TARGETS[@]} scripts verified)"

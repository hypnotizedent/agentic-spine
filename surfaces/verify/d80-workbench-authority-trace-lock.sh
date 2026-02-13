#!/usr/bin/env bash
# D80: Workbench authority-trace lock
# Wrapper gate that runs workbench authority-trace.sh --strict
# as part of spine.verify. Catches legacy naming violations
# (legacy doc refs, old path prefixes, ronny-ops naming) in
# active workbench surfaces.

set -euo pipefail

WORKBENCH_ROOT="${WORKBENCH_ROOT:-/Users/ronnyworks/code/workbench}"
if [[ ! -d "$WORKBENCH_ROOT" ]]; then
  WORKBENCH_ROOT="${HOME}/code/workbench"
fi

fail() {
  echo "D80 FAIL: $*" >&2
  exit 1
}

TRACE_SCRIPT="$WORKBENCH_ROOT/scripts/root/authority-trace.sh"

[[ -d "$WORKBENCH_ROOT" ]] || fail "workbench not found: $WORKBENCH_ROOT"
[[ -x "$TRACE_SCRIPT" ]] || fail "authority-trace.sh not executable: $TRACE_SCRIPT"

# Run authority-trace in strict mode
output="$(bash "$TRACE_SCRIPT" --strict 2>&1)" || {
  echo "$output" >&2
  fail "workbench authority-trace --strict failed"
}

echo "D80 PASS: workbench authority-trace lock enforced"

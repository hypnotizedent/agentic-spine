#!/usr/bin/env bash
# Enforce deterministic operator smoke checks for workbench surfaces.
set -euo pipefail

SMOKE_SCRIPT="/Users/ronnyworks/code/workbench/scripts/root/operator/operator-smoke-suite.sh"

fail() {
  echo "D169 FAIL: $*" >&2
  exit 1
}

if [[ ! -f "$SMOKE_SCRIPT" ]]; then
  fail "missing required smoke suite script: $SMOKE_SCRIPT"
fi

if [[ ! -x "$SMOKE_SCRIPT" ]]; then
  fail "smoke suite script is not executable: $SMOKE_SCRIPT (run: chmod +x \"$SMOKE_SCRIPT\")"
fi

if ! "$SMOKE_SCRIPT"; then
  fail "operator smoke suite failed via $SMOKE_SCRIPT (remediation: run it directly in workbench and fix reported checks)"
fi

echo "D169 PASS: workbench operator smoke suite passed"

#!/usr/bin/env bash
# TRIAGE: Fix domain_external capability implementation paths so they resolve to canonical workbench files.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
AUDIT="$ROOT/ops/plugins/verify/bin/workbench-impl-audit"

fail() {
  echo "D126 FAIL: $*" >&2
  exit 1
}

[[ -x "$AUDIT" ]] || fail "missing executable: $AUDIT"

if ! "$AUDIT" --strict; then
  fail "domain_external implementation path parity failed (run ./bin/ops cap run workbench.impl.audit --list)"
fi

echo "D126 PASS: workbench implementation path lock enforced"

#!/usr/bin/env bash
# TRIAGE: run platform.extension.lint and resolve namespace collisions, missing references, invalid names, or vmid overlaps before rerunning hygiene-weekly.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CONTRACT="$ROOT/ops/bindings/platform.extension.naming.contract.yaml"
LINT_SCRIPT="$ROOT/ops/plugins/authority/bin/platform-extension-lint"

fail() {
  echo "D180 FAIL: $*" >&2
  exit 1
}

[[ -f "$CONTRACT" ]] || fail "missing naming contract: $CONTRACT"
[[ -x "$LINT_SCRIPT" ]] || fail "missing/executable lint script: $LINT_SCRIPT"

if ! report="$($LINT_SCRIPT 2>&1)"; then
  echo "$report" >&2
  fail "platform extension namespace collision lock violations found"
fi

echo "$report"
echo "D180 PASS: platform extension namespace collision lock valid"

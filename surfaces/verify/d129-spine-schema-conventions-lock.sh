#!/usr/bin/env bash
# TRIAGE: Run schema.conventions.audit and resolve disallowed alias keys/status/date drift before merging binding changes.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
AUDIT_BIN="$ROOT/ops/plugins/verify/bin/schema-conventions-audit"

fail() {
  echo "D129 FAIL: $*" >&2
  exit 1
}

[[ -x "$AUDIT_BIN" ]] || fail "missing audit binary: $AUDIT_BIN"

if "$AUDIT_BIN" --mode gate >/dev/null; then
  echo "D129 PASS: spine schema conventions lock enforced"
else
  "$AUDIT_BIN" --mode gate || true
  fail "schema conventions audit failed"
fi

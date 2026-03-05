#!/usr/bin/env bash
# TRIAGE: Run schema.conventions.audit and resolve disallowed alias keys/status/date drift before merging binding changes.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
AUDIT_BIN="$ROOT/ops/plugins/verify/bin/schema-conventions-audit"
# D129_STRICT=1 to fail on any changed file (staged or unstaged). Default: staged-only.
STRICT="${D129_STRICT:-0}"

fail() {
  echo "D129 FAIL: $*" >&2
  exit 1
}

[[ -x "$AUDIT_BIN" ]] || fail "missing audit binary: $AUDIT_BIN"

if [[ "$STRICT" == "1" ]]; then
  # Strict mode: fail on any changed binding file (staged + unstaged)
  if "$AUDIT_BIN" --mode gate >/dev/null; then
    echo "D129 PASS: spine schema conventions lock enforced (strict)"
  else
    "$AUDIT_BIN" --mode gate || true
    fail "schema conventions audit failed (strict mode)"
  fi
else
  # Default mode: fail only on staged violations; advisory for ambient unstaged dirt.
  staged_pass=0
  if "$AUDIT_BIN" --mode staged >/dev/null 2>&1; then
    staged_pass=1
  fi

  gate_pass=0
  if "$AUDIT_BIN" --mode gate >/dev/null 2>&1; then
    gate_pass=1
  fi

  if [[ "$staged_pass" -eq 1 && "$gate_pass" -eq 1 ]]; then
    echo "D129 PASS: spine schema conventions lock enforced"
  elif [[ "$staged_pass" -eq 1 && "$gate_pass" -eq 0 ]]; then
    echo "D129 ADVISORY: unstaged/untracked binding changes have schema violations (not blocking)" >&2
    "$AUDIT_BIN" --mode gate 2>&1 | sed 's/^/  /' >&2 || true
    echo "D129 PASS: spine schema conventions lock enforced (staged clean; ambient drift advisory)"
  else
    "$AUDIT_BIN" --mode staged || true
    fail "schema conventions audit failed (staged violations)"
  fi
fi

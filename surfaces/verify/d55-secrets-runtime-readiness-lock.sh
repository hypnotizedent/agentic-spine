#!/usr/bin/env bash
set -euo pipefail

# D55: Secrets Runtime Readiness Lock (composite)
# Groups secrets readiness checks behind one high-signal STOP.
#
# Subchecks:
#   - D20 secrets surface drift gate (non-leaky + read-only)
#   - D25 secrets CLI canonical lock (canonical helper CLIs exist; advisory parity with workbench)

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

fail() { echo "D55 FAIL: $*" >&2; exit 1; }

subcheck() {
  local id="$1"
  local script="$2"
  local tmp rc
  tmp="$(mktemp)"
  set +e
  bash "$script" >"$tmp" 2>&1
  rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    rm -f "$tmp"
    return 0
  fi

  echo "subcheck ${id}: FAIL (rc=${rc})" >&2
  # Keep output bounded: first 80 lines.
  sed -n '1,80p' "$tmp" >&2 || true
  rm -f "$tmp"
  return 1
}

FAILS=0

subcheck "D20" "$ROOT/surfaces/verify/d20-secrets-drift.sh" || FAILS=$((FAILS+1))
subcheck "D25" "$ROOT/surfaces/verify/d25-secrets-cli-canonical-lock.sh" || FAILS=$((FAILS+1))

(( FAILS == 0 )) || fail "secrets runtime readiness violated (${FAILS} failing subcheck(s))"
exit 0


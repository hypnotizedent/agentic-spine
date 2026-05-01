#!/usr/bin/env bash
set -euo pipefail

# D8: live root hygiene check.
#
# Historical drift-gate.sh used to be a monolithic runner for many retired D
# checks. The live registry now only assigns this script to D8; other D gates
# either own their dedicated script/readback or are retired history.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

FAIL=0

pass() {
  echo "PASS"
}

fail() {
  echo "FAIL $*"
  FAIL=1
}

echo "=== DRIFT GATE (D8 root hygiene) ==="

# D8: No backup clutter (recursive: .bak and fix_bak in live executable surfaces)
CURRENT_GATE="D8"
echo -n "D8 no backup clutter... "
BK="$(find bin ops -type f 2>/dev/null | rg '\.bak$|fix_bak' || true)"
if [[ -z "$BK" ]]; then
  pass
else
  fail "backup files in live surfaces: $(echo "$BK" | tr '\n' ' ')"
fi

if [[ "$FAIL" -eq 0 ]]; then
  echo
  echo "DRIFT GATE: PASS"
  exit 0
fi

echo
echo "DRIFT GATE: FAIL"
exit 1

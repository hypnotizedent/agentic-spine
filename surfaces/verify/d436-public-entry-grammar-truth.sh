#!/usr/bin/env bash
# TRIAGE: bin/ops help text must teach ops terminal launch as Operator front door (Entry),
#         and session.v3.attach must NOT appear as Entry in that section.
set -euo pipefail

SPINE_CODE="${SPINE_CODE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
OPS_BIN="$SPINE_CODE/bin/ops"

fail() { echo "D436 FAIL: $*" >&2; exit 1; }

[[ -f "$OPS_BIN" ]] || fail "bin/ops not found at $OPS_BIN"

# terminal launch must be taught as Entry under Operator front door
if ! grep -q 'ops terminal launch.*Entry' "$OPS_BIN"; then
  fail "bin/ops does not teach 'ops terminal launch' as Entry under Operator front door"
fi

# session.v3.attach must NOT be taught as Entry (it is orientation, not admission)
if grep -q 'session\.v3\.attach.*Entry' "$OPS_BIN"; then
  fail "bin/ops still teaches session.v3.attach as Entry — it should be orientation only"
fi

echo "D436 PASS: public entry grammar is truthful (terminal launch = Entry, session.v3.attach = orientation)"
exit 0

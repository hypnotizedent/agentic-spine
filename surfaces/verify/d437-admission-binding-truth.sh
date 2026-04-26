#!/usr/bin/env bash
# TRIAGE: session-v3-attach must check OPS_TERMINAL_ROLE and emit ADMITTED vs UNBOUND
#         admission status. The header must describe it as orientation, NOT admission.
set -euo pipefail

SPINE_CODE="${SPINE_CODE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
ATTACH_SCRIPT="$SPINE_CODE/ops/plugins/core/lifecycle/bin/session-v3-attach"

fail() { echo "D437 FAIL: $*" >&2; exit 1; }

[[ -f "$ATTACH_SCRIPT" ]] || fail "session-v3-attach not found"

# Must check admission status based on OPS_TERMINAL_ROLE
if ! grep -q 'ADMISSION_STATUS.*unbound' "$ATTACH_SCRIPT"; then
  fail "session-v3-attach does not check admission status (missing ADMISSION_STATUS)"
fi

# Header must say NOT admission
if ! grep -q 'NOT admission' "$ATTACH_SCRIPT"; then
  fail "session-v3-attach header does not clarify it is NOT admission"
fi

# Must emit UNBOUND status when standalone
if ! grep -q 'UNBOUND' "$ATTACH_SCRIPT"; then
  fail "session-v3-attach does not emit UNBOUND status for standalone invocation"
fi

echo "D437 PASS: admission binding truth is explicit (ADMITTED vs UNBOUND, header says NOT admission)"
exit 0

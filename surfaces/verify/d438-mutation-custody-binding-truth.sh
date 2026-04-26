#!/usr/bin/env bash
# TRIAGE: cap.sh must block mutating capabilities when OPS_TERMINAL_ROLE is unset
#         (no bound terminal identity). The block reason is unbound_terminal_identity.
set -euo pipefail

SPINE_CODE="${SPINE_CODE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CAP_SH="$SPINE_CODE/ops/commands/cap.sh"

fail() { echo "D438 FAIL: $*" >&2; exit 1; }

[[ -f "$CAP_SH" ]] || fail "cap.sh not found"

# Must have the unbound terminal identity check
if ! grep -q 'unbound_terminal_identity' "$CAP_SH"; then
  fail "cap.sh does not enforce unbound_terminal_identity gate for mutation"
fi

# Must check OPS_TERMINAL_ROLE specifically
if ! grep -q 'OPS_TERMINAL_ROLE' "$CAP_SH"; then
  fail "cap.sh does not check OPS_TERMINAL_ROLE for mutation custody"
fi

echo "D438 PASS: mutation requires bound terminal identity (unbound_terminal_identity gate present)"
exit 0

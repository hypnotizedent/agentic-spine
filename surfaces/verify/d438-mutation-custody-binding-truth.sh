#!/usr/bin/env bash
# TRIAGE: cap.sh must block mutating capabilities when canonical terminal identity is unset
#         (no bound terminal identity). The block reason is unbound_terminal_identity.
set -euo pipefail

SPINE_CODE="${SPINE_CODE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CAP_SH="$SPINE_CODE/ops/commands/cap.sh"
PRE_PUSH_HOOK="$SPINE_CODE/.githooks/pre-push"

fail() { echo "D438 FAIL: $*" >&2; exit 1; }

[[ -f "$CAP_SH" ]] || fail "cap.sh not found"
[[ -f "$PRE_PUSH_HOOK" ]] || fail "pre-push hook not found"

# Must have the unbound terminal identity check
if ! grep -q 'unbound_terminal_identity' "$CAP_SH"; then
  fail "cap.sh does not enforce unbound_terminal_identity gate for mutation"
fi

# Must check canonical terminal identity or compatibility aliases
if ! grep -Eq 'SPINE_TERMINAL_ID|OPS_TERMINAL_ID|OPS_TERMINAL_ROLE' "$CAP_SH"; then
  fail "cap.sh does not check canonical terminal identity for mutation custody"
fi

if ! grep -q 'direct git push requires governed terminal admission' "$PRE_PUSH_HOOK"; then
  fail "pre-push hook does not refuse unadmitted direct git push"
fi

if ! "$PRE_PUSH_HOOK" --self-check >/dev/null 2>&1; then
  fail "pre-push hook self-check failed"
fi

echo "D438 PASS: mutation requires bound terminal identity (cap gate + direct git push hook present)"
exit 0

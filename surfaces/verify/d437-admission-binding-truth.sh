#!/usr/bin/env bash
# TRIAGE: session-v3-attach must check canonical terminal identity and emit ADMITTED vs UNBOUND
#         admission status. The header must describe it as orientation, NOT admission.
set -euo pipefail

SPINE_CODE="${SPINE_CODE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
ATTACH_SCRIPT="$SPINE_CODE/ops/plugins/core/lifecycle/bin/session-v3-attach"
OPS_BIN="$SPINE_CODE/bin/ops"

fail() { echo "D437 FAIL: $*" >&2; exit 1; }

[[ -f "$ATTACH_SCRIPT" ]] || fail "session-v3-attach not found"
[[ -x "$OPS_BIN" ]] || fail "bin/ops not executable"

# Must check admission status based on canonical terminal identity / aliases
if ! grep -q 'ADMISSION_STATUS.*unbound' "$ATTACH_SCRIPT"; then
  fail "session-v3-attach does not check admission status (missing ADMISSION_STATUS)"
fi

if ! grep -Eq 'SPINE_TERMINAL_ID|OPS_TERMINAL_ID|OPS_TERMINAL_ROLE' "$ATTACH_SCRIPT"; then
  fail "session-v3-attach does not resolve canonical terminal identity"
fi

# Header must say NOT admission
if ! grep -q 'NOT admission' "$ATTACH_SCRIPT"; then
  fail "session-v3-attach header does not clarify it is NOT admission"
fi

# Must emit UNBOUND status when standalone
if ! grep -q 'UNBOUND' "$ATTACH_SCRIPT"; then
  fail "session-v3-attach does not emit UNBOUND status for standalone invocation"
fi

set +e
main_launch_output="$("$OPS_BIN" terminal launch --role solo --tool claude --terminal SPINE-CONTROL-01 --dry-run 2>&1)"
main_launch_rc=$?
set -e

if [[ "$main_launch_rc" -ne 0 ]]; then
  fail "first-class terminal launch was blocked: $main_launch_output"
fi

if [[ "$main_launch_output" != *"# Launch cwd: $SPINE_CODE"* ]]; then
  fail "terminal launch no longer births on the canonical primary checkout"
fi

if [[ "$main_launch_output" == *"worktree"* && "$main_launch_output" != *"SPINE_WORKTREE"* && "$main_launch_output" != *".runtime/spine/tmp/worktrees/"* ]]; then
  fail "terminal launch emitted ambiguous worktree routing text"
fi

echo "D437 PASS: admission binding truth is explicit and first-class terminal entry is not blocked"
exit 0

#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
TOOLS_PY="$ROOT/../workbench/agents/microsoft/tools/microsoft_tools.py"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

[[ -f "$TOOLS_PY" ]] || fail "missing microsoft tools script"

set +e
err_out="$("$ROOT/ops/plugins/providers/microsoft/bin/microsoft-cap-exec" draft_send --mailbox team@mintprints.com --message-id DRAFT-123 2>&1)"
rc=$?
set -e

[[ "$rc" -eq 2 ]] || fail "draft_send should be blocked by policy"
echo "$err_out" | grep -F "Drafts only" >/dev/null || fail "draft_send block should explain drafts-only policy"
pass "microsoft draft_send is blocked by policy"

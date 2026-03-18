#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

set +e
err_out="$("$ROOT/ops/plugins/providers/microsoft/bin/microsoft-cap-exec" mail_forward --mailbox team@mintprints.com --message-id MSG-123 --to team@mintprints.com 2>&1)"
rc=$?
set -e

[[ "$rc" -eq 2 ]] || fail "mail_forward should be blocked by policy"
echo "$err_out" | grep -F "Drafts only" >/dev/null || fail "mail_forward block should explain the drafts-only policy"
pass "microsoft mail_forward is blocked by policy"

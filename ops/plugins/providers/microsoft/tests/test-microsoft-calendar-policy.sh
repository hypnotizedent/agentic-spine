#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

set +e
err_out="$("$ROOT/ops/plugins/providers/microsoft/bin/microsoft-cap-exec" calendar_create --subject Test --body Body --start 2026-03-18T10:00:00 --end 2026-03-18T11:00:00 --timezone America/New_York --attendees team@mintprints.com 2>&1)"
rc=$?
set -e

[[ "$rc" -eq 2 ]] || fail "calendar_create should be blocked by policy"
echo "$err_out" | grep -F "Drafts only" >/dev/null || fail "calendar_create block should explain the drafts-only policy"
pass "microsoft calendar_create is blocked by policy"

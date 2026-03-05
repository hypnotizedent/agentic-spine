#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPT="$ROOT/surfaces/verify/d61-session-loop-traceability-lock.sh"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "required command missing: $1"
}

require_cmd mktemp

[[ -f "$SCRIPT" ]] || fail "missing script under test: $SCRIPT"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/surfaces/verify"
mkdir -p "$tmp/mailroom/state/loop-scopes"
mkdir -p "$tmp/receipts/sessions"
cp "$SCRIPT" "$tmp/surfaces/verify/d61-session-loop-traceability-lock.sh"
chmod +x "$tmp/surfaces/verify/d61-session-loop-traceability-lock.sh"

cat > "$tmp/mailroom/state/loop-scopes/LOOP-TEST-D61.scope.md" <<'MD'
---
loop_id: LOOP-TEST-D61
status: active
severity: low
created: 2026-02-17
---
MD

cat > "$tmp/mailroom/state/ledger.csv" <<'CSV'
run_id,created_at,started_at,finished_at,status,prompt_file,result_file,error,context_used
CAP-TEST-000,2026-02-17T00:00:00Z,2026-02-17T00:00:00Z,2026-02-17T00:00:01Z,done,mailroom.runtime.migrate,receipt.md,,capability
CSV

rcap_dir="$tmp/receipts/sessions/RCAP-20260217-120000__agent.session.closeout__Rtest"
mkdir -p "$rcap_dir"
now_ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
cat > "$rcap_dir/receipt.md" <<EOF
# Receipt: CAP-20260217-120000__agent.session.closeout__Rtest

| Field | Value |
|-------|-------|
| Run ID | \`CAP-20260217-120000__agent.session.closeout__Rtest\` |
| Status | done |
| Generated | $now_ts |

## Timestamps

| Event | Time |
|-------|------|
| Start | $now_ts |
| End | $now_ts |
EOF

if ! "$tmp/surfaces/verify/d61-session-loop-traceability-lock.sh" >/tmp/d61-fallback-pass.out 2>&1; then
  cat /tmp/d61-fallback-pass.out >&2
  fail "expected pass when receipt fallback is present"
fi
grep -q "D61 PASS" /tmp/d61-fallback-pass.out || fail "missing PASS output for fallback case"
pass "receipt fallback satisfies closeout freshness when ledger has no done closeout rows"

rm -rf "$tmp/receipts/sessions/RCAP-20260217-120000__agent.session.closeout__Rtest"

if "$tmp/surfaces/verify/d61-session-loop-traceability-lock.sh" >/tmp/d61-fallback-fail.out 2>&1; then
  cat /tmp/d61-fallback-fail.out >&2
  fail "expected fail when both ledger and receipts lack closeout evidence"
fi
grep -q "no done ledger rows or receipts" /tmp/d61-fallback-fail.out || fail "missing expected failure message"
pass "fails cleanly when no closeout evidence exists"

echo "ALL TESTS PASSED"

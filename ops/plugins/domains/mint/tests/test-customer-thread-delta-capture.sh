#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
SPINE_ROOT="$ROOT"
source "$SPINE_ROOT/ops/lib/spine-paths.sh"
spine_paths_init

SCRIPT="$ROOT/ops/plugins/domains/mint/bin/customer-thread-delta-capture"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  if grep -Fq -- "$needle" <<<"$haystack"; then
    pass "$label"
  else
    fail "$label (missing: $needle)"
  fi
}

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

json_out="$(
  SPINE_STATE="$tmpdir/state" \
  python3 "$SCRIPT" \
    --message-id msg-123 \
    --classification quote_ready_gap \
    --severity high \
    --confidence high \
    --summary "Customer asked for pricing but packet state was missing." \
    --next-action "restore packet binding" \
    --evidence-ref "mailbox:msg-123" \
    --json
)"

assert_contains "$json_out" "\"status\": \"ok\"" "capture returns ok"
record_path="$(printf '%s' "$json_out" | python3 -c 'import json,sys; print(json.load(sys.stdin)["record_path"])')"
[[ -f "$record_path" ]] && pass "record written to runtime state" || fail "record written to runtime state"
record_payload="$(cat "$record_path")"
assert_contains "$record_payload" "\"classification\": \"quote_ready_gap\"" "record stores classification"
assert_contains "$record_payload" "\"next_action\": \"restore packet binding\"" "record stores next action"
assert_contains "$record_payload" "\"capability\": \"mint.customer.thread.delta.capture\"" "record stores capability id"

echo "tests: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]

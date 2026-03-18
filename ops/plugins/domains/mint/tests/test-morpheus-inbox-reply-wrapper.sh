#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
WRAPPER="$ROOT/../mint-modules/scripts/morpheus/inbox.sh"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

[[ -x "$WRAPPER" ]] || fail "missing Morpheus inbox wrapper"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export SPINE_ROOT="$tmp/spine"
export SPINE_STATE="$tmp/state"
export MORPHEUS_MINT_MAILBOX="team@mintprints.com"
mkdir -p "$SPINE_ROOT" "$SPINE_STATE"

cat >"$tmp/ops" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$@" >"${SPINE_STATE}/last-ops-args.txt"
cat <<'OUT'
Receipt: /tmp/fake-morpheus-reply.receipt.md
{"data":{"attachment_count":0,"author_mode":"morpheus","draft_id":"DRAFT-1","draft_subject":"13825 Freedland Scrubs","draft_to":"davidfreedland@yahoo.com","draft_verified":true,"outbound_receipt_id":"MOR-OUT-TEST","reply_draft_id":"MRD-TEST","reply_mode":"formal_quote_ready","thread_mode":"reply"}}
OUT
EOF
chmod +x "$tmp/ops"
export OPS_BIN="$tmp/ops"

reset_args() {
  : >"$SPINE_STATE/last-ops-args.txt"
}

assert_arg_line() {
  local expected="$1"
  grep -Fx -- "$expected" "$SPINE_STATE/last-ops-args.txt" >/dev/null || fail "missing wrapper pass-through arg: $expected"
}

assert_no_arg_line() {
  local unexpected="$1"
  if grep -Fx -- "$unexpected" "$SPINE_STATE/last-ops-args.txt" >/dev/null; then
    fail "wrapper should not pass arg: $unexpected"
  fi
}

reset_args
"$WRAPPER" reply MSG-AUTO --json >/dev/null
assert_arg_line "mint.customer.reply.draft"
assert_arg_line "--reply-mode"
assert_arg_line "general"
assert_no_arg_line "--body"
assert_no_arg_line "--subject"
assert_no_arg_line "--content-type"

reset_args
"$WRAPPER" reply MSG-1 \
  --quote-state quote-ready \
  --job-number 13825 \
  --job-nickname "Freedland Scrubs" \
  --quote-subject "13825 Freedland Scrubs" \
  --quote-url "https://example.test/invoice/13825" \
  --json >/dev/null
assert_arg_line "mint.customer.reply.draft"
assert_arg_line "--reply-mode"
assert_arg_line "formal_quote_ready"
assert_arg_line "--job-number"
assert_arg_line "13825"
assert_arg_line "--job-nickname"
assert_arg_line "Freedland Scrubs"
assert_arg_line "--quote-subject"
assert_arg_line "13825 Freedland Scrubs"
assert_arg_line "--quote-url"
assert_arg_line "https://example.test/invoice/13825"
assert_no_arg_line "--body"
assert_no_arg_line "--subject"
assert_no_arg_line "--content-type"

reset_args
"$WRAPPER" reply MSG-1 \
  --job-number 13825 \
  --job-nickname "Freedland Scrubs" \
  --quote-subject "13825 Freedland Scrubs" \
  --quote-url "https://example.test/invoice/13825" \
  --json >/dev/null
assert_arg_line "--reply-mode"
assert_arg_line "formal_quote_ready"
assert_no_arg_line "--body"

reset_args
"$WRAPPER" reply MSG-1 \
  --quote-state quote-live-payment \
  --job-number 13825 \
  --job-nickname "Freedland Scrubs" \
  --quote-subject "13825 Freedland Scrubs" \
  --quote-url "https://example.test/invoice/13825" \
  --json >/dev/null
assert_arg_line "--reply-mode"
assert_arg_line "formal_quote_ready"
assert_arg_line "--current-action"
assert_arg_line "Payment link is live now"

reset_args
"$WRAPPER" reply MSG-1 \
  --quote-state in-progress \
  --job-number 13825 \
  --job-nickname "Freedland Scrubs" \
  --quote-subject "13825 Freedland Scrubs" \
  --quote-url "https://example.test/invoice/13825" \
  --json >/dev/null
assert_arg_line "--reply-mode"
assert_arg_line "in_progress"
assert_arg_line "--current-action"
assert_arg_line "Production is moving now"

if "$WRAPPER" reply MSG-1 --body "Hi David" --subject "Bad override" >/dev/null 2>"$tmp/subject-error.log"; then
  fail "Morpheus wrapper should reject generic subject overrides"
fi
grep -F 'does not accept --body/--body-file' "$tmp/subject-error.log" >/dev/null || fail "freeform body rejection should block the wrapper before customer prose overrides"

if "$WRAPPER" reply MSG-1 \
  --quote-state quote-ready \
  --job-number 13825 \
  --job-nickname "Freedland Scrubs" \
  --quote-subject "13825 Freedland Scrubs" \
  --quote-url "https://example.test/invoice/13825" \
  --subject "Bad override" >/dev/null 2>"$tmp/subject-error.log"; then
  fail "Morpheus wrapper should reject generic subject overrides"
fi
grep -F 'does not accept --subject' "$tmp/subject-error.log" >/dev/null || fail "subject override rejection should explain the governed quote/job path"

if "$WRAPPER" reply MSG-1 --body "Hi David" --content-type Text >/dev/null 2>"$tmp/content-type-error.log"; then
  fail "Morpheus wrapper should reject wrapper-side content-type overrides"
fi
grep -F 'does not accept --body/--body-file' "$tmp/content-type-error.log" >/dev/null || fail "freeform body rejection should block wrapper-side content-type overrides too"

if "$WRAPPER" reply MSG-1 \
  --quote-state quote-ready \
  --job-number 13825 \
  --job-nickname "Freedland Scrubs" \
  --quote-subject "13825 Freedland Scrubs" \
  --quote-url "https://example.test/invoice/13825" \
  --content-type Text >/dev/null 2>"$tmp/content-type-error.log"; then
  fail "Morpheus wrapper should reject wrapper-side content-type overrides"
fi
grep -F 'does not accept --content-type' "$tmp/content-type-error.log" >/dev/null || fail "content-type rejection should explain governed HTML policy"

if "$WRAPPER" reply MSG-1 --body "Hi David" --author-mode ronny >/dev/null 2>"$tmp/author-mode-error.log"; then
  fail "Morpheus wrapper should block ronny author-mode override in the normal customer lane"
fi
grep -F 'blocks --author-mode ronny by default' "$tmp/author-mode-error.log" >/dev/null || fail "author-mode rejection should explain the break-glass override"

if "$WRAPPER" reply MSG-1 --body "Hi David" >/dev/null 2>"$tmp/general-error.log"; then
  fail "Morpheus wrapper should block freeform general drafting in the normal customer lane"
fi
grep -F 'does not accept --body/--body-file' "$tmp/general-error.log" >/dev/null || fail "general drafting rejection should explain the blocked freeform body path"

pass "Morpheus inbox reply wrapper routes quote/customer replies through governed reply modes and blocks unsafe customer-lane overrides"

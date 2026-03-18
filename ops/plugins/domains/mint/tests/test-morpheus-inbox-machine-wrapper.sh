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
Receipt: /tmp/fake-machine.receipt.md
{"inbox_item_id":"MII-TEST","workflow_state":"queued","reply_anchor_mode":"reply_chain","source_mode":"team_direct","source_message_anchor":{"subject":"Need 24 polos","from":"direct@example.com"},"record_file":"/tmp/MII-TEST.json"}
OUT
EOF
chmod +x "$tmp/ops"
export OPS_BIN="$tmp/ops"

assert_arg_line() {
  local expected="$1"
  grep -Fx -- "$expected" "$SPINE_STATE/last-ops-args.txt" >/dev/null || fail "missing wrapper pass-through arg: $expected"
}

"$WRAPPER" open MSG-1 >/dev/null
assert_arg_line "mint.customer.inbox.item.get"
assert_arg_line "--message-id"
assert_arg_line "MSG-1"

"$WRAPPER" wait MSG-1 --note "waiting on size breakdown" >/dev/null
assert_arg_line "mint.customer.inbox.transition"
assert_arg_line "--state"
assert_arg_line "waiting_on_customer"

"$WRAPPER" promote MSG-RONNY-1 --source-mailbox ronny@mintprints.com >/dev/null
assert_arg_line "mint.customer.inbox.promote_to_team"
assert_arg_line "--source-mailbox"
assert_arg_line "ronny@mintprints.com"
assert_arg_line "--target-mailbox"
assert_arg_line "team@mintprints.com"

"$WRAPPER" history-materialize "Green School Student T-shirts" --apply >/dev/null
assert_arg_line "mint.customer.inbox.history.materialize"
assert_arg_line "--query"
assert_arg_line "Green School Student T-shirts"
assert_arg_line "--apply"

"$WRAPPER" history-restore "Green School Student T-shirts" --apply >/dev/null
assert_arg_line "mint.customer.inbox.history.restore"
assert_arg_line "--query"
assert_arg_line "Green School Student T-shirts"
assert_arg_line "--apply"

"$WRAPPER" review MII-TEST >/dev/null
assert_arg_line "mint.customer.inbox.complete"
assert_arg_line "--action"
assert_arg_line "review"
assert_arg_line "--inbox-item-id"
assert_arg_line "MII-TEST"

"$WRAPPER" send MSG-1 --note "approved and sent" >/dev/null
assert_arg_line "mint.customer.inbox.complete"
assert_arg_line "--action"
assert_arg_line "send"
assert_arg_line "--message-id"
assert_arg_line "MSG-1"

"$WRAPPER" park MSG-1 --note "parked for operator follow-up" >/dev/null
assert_arg_line "mint.customer.inbox.complete"
assert_arg_line "--action"
assert_arg_line "park"
assert_arg_line "--message-id"
assert_arg_line "MSG-1"

pass "Morpheus inbox wrapper exposes the governed inbox item, completion, and promote-to-team machine actions"

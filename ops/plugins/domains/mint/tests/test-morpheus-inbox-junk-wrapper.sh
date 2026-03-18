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
Receipt: /tmp/fake-junk.receipt.md
{"mailbox":"team@mintprints.com","source_folder_display_name":"Junk Email","reviewed_count":2,"counts":{"supplier_marketing":1,"risky_junk":1,"real_customer_false_positive":0},"action_counts":{"move_to_supplier_marketing":1,"restore_to_inbox":0,"leave_in_junk":1},"items":[],"actions":[]}
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
"$WRAPPER" junk-review --top 7 --folder "Junk Email" --order oldest_first --json >/dev/null
assert_arg_line "mint.customer.junk.review"
assert_arg_line "--mailbox"
assert_arg_line "team@mintprints.com"
assert_arg_line "--top"
assert_arg_line "7"
assert_arg_line "--folder"
assert_arg_line "Junk Email"
assert_arg_line "--order"
assert_arg_line "oldest_first"
assert_arg_line "--json"

reset_args
"$WRAPPER" junk-sweep --top 9 --json >/dev/null
assert_arg_line "mint.customer.junk.sweep"
assert_arg_line "--mailbox"
assert_arg_line "team@mintprints.com"
assert_arg_line "--top"
assert_arg_line "9"
assert_arg_line "--json"
assert_no_arg_line "--apply"

reset_args
"$WRAPPER" junk-sweep --top 9 --apply --json >/dev/null
assert_arg_line "mint.customer.junk.sweep"
assert_arg_line "--apply"
assert_arg_line "--json"

reset_args
"$WRAPPER" junk-drain --top 11 --apply --json >/dev/null
assert_arg_line "mint.customer.junk.drain"
assert_arg_line "--top"
assert_arg_line "11"
assert_arg_line "--apply"
assert_arg_line "--json"

reset_args
"$WRAPPER" junk-clear --top 13 --apply --json >/dev/null
assert_arg_line "mint.customer.junk.clear"
assert_arg_line "--top"
assert_arg_line "13"
assert_arg_line "--apply"
assert_arg_line "--json"

pass "Morpheus inbox wrapper exposes governed junk review, sweep, drain, and clear commands without falling back to ad hoc mail tooling"

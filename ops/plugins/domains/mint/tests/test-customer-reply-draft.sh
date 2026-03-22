#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
source "$ROOT/ops/lib/spine-paths.sh"
spine_paths_init
SCRIPT="$ROOT/ops/plugins/domains/mint/bin/customer-reply-draft"

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

body_file="$tmpdir/body.html"
printf '<p>We can get this cleaned up for you.</p>' >"$body_file"

fake_ops="$tmpdir/ops"
cat >"$fake_ops" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cap="$3"
shift 4 || true
echo "Receipt: /tmp/${cap}.receipt.md"
case "$cap" in
  microsoft.mail.get)
    message_id=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --message-id) message_id="${2:-}"; shift 2 ;;
        *) shift ;;
      esac
    done
    if [[ "$message_id" == "MSG-VENDOR" ]]; then
      cat <<'JSON'
{"id":"MSG-VENDOR","subject":"Updated proof","bodyPreview":"proof attached","from":{"emailAddress":{"address":"digitrace54@gmail.com","name":"Sheik"}}}
JSON
    else
      cat <<'JSON'
{"id":"MSG-CUSTOMER","subject":"Need updated shirts","bodyPreview":"Can you help with this?","from":{"emailAddress":{"address":"customer@example.com","name":"Customer"}}}
JSON
    fi
    ;;
  microsoft.mail.reply.draft)
    cat <<'JSON'
{"id":"DRAFT-1","subject":"13825 Papa","body":{"contentType":"HTML","content":"<p>body</p><hr><div>quoted</div>"}}
JSON
    ;;
  microsoft.mail.attachment.add)
    cat <<'JSON'
{"id":"ATT-NEW","name":"proof.pdf"}
JSON
    ;;
  *)
    echo "unsupported capability: $cap" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$fake_ops"

attach_file="$tmpdir/proof.pdf"
printf 'pdf' >"$attach_file"

json_out="$(
  OPS_BIN="$fake_ops" \
  SPINE_STATE="$tmpdir/state" \
  python3 "$SCRIPT" --message-id MSG-CUSTOMER --mailbox team@mintprints.com --body-file "$body_file" --job-number 13825 --job-nickname Papa --attach "$attach_file" --json
)"
assert_contains "$json_out" "\"status\": \"ok\"" "reply draft succeeds"
assert_contains "$json_out" "\"draft_id\": \"DRAFT-1\"" "provider draft id returned"
assert_contains "$json_out" "\"subject\": \"13825 Papa\"" "governed subject applied"
assert_contains "$json_out" "\"attachment_count\": 1" "attachment recorded"

vendor_rc=0
vendor_out="$(
  OPS_BIN="$fake_ops" \
  SPINE_STATE="$tmpdir/state" \
  python3 "$SCRIPT" --message-id MSG-VENDOR --mailbox team@mintprints.com --body-file "$body_file" --json
)" || vendor_rc=$?
[[ "$vendor_rc" -eq 2 ]] && pass "vendor thread is blocked by default" || fail "vendor thread is blocked by default"
assert_contains "$vendor_out" "\"status\": \"blocked\"" "blocked payload returned for vendor thread"

echo "tests: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]

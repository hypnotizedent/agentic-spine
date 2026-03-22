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
fake_log="$tmpdir/fake.log"

fake_ops="$tmpdir/ops"
cat >"$fake_ops" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cap="$3"
shift 4 || true
echo "$cap $*" >>"${FAKE_LOG:?}"
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
{"id":"MSG-VENDOR","conversationId":"CONV-VENDOR","subject":"Updated proof","bodyPreview":"proof attached","from":{"emailAddress":{"address":"digitrace54@gmail.com","name":"Sheik"}}}
JSON
    elif [[ "$message_id" == "MSG-CANONICAL-CUSTOMER" ]]; then
      cat <<'JSON'
{"id":"MSG-CANONICAL-CUSTOMER","conversationId":"CONV-CUSTOMER","subject":"13825 Papa","bodyPreview":"Can you help with this?","from":{"emailAddress":{"address":"customer@example.com","name":"Customer"}}}
JSON
    else
      cat <<'JSON'
{"id":"MSG-CUSTOMER","conversationId":"CONV-CUSTOMER","subject":"Need updated shirts","bodyPreview":"Can you help with this?","from":{"emailAddress":{"address":"customer@example.com","name":"Customer"}}}
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
  FAKE_LOG="$fake_log" \
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
  FAKE_LOG="$fake_log" \
  SPINE_STATE="$tmpdir/state" \
  python3 "$SCRIPT" --message-id MSG-VENDOR --mailbox team@mintprints.com --body-file "$body_file" --json
)" || vendor_rc=$?
[[ "$vendor_rc" -eq 2 ]] && pass "vendor thread is blocked by default" || fail "vendor thread is blocked by default"
assert_contains "$vendor_out" "\"status\": \"blocked\"" "blocked payload returned for vendor thread"

mkdir -p "$tmpdir/state/mint/customer-lifecycle-resolutions/records/2026/03/21"
cat >"$tmpdir/state/mint/customer-lifecycle-resolutions/index.ndjson" <<JSON
{"customer_email":"customer@example.com","lifecycle_id":"MCLR-TEST","lifecycle_state":"art_revision_required","message_id":"MSG-VENDOR","packet_id":"","record_file":"$tmpdir/state/mint/customer-lifecycle-resolutions/records/2026/03/21/MCLR-TEST.json","reply_mode":"art_revision","stored_at_utc":"2026-03-21T12:00:00Z"}
JSON
cat >"$tmpdir/state/mint/customer-lifecycle-resolutions/records/2026/03/21/MCLR-TEST.json" <<'JSON'
{
  "lifecycle_id": "MCLR-TEST",
  "customer_email": "customer@example.com",
  "customer_name": "Customer",
  "record_file": "runtime://customer-lifecycle-resolutions/MCLR-TEST.json",
  "outbound_binding": {
    "binding_id": "MOB-TEST",
    "reply_target_role": "customer",
    "canonical_customer_thread": {
      "message_id": "MSG-CANONICAL-CUSTOMER",
      "conversation_id": "CONV-CUSTOMER",
      "from": "customer@example.com",
      "from_name": "Customer"
    }
  }
}
JSON
mkdir -p "$tmpdir/state/mint/customer-outbound-bindings/records"
cat >"$tmpdir/state/mint/customer-outbound-bindings/records/MOB-TEST.json" <<'JSON'
{
  "binding_id": "MOB-TEST",
  "canonical_recipients": {
    "mailbox": "team@mintprints.com",
    "to": ["customer@example.com"],
    "cc": []
  },
  "participant_resolution": {
    "reply_target_role": "customer",
    "canonical_customer_thread": {
      "message_id": "MSG-CANONICAL-CUSTOMER",
      "conversation_id": "CONV-CUSTOMER",
      "from": "customer@example.com",
      "from_name": "Customer"
    }
  }
}
JSON

resolved_out="$(
  OPS_BIN="$fake_ops" \
  FAKE_LOG="$fake_log" \
  SPINE_STATE="$tmpdir/state" \
  python3 "$SCRIPT" --message-id MSG-VENDOR --mailbox team@mintprints.com --body-file "$body_file" --json
)"
assert_contains "$resolved_out" "\"status\": \"ok\"" "vendor source can draft when canonical customer target exists"
assert_contains "$resolved_out" "\"target_message_id\": \"MSG-CANONICAL-CUSTOMER\"" "reply draft records canonical target message"
assert_contains "$(cat "$fake_log")" "microsoft.mail.reply.draft --message-id MSG-CANONICAL-CUSTOMER" "reply draft uses canonical customer thread"

echo "tests: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]

#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
REPLY="$ROOT/ops/plugins/domains/mint/bin/customer-reply-draft"
REPLY_POLICY_CONTRACT="$ROOT/ops/bindings/mint.customer.reply.draft.policy.contract.yaml"
QUOTE_POLICY_CONTRACT="$ROOT/ops/bindings/mint.quote.intelligence.policy.contract.yaml"
OPERATOR_POLICY_CONTRACT="$ROOT/ops/bindings/mint.customer.operator.policy.contract.yaml"
DISPOSITION_CONTRACT="$ROOT/ops/bindings/mint.customer.inbox.disposition.contract.yaml"
QUOTE_INTAKE_CONTRACT="$ROOT/ops/bindings/mint.customer.quote.intake.contract.yaml"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || fail "jq required"
[[ -x "$REPLY" ]] || fail "missing customer-reply-draft executable"
[[ -f "$REPLY_POLICY_CONTRACT" ]] || fail "missing governed reply policy contract"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export SPINE_ROOT="$tmp/spine"
export SPINE_STATE="$tmp/state"
export MINT_CUSTOMER_REPLY_DRAFT_POLICY_CONTRACT="$REPLY_POLICY_CONTRACT"
export MINT_QUOTE_INTELLIGENCE_POLICY_CONTRACT="$QUOTE_POLICY_CONTRACT"
export MINT_CUSTOMER_OPERATOR_POLICY_CONTRACT="$OPERATOR_POLICY_CONTRACT"
export MINT_CUSTOMER_INBOX_DISPOSITION_CONTRACT="$DISPOSITION_CONTRACT"
export MINT_CUSTOMER_QUOTE_INTAKE_CONTRACT="$QUOTE_INTAKE_CONTRACT"
export MORPHEUS_ALLOW_UNSAFE_REPLY_OVERRIDE=1
mkdir -p "$SPINE_ROOT/bin" "$SPINE_STATE"

cat >"$SPINE_ROOT/bin/ops" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

capability="${3:-}"
shift 3 || true
if [[ "${1:-}" == "--" ]]; then
  shift
fi

echo "Receipt: /tmp/${capability}.receipt.md"

case "$capability" in
  microsoft.mail.get)
    message_id=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --message-id) message_id="$2"; shift 2 ;;
        --mailbox) shift 2 ;;
        *) shift ;;
      esac
    done
    case "$message_id" in
      MSG-FWD)
        cat <<'JSON'
{"id":"MSG-FWD","subject":"FW: Merch Quote Request - Cove Brewery","conversationId":"CONV-INTERNAL","internetMessageId":"<fwd@example.com>","from":{"emailAddress":{"address":"team@mintprints.com","name":"Mint Prints Team"}},"bodyPreview":"Please reply from the real customer thread.","body":{"contentType":"HTML","content":"<html><body><div>Please reply from the real customer thread.</div><br><div><b>From:</b> Spencer Todd &lt;marketing@covebrewery.com&gt;</div><div><b>Subject:</b> Merch Quote Request - Cove Brewery</div></body></html>"}} 
JSON
        ;;
      DRAFT-CANON)
        draft_subject="$(cat "${SPINE_STATE}/draft-subject.txt" 2>/dev/null || printf 'Re: Merch Quote Request - Cove Brewery')"
        draft_to="$(cat "${SPINE_STATE}/draft-to.txt" 2>/dev/null || printf 'marketing@covebrewery.com')"
        draft_cc="$(cat "${SPINE_STATE}/draft-cc.txt" 2>/dev/null || printf '')"
        draft_body="$(cat "${SPINE_STATE}/draft-body.html" 2>/dev/null || printf '<div>Quoted thread</div>')"
        python3 - <<'PY' "$draft_subject" "$draft_to" "$draft_cc" "$draft_body"
import json
import sys

def parse_csv(text):
    out = []
    for item in text.split(","):
        cleaned = item.strip()
        if cleaned:
            out.append({"emailAddress": {"address": cleaned}})
    return out

payload = {
    "id": "DRAFT-CANON",
    "subject": sys.argv[1],
    "conversationId": "CONV-EXT",
    "toRecipients": parse_csv(sys.argv[2]),
    "ccRecipients": parse_csv(sys.argv[3]),
    "body": {"contentType": "HTML", "content": sys.argv[4]},
}
print(json.dumps(payload))
PY
        ;;
      *)
        echo "unexpected message id: $message_id" >&2
        exit 1
        ;;
    esac
    ;;
  communications.mail.search)
    printf '%s\n' "search" >>"${SPINE_STATE}/search-calls.log"
    cat <<'JSON'
{"data":{"microsoft":{"value":[
  {"id":"MSG-EXT","subject":"Merch Quote Request - Cove Brewery","conversationId":"CONV-EXT","internetMessageId":"<ext@example.com>","receivedDateTime":"2026-03-13T12:00:00Z","from":{"emailAddress":{"address":"marketing@covebrewery.com","name":"Spencer Todd"}},"toRecipients":[{"emailAddress":{"address":"team@mintprints.com"}},{"emailAddress":{"address":"owner@covebrewery.com"}}],"ccRecipients":[{"emailAddress":{"address":"melissa@covebrewery.com"}},{"emailAddress":{"address":"taproom@Covebrewery.com"}},{"emailAddress":{"address":"khartofilis@whelchelpartners.com"}}],"body":{"contentType":"HTML","content":"<div>Clean customer thread</div>"}}
]}}}
JSON
    ;;
  microsoft.mail.reply.draft)
    message_id=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --message-id) message_id="$2"; shift 2 ;;
        --mailbox) shift 2 ;;
        *) shift ;;
      esac
    done
    printf '%s\n' "$message_id" >>"${SPINE_STATE}/reply-draft-calls.log"
    cat <<'JSON'
{"id":"DRAFT-CANON","subject":"Re: Merch Quote Request - Cove Brewery","conversationId":"CONV-EXT","toRecipients":[{"emailAddress":{"address":"marketing@covebrewery.com"}}],"ccRecipients":[{"emailAddress":{"address":"design@covebrewery.com"}}],"body":{"contentType":"HTML","content":"<div>Quoted thread</div>"}}
JSON
    ;;
  microsoft.mail.draft.update)
    message_id=""
    body=""
    subject=""
    to_csv=""
    cc_csv=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --message-id) message_id="$2"; shift 2 ;;
        --body) body="$2"; shift 2 ;;
        --subject) subject="$2"; shift 2 ;;
        --to) to_csv="$2"; shift 2 ;;
        --cc) cc_csv="$2"; shift 2 ;;
        --content-type) shift 2 ;;
        --mailbox) shift 2 ;;
        *) shift ;;
      esac
    done
    printf '%s' "$message_id" >"${SPINE_STATE}/last-update-draft-id.txt"
    printf '%s' "$subject" >"${SPINE_STATE}/draft-subject.txt"
    printf '%s' "$to_csv" >"${SPINE_STATE}/draft-to.txt"
    printf '%s' "$cc_csv" >"${SPINE_STATE}/draft-cc.txt"
    printf '%s' "$body" >"${SPINE_STATE}/draft-body.html"
    python3 - <<'PY' "$message_id" "$subject" "$to_csv" "$cc_csv"
import json
import sys

def parse_csv(text):
    out = []
    for item in text.split(","):
        cleaned = item.strip()
        if cleaned:
            out.append({"emailAddress": {"address": cleaned}})
    return out

payload = {
    "id": sys.argv[1],
    "subject": sys.argv[2],
    "toRecipients": parse_csv(sys.argv[3]),
    "ccRecipients": parse_csv(sys.argv[4]),
}
print(json.dumps(payload))
PY
    ;;
  mint.customer.record.snapshot)
    cat <<'JSON'
{"data":{"query_mode":"email","fresh_slate":{"customer":{"record_id":"cust-cove","email":"marketing@covebrewery.com","name":"Spencer Todd","metadata":{"customer_identity":{"schema_version":"1.0","legal_name":"Spencer Todd","greeting_name":"Spencer","display_name":"Spencer","provenance":{"source":"operator_confirmed","confidence":"high"}}}},"customers":[{"record_id":"cust-cove","email":"marketing@covebrewery.com","name":"Spencer Todd","metadata":{"customer_identity":{"schema_version":"1.0","legal_name":"Spencer Todd","greeting_name":"Spencer","display_name":"Spencer","provenance":{"source":"operator_confirmed","confidence":"high"}}}}],"identity":{"schema_version":"1.0","legal_name":"Spencer Todd","greeting_name":"Spencer","display_name":"Spencer","provenance":{"source":"operator_confirmed","confidence":"high"},"record_id":"cust-cove","email":"marketing@covebrewery.com","has_customer_facing_name":true},"customer_match_count":1},"legacy_hold":{"orders":[]}}}
JSON
    ;;
  *)
    echo "unsupported capability: $capability" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$SPINE_ROOT/bin/ops"

packet_file="$tmp/quote_packet_cove.yaml"
cat >"$packet_file" <<'EOF'
quote_packet_id: packet-cove
customer_ref:
  resolved_email: marketing@covebrewery.com
  resolved_name: Spencer Todd
EOF

run_reply() {
  local quote_url="$1"
  "$REPLY" MSG-FWD \
    --mailbox team@mintprints.com \
    --body "Your quote lane is ready to review." \
    --quote-subject "13639 Cove Brewery merch quote" \
    --quote-url "$quote_url" \
    --packet-file "$packet_file" \
    --json
}

first_json="$(run_reply "https://example.test/q/cove-v1")"
first_draft_id="$(echo "$first_json" | jq -r '.data.draft_id')"

[[ "$(echo "$first_json" | jq -r '.data.canonical_thread.message_id')" == "MSG-EXT" ]] || fail "forwarded thread should resolve to the real external customer message"
[[ "$(echo "$first_json" | jq -r '.data.provider_receipts.external_thread_search_receipt')" == "/tmp/communications.mail.search.receipt.md" ]] || fail "search receipt should be surfaced for forwarded-thread resolution"
[[ "$(echo "$first_json" | jq -r '.data.draft_subject')" == "13639 Cove Brewery merch quote" ]] || fail "subject should come from the governed quote binding"
[[ "$(echo "$first_json" | jq -r '.data.subject_source')" == "quote_binding_subject" ]] || fail "subject source should report the quote binding"
[[ "$(echo "$first_json" | jq -r '.data.draft_to')" == "marketing@covebrewery.com,owner@covebrewery.com" ]] || fail "draft should inherit canonical To participants from the external thread"
[[ "$(echo "$first_json" | jq -r '.data.draft_cc')" == "melissa@covebrewery.com,taproom@covebrewery.com,khartofilis@whelchelpartners.com" ]] || fail "draft should inherit canonical CC participants from the external thread"
[[ "$(cat "$SPINE_STATE/reply-draft-calls.log")" == "MSG-EXT" ]] || fail "reply draft should target the external customer message, not the forwarded wrapper"
grep -F '<a href="https://example.test/q/cove-v1">13639 Cove Brewery merch quote</a>' "$SPINE_STATE/draft-body.html" >/dev/null || fail "quote binding should render as a governed hyperlink"

second_json="$(run_reply "https://example.test/q/cove-v2")"
second_draft_id="$(echo "$second_json" | jq -r '.data.draft_id')"

[[ "$second_draft_id" == "$first_draft_id" ]] || fail "rerun should update the existing canonical draft instead of creating a new one"
[[ "$(echo "$second_json" | jq -r '.data.outbound_binding.update_mode')" == "update_existing_binding" ]] || fail "rerun should report update_existing_binding"
[[ "$(wc -l <"$SPINE_STATE/reply-draft-calls.log" | tr -d ' ')" == "1" ]] || fail "rerun should not call microsoft.mail.reply.draft again"
[[ "$(cat "$SPINE_STATE/last-update-draft-id.txt")" == "DRAFT-CANON" ]] || fail "draft update should continue patching the same draft id"
grep -F 'https://example.test/q/cove-v2' "$SPINE_STATE/draft-body.html" >/dev/null || fail "rerendered draft should contain the updated quote hyperlink"
grep -F 'https://example.test/q/cove-v1' "$SPINE_STATE/draft-body.html" >/dev/null && fail "rerendered draft should replace the old quote hyperlink"
[[ "$(grep -o 'MORPHEUS (Mint Prints operational intelligence)' "$SPINE_STATE/draft-body.html" | wc -l | tr -d ' ')" == "1" ]] || fail "governed signature should render once on rerun"

pass "customer-reply-draft canonicalizes forwarded outbound replies onto one governed draft bound to the external thread and quote"

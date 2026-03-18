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
      MSG-COVE)
        cat <<'JSON'
{"id":"MSG-COVE","subject":"Merch Quote Request - Cove Brewery","conversationId":"CONV-COVE","internetMessageId":"<cove@example.com>","from":{"emailAddress":{"address":"marketing@covebrewery.com","name":"Spencer Todd"}},"toRecipients":[{"emailAddress":{"address":"team@mintprints.com"}}],"ccRecipients":[{"emailAddress":{"address":"melissa@covebrewery.com"}},{"emailAddress":{"address":"taproom@Covebrewery.com"}},{"emailAddress":{"address":"khartofilis@whelchelpartners.com"}}],"body":{"contentType":"HTML","content":"<div>Can you send the updated quote?</div>"}} 
JSON
        ;;
      DRAFT-FAIL)
        draft_body="$(cat "${SPINE_STATE}/draft-body.html" 2>/dev/null || printf '<div>Quoted thread</div>')"
        python3 - <<'PY' "$draft_body"
import json
import sys
print(json.dumps({
    "id": "DRAFT-FAIL",
    "subject": "13639 Cove Brewery merch quote",
    "conversationId": "CONV-COVE",
    "toRecipients": [{"emailAddress": {"address": "marketing@covebrewery.com"}}],
    "ccRecipients": [],
    "body": {"contentType": "HTML", "content": sys.argv[1]},
}))
PY
        ;;
      *)
        echo "unexpected message id: $message_id" >&2
        exit 1
        ;;
    esac
    ;;
  microsoft.mail.reply.draft)
    cat <<'JSON'
{"id":"DRAFT-FAIL","subject":"Re: Merch Quote Request - Cove Brewery","conversationId":"CONV-COVE","toRecipients":[{"emailAddress":{"address":"marketing@covebrewery.com"}}],"ccRecipients":[],"body":{"contentType":"HTML","content":"<div>Quoted thread</div>"}}
JSON
    ;;
  microsoft.mail.draft.update)
    body=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --body) body="$2"; shift 2 ;;
        --message-id|--subject|--to|--cc|--content-type|--mailbox) shift 2 ;;
        *) shift ;;
      esac
    done
    printf '%s' "$body" >"${SPINE_STATE}/draft-body.html"
    cat <<'JSON'
{"id":"DRAFT-FAIL","subject":"13639 Cove Brewery merch quote","toRecipients":[{"emailAddress":{"address":"marketing@covebrewery.com"}}],"ccRecipients":[]}
JSON
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

if "$REPLY" MSG-COVE \
  --mailbox team@mintprints.com \
  --body "I kept this on the original customer thread and the quote link is below." \
  --quote-subject "13639 Cove Brewery merch quote" \
  --quote-url "https://example.test/q/cove" \
  --packet-file "$packet_file" >/dev/null 2>"$tmp/recipient-guard-error.log"; then
  fail "draft should fail when readback drops the canonical reply-all recipients"
fi

grep -F 'draft readback recipients do not match the canonical external reply-all set' "$tmp/recipient-guard-error.log" >/dev/null || fail "recipient mismatch should explain the reply-all failure"
repair_index="$SPINE_STATE/mint/customer-repair-items/index.ndjson"
[[ -f "$repair_index" ]] || fail "recipient mismatch should record a repair item"
repair_file="$(tail -n 1 "$repair_index" | jq -r '.record_file')"
[[ "$(jq -r '.issue_type' "$repair_file")" == "reply_draft_recipient_mismatch" ]] || fail "repair item should use the recipient mismatch issue type"
[[ "$(jq -r '.expected.canonical_cc | join(",")' "$repair_file")" == "melissa@covebrewery.com,taproom@covebrewery.com,khartofilis@whelchelpartners.com" ]] || fail "repair item should capture the expected canonical CC list"
[[ "$(jq -r '.observed.verified_cc | join(",")' "$repair_file")" == "" ]] || fail "repair item should capture the dropped CC readback"

pass "customer-reply-draft fails closed when draft readback drops the canonical reply-all recipients"

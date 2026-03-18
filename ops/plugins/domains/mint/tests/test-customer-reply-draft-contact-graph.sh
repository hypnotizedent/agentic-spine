#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
REPLY="$ROOT/ops/plugins/domains/mint/bin/customer-reply-draft"
SET_GRAPH="$ROOT/ops/plugins/domains/mint/bin/customer-contact-graph-set"
REPLY_POLICY_CONTRACT="$ROOT/ops/bindings/mint.customer.reply.draft.policy.contract.yaml"
QUOTE_POLICY_CONTRACT="$ROOT/ops/bindings/mint.quote.intelligence.policy.contract.yaml"
OPERATOR_POLICY_CONTRACT="$ROOT/ops/bindings/mint.customer.operator.policy.contract.yaml"
GRAPH_CONTRACT="$ROOT/ops/bindings/mint.customer.contact.graph.contract.yaml"
DISPOSITION_CONTRACT="$ROOT/ops/bindings/mint.customer.inbox.disposition.contract.yaml"
QUOTE_INTAKE_CONTRACT="$ROOT/ops/bindings/mint.customer.quote.intake.contract.yaml"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || fail "jq required"
[[ -x "$REPLY" ]] || fail "missing customer-reply-draft executable"
[[ -x "$SET_GRAPH" ]] || fail "missing customer-contact-graph-set executable"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export SPINE_ROOT="$tmp/spine"
export SPINE_STATE="$tmp/state"
export MINT_CUSTOMER_REPLY_DRAFT_POLICY_CONTRACT="$REPLY_POLICY_CONTRACT"
export MINT_QUOTE_INTELLIGENCE_POLICY_CONTRACT="$QUOTE_POLICY_CONTRACT"
export MINT_CUSTOMER_OPERATOR_POLICY_CONTRACT="$OPERATOR_POLICY_CONTRACT"
export MINT_CUSTOMER_CONTACT_GRAPH_CONTRACT="$GRAPH_CONTRACT"
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
      MSG-APPROVAL)
        cat <<'JSON'
{"id":"MSG-APPROVAL","subject":"Re: Merch Quote Request - Cove Brewery","conversationId":"CONV-COVE","from":{"emailAddress":{"address":"marketing@covebrewery.com","name":"Cove Marketing"}},"toRecipients":[{"emailAddress":{"address":"team@mintprints.com"}}],"ccRecipients":[{"emailAddress":{"address":"khartofilis@whelchelpartners.com","name":"Kristy Hartofilis"}}],"body":{"contentType":"Text","content":"Hey Mint Prints Team,\nI have not received final approval yet, but Kristy is copied here because she needs to approve the direction.\nThanks,\nSpencer Todd\nCove Brewery"}}
JSON
        ;;
      MSG-DIRECT)
        cat <<'JSON'
{"id":"MSG-DIRECT","subject":"Re: Merch Quote Request - Cove Brewery","conversationId":"CONV-COVE","from":{"emailAddress":{"address":"marketing@covebrewery.com","name":"Cove Marketing"}},"toRecipients":[{"emailAddress":{"address":"team@mintprints.com"}}],"ccRecipients":[{"emailAddress":{"address":"khartofilis@whelchelpartners.com","name":"Kristy Hartofilis"}}],"body":{"contentType":"Text","content":"Hey Mint Prints Team,\nCan you send the updated quote lane over?\nThanks,\nSpencer Todd\nCove Brewery"}}
JSON
        ;;
      DRAFT-COVE)
        draft_body="$(cat "${SPINE_STATE}/draft-body.html" 2>/dev/null || printf '<div>Quoted thread</div>')"
        python3 - <<'PY' "$draft_body"
import json
import sys
print(json.dumps({
    "id": "DRAFT-COVE",
    "subject": "13639 Cove Brewery merch quote",
    "conversationId": "CONV-COVE",
    "toRecipients": [{"emailAddress": {"address": "marketing@covebrewery.com"}}],
    "ccRecipients": [{"emailAddress": {"address": "khartofilis@whelchelpartners.com"}}],
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
{"id":"DRAFT-COVE","subject":"Re: Merch Quote Request - Cove Brewery","conversationId":"CONV-COVE","toRecipients":[{"emailAddress":{"address":"marketing@covebrewery.com"}}],"ccRecipients":[{"emailAddress":{"address":"khartofilis@whelchelpartners.com"}}],"body":{"contentType":"HTML","content":"<div>Quoted thread</div>"}}
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
{"id":"DRAFT-COVE","subject":"13639 Cove Brewery merch quote","toRecipients":[{"emailAddress":{"address":"marketing@covebrewery.com"}}],"ccRecipients":[{"emailAddress":{"address":"khartofilis@whelchelpartners.com"}}]}
JSON
    ;;
  mint.customer.record.snapshot)
    cat <<'JSON'
{"data":{"query_mode":"email","fresh_slate":{"customer":{"record_id":"cust-cove","email":"marketing@covebrewery.com","name":"Spencer Todd","company":"Cove Brewery","metadata":{}},"customers":[{"record_id":"cust-cove","email":"marketing@covebrewery.com","name":"Spencer Todd","company":"Cove Brewery","metadata":{}}],"identity":{"schema_version":"1.0","legal_name":"Spencer Todd","display_name":"Spencer Todd","record_id":"cust-cove","email":"marketing@covebrewery.com","has_customer_facing_name":false},"customer_match_count":1},"legacy_hold":{"orders":[]}}}
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

"$SET_GRAPH" \
  --company "Cove Brewery" \
  --domain "covebrewery.com" \
  --domain "whelchelpartners.com" \
  --contact "email=marketing@covebrewery.com,name=Spencer Todd,greeting_name=Spencer,role=marketing,role=buyer,status=active,confidence=high" \
  --contact "email=khartofilis@whelchelpartners.com,name=Kristy Hartofilis,greeting_name=Kristy,role=owner,role=approver,status=historical,confidence=high" \
  --json >/dev/null

json_joint="$("$REPLY" MSG-APPROVAL \
  --mailbox team@mintprints.com \
  --body "I kept this on the original customer thread and the quote link is below." \
  --quote-subject "13639 Cove Brewery merch quote" \
  --quote-url "https://example.test/q/cove" \
  --packet-file "$packet_file" \
  --json)"
grep -F 'Greetings Spencer and Kristy,' "$SPINE_STATE/draft-body.html" >/dev/null || fail "approval thread should use a joint Spencer and Kristy greeting"
[[ "$(echo "$json_joint" | jq -r '.data.greeting_selection.selection_mode')" == "sender_plus_cc_approval" ]] || fail "reply output should persist sender_plus_cc_approval selection mode"

json_direct="$("$REPLY" MSG-DIRECT \
  --mailbox team@mintprints.com \
  --body "I kept this on the original customer thread and the quote link is below." \
  --quote-subject "13639 Cove Brewery merch quote" \
  --quote-url "https://example.test/q/cove" \
  --packet-file "$packet_file" \
  --json)"
grep -F 'Greetings Spencer,' "$SPINE_STATE/draft-body.html" >/dev/null || fail "non-approval thread should greet Spencer directly"
if grep -F 'Greetings Spencer and Kristy,' "$SPINE_STATE/draft-body.html" >/dev/null; then
  fail "non-approval thread should not keep the joint greeting"
fi
[[ "$(echo "$json_direct" | jq -r '.data.greeting_selection.primary_contact.greeting_name')" == "Spencer" ]] || fail "primary contact should resolve to Spencer"
[[ "$(echo "$json_direct" | jq -r '.data.customer_identity.greeting_name')" == "Spencer" ]] || fail "effective identity should inherit Spencer's governed greeting name"

pass "customer-reply-draft uses the company contact graph to choose direct vs joint greetings from thread context"

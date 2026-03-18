#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
BRIEF="$ROOT/ops/plugins/domains/mint/bin/customer-quote-brief"
REPLY="$ROOT/ops/plugins/domains/mint/bin/customer-reply-draft"
QUOTE_POLICY_CONTRACT="$ROOT/ops/bindings/mint.quote.intelligence.policy.contract.yaml"
REPLY_POLICY_CONTRACT="$ROOT/ops/bindings/mint.customer.reply.draft.policy.contract.yaml"
OPERATOR_POLICY_CONTRACT="$ROOT/ops/bindings/mint.customer.operator.policy.contract.yaml"
QUOTE_BRIEF_CONTRACT="$ROOT/ops/bindings/mint.customer.quote.brief.contract.yaml"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || fail "jq required"
[[ -x "$BRIEF" ]] || fail "missing customer-quote-brief executable"
[[ -x "$REPLY" ]] || fail "missing customer-reply-draft executable"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export SPINE_ROOT="$tmp/spine"
export SPINE_STATE="$tmp/state"
export MINT_QUOTE_INTELLIGENCE_POLICY_CONTRACT="$QUOTE_POLICY_CONTRACT"
export MINT_CUSTOMER_REPLY_DRAFT_POLICY_CONTRACT="$REPLY_POLICY_CONTRACT"
export MINT_CUSTOMER_OPERATOR_POLICY_CONTRACT="$OPERATOR_POLICY_CONTRACT"
export MINT_CUSTOMER_QUOTE_BRIEF_CONTRACT="$QUOTE_BRIEF_CONTRACT"
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
      MSG-MOE)
        cat <<'JSON'
{"id":"MSG-MOE","subject":"Re: 13838 Loe shimmy tank tops","conversationId":"CONV-MOE","internetMessageId":"<moe@example.com>","from":{"emailAddress":{"address":"humblereligion954@gmail.com","name":"Humble Religion"}},"body":{"contentType":"Text","content":"I’ll bring the garments by today or set the Uber up to deliver. Who can I call?"},"bodyPreview":"I’ll bring the garments by today or set the Uber up to deliver. Who can I call?"}
JSON
        ;;
      MSG-EC)
        cat <<'JSON'
{"id":"MSG-EC","subject":"Re: 13839 Respect march","conversationId":"CONV-EC","internetMessageId":"<ec@example.com>","from":{"emailAddress":{"address":"emilioacolon18@gmail.com","name":"Emilio Colon"}},"body":{"contentType":"Text","content":"Payment sent. Text me when they are ready.\n\nOn Tue, Mar 12, 2026, Ronny wrote:\nI’ll bring the garments by today or set the Uber up to deliver. Who can I call?"},"bodyPreview":"Payment sent. Text me when they are ready."}
JSON
        ;;
      DRAFT-1)
        draft_subject="$(cat "${SPINE_STATE}/last-draft-subject.txt" 2>/dev/null || printf '13838 Loe shimmy tank tops')"
        draft_content_type="$(cat "${SPINE_STATE}/last-draft-content-type.txt" 2>/dev/null || printf 'HTML')"
        draft_body="$(cat "${SPINE_STATE}/last-draft-body.txt" 2>/dev/null || printf '<div>Quoted thread</div>')"
        python3 - <<'PY' "${SPINE_STATE}/mail-get-draft.json" "$draft_subject" "$draft_content_type" "$draft_body"
from pathlib import Path
import json
import sys

payload = {
    "id": "DRAFT-1",
    "subject": sys.argv[2],
    "conversationId": "CONV-MOE",
    "toRecipients": [{"emailAddress": {"address": "humblereligion954@gmail.com"}}],
    "body": {
        "contentType": sys.argv[3],
        "content": sys.argv[4],
    },
}
Path(sys.argv[1]).write_text(json.dumps(payload), encoding="utf-8")
PY
        cat "${SPINE_STATE}/mail-get-draft.json"
        ;;
      *)
        echo "unexpected message id: $message_id" >&2
        exit 1
        ;;
    esac
    ;;
  microsoft.mail.reply.draft)
    cat <<'JSON'
{"id":"DRAFT-1","subject":"Re: 13838 Loe shimmy tank tops","conversationId":"CONV-MOE","toRecipients":[{"emailAddress":{"address":"humblereligion954@gmail.com"}}],"body":{"contentType":"HTML","content":"<div>Quoted thread</div>"}}
JSON
    ;;
  microsoft.mail.draft.update)
    body=""
    subject=""
    mailbox=""
    content_type=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --message-id) shift 2 ;;
        --to) shift 2 ;;
        --cc) shift 2 ;;
        --subject) subject="$2"; shift 2 ;;
        --body) body="$2"; shift 2 ;;
        --content-type) content_type="$2"; shift 2 ;;
        --mailbox) mailbox="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    printf '%s' "$body" >"${SPINE_STATE}/last-draft-body.txt"
    printf '%s' "$mailbox" >"${SPINE_STATE}/last-draft-mailbox.txt"
    printf '%s' "$subject" >"${SPINE_STATE}/last-draft-subject.txt"
    printf '%s' "$content_type" >"${SPINE_STATE}/last-draft-content-type.txt"
    printf '{"id":"DRAFT-1","subject":"%s","toRecipients":[{"emailAddress":{"address":"humblereligion954@gmail.com"}}]}\n' "$subject"
    ;;
  mint.customer.record.snapshot)
    cat <<'JSON'
{"data":{"quote_intelligence":{}}}
JSON
    ;;
  *)
    echo "unsupported capability: $capability" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$SPINE_ROOT/bin/ops"

json_brief="$("$BRIEF" MSG-MOE --mailbox team@mintprints.com --json)"
reply_preview="$(echo "$json_brief" | jq -r '.data.reply_preview.body_text')"

[[ "$(echo "$json_brief" | jq -r '.data.operator_brief.next_step')" == "keep this in email, restate approval-and-payment-before-dropoff policy, and ask the customer to send details through email" ]] || fail "quote brief should switch to the async-first next step"
[[ "$(echo "$json_brief" | jq -r '.data.operator_policy_match.matched')" == "true" ]] || fail "quote brief should record operator-policy match"
[[ "$reply_preview" == *"Orders must be approved and paid before anything is brought by."* ]] || fail "reply preview should restate the drop-off gate"
[[ "$reply_preview" == *"coordinate by phone at the moment"* ]] || fail "reply preview should refuse phone coordination"
[[ "$reply_preview" == *"send over what you need through email"* ]] || fail "reply preview should steer the customer back to email"
[[ "$reply_preview" != *"phone number"* ]] || fail "reply preview should not offer a phone number"

json_reply="$("$REPLY" MSG-MOE --body "I have your quote linked here." --mailbox team@mintprints.com --job-number 13838 --job-nickname "Loe shimmy tank tops" --json)"
reply_record="$(echo "$json_reply" | jq -r '.data.record_file')"
reply_body="$SPINE_STATE/last-draft-body.txt"

[[ -f "$reply_record" ]] || fail "reply draft record should exist"
grep -F 'Greetings Humble Religion,' "$reply_body" >/dev/null || fail "reply draft should keep a customer greeting"
grep -F 'Orders must be approved and paid before anything is brought by.' "$reply_body" >/dev/null || fail "reply draft should inject the approval/payment policy"
grep -F 'We do not have anyone available to coordinate by phone at the moment.' "$reply_body" >/dev/null || fail "reply draft should inject the no-phone note"
grep -F 'If you send over what you need through email, I can help you here and keep it documented.' "$reply_body" >/dev/null || fail "reply draft should keep coordination in email"
grep -F 'I have your quote linked here.' "$reply_body" >/dev/null || fail "reply draft should preserve the operator body"
[[ "$(jq -r '.operator_policy_contract' "$reply_record")" == "$OPERATOR_POLICY_CONTRACT" ]] || fail "reply record should persist the operator policy contract"
[[ "$(jq -r '.operator_policy_match.matched' "$reply_record")" == "true" ]] || fail "reply record should persist the operator-policy match"
[[ "$(jq -r '.operator_policy_match.rule' "$reply_record")" == "async_first_coordination_guard" ]] || fail "reply record should persist the async-first rule"

if "$REPLY" MSG-MOE --body "Please send me a phone number and I can call you." --mailbox team@mintprints.com --job-number 13838 --job-nickname "Loe shimmy tank tops" --json >/dev/null 2>&1; then
  fail "reply draft should reject positive phone-coordination wording in Morpheus mode"
fi

json_ec="$("$REPLY" MSG-EC --body "Payment received, we are on it." --mailbox team@mintprints.com --job-number 13839 --job-nickname "Respect march" --json)"
ec_record="$(echo "$json_ec" | jq -r '.data.record_file')"
ec_body="$SPINE_STATE/last-draft-body.txt"

[[ -f "$ec_record" ]] || fail "EC reply draft record should exist"
grep -F 'Payment received, we are on it.' "$ec_body" >/dev/null || fail "EC reply should preserve the operator body"
grep -F 'Orders must be approved and paid before anything is brought by.' "$ec_body" >/dev/null && fail "phone-only EC reply should not inject drop-off policy"
grep -F 'We do not have anyone available to coordinate by phone at the moment.' "$ec_body" >/dev/null && fail "phone-only EC reply should not inject no-phone coordination boilerplate"
[[ "$(jq -r '.operator_policy_match.matched' "$ec_record")" == "true" ]] || fail "EC reply should still record phone-only operator-policy match"
[[ "$(jq -r '.operator_policy_match.rule' "$ec_record")" == "async_first_phone_guard" ]] || fail "EC reply should classify phone-only follow-up separately from drop-off coordination"

pass "customer async-first operator policy hardening keeps coordination in email for the Humble Religion proving case"

#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
REPLY="$ROOT/ops/plugins/domains/mint/bin/customer-reply-draft"
REPLY_POLICY="$ROOT/ops/bindings/mint.customer.reply.draft.policy.contract.yaml"
QUOTE_POLICY="$ROOT/ops/bindings/mint.quote.intelligence.policy.contract.yaml"
OPERATOR_POLICY="$ROOT/ops/bindings/mint.customer.operator.policy.contract.yaml"
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
export MINT_CUSTOMER_REPLY_DRAFT_POLICY_CONTRACT="$REPLY_POLICY"
export MINT_QUOTE_INTELLIGENCE_POLICY_CONTRACT="$QUOTE_POLICY"
export MINT_CUSTOMER_OPERATOR_POLICY_CONTRACT="$OPERATOR_POLICY"
export MINT_CUSTOMER_INBOX_DISPOSITION_CONTRACT="$DISPOSITION_CONTRACT"
export MINT_CUSTOMER_QUOTE_INTAKE_CONTRACT="$QUOTE_INTAKE_CONTRACT"

mkdir -p "$SPINE_ROOT/bin" "$SPINE_STATE"

packet_file="$tmp/quote_packet_phuse.yaml"
cat >"$packet_file" <<'YAML'
quote_packet_id: packet-phuse
customer_ref:
  resolved_email: phusecream7@gmail.com
  resolved_name: Phuse Cream
line_items: []
YAML

history_packet_file="$tmp/quote_packet_phuse_history.yaml"
cat >"$history_packet_file" <<'YAML'
quote_packet_id: packet-phuse-history
customer_ref:
  resolved_email: phusecream7@gmail.com
  resolved_name: Phuse Cream
source_refs:
  - ref_type: operator_note
    summary: |
      Hi,

      Catherine Gustave-Whyte here again, and I'm reaching out on behalf of Phuse Cream.

      Could you send the updated quote option too?
line_items: []
YAML

neutral_packet_file="$tmp/quote_packet_brand_only.yaml"
cat >"$neutral_packet_file" <<'YAML'
quote_packet_id: packet-brand-only
customer_ref:
  resolved_email: brand@example.com
  resolved_name: Brand Only
  mail_salutation_mode: neutral
source_refs:
  - ref_type: operator_note
    summary: |
      Customer asked for a quote update but did not include a human contact name.
line_items: []
YAML

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
      MSG-PHUSE)
        cat <<'JSON'
{"id":"MSG-PHUSE","subject":"Need the updated quote option","conversationId":"CONV-PHUSE","internetMessageId":"<phuse@example.com>","from":{"emailAddress":{"address":"phusecream7@gmail.com","name":"Phuse Cream"}},"toRecipients":[{"emailAddress":{"address":"team@mintprints.com"}}],"ccRecipients":[],"body":{"contentType":"Text","content":"Hi,\n\nCatherine Gustave-Whyte here again, and I'm reaching out on behalf of Phuse Cream.\n\nCan you send the updated quote option too?\n\nBest regards,\nPhuse Cream Team"},"bodyPreview":"Catherine Gustave-Whyte here again, and I'm reaching out on behalf of Phuse Cream."}
JSON
        ;;
      MSG-PHUSE-HISTORY)
        cat <<'JSON'
{"id":"MSG-PHUSE-HISTORY","subject":"Need the updated quote option","conversationId":"CONV-PHUSE-HISTORY","internetMessageId":"<phuse-history@example.com>","from":{"emailAddress":{"address":"phusecream7@gmail.com","name":"Phuse Cream"}},"toRecipients":[{"emailAddress":{"address":"team@mintprints.com"}}],"ccRecipients":[],"body":{"contentType":"Text","content":"Can you send the updated quote option too?"},"bodyPreview":"Can you send the updated quote option too?"}
JSON
        ;;
      MSG-BRAND)
        cat <<'JSON'
{"id":"MSG-BRAND","subject":"Need the updated quote option","conversationId":"CONV-BRAND","internetMessageId":"<brand@example.com>","from":{"emailAddress":{"address":"brand@example.com","name":"Brand Only"}},"toRecipients":[{"emailAddress":{"address":"team@mintprints.com"}}],"ccRecipients":[],"body":{"contentType":"Text","content":"Can you send the updated quote option too?"},"bodyPreview":"Can you send the updated quote option too?"}
JSON
        ;;
      DRAFT-1)
        python3 - <<'PY' "${SPINE_STATE}/draft-body.txt" "${SPINE_STATE}/draft-subject.txt" "${SPINE_STATE}/draft-content-type.txt" "${SPINE_STATE}/draft-to.txt"
from pathlib import Path
import json
import sys

body = Path(sys.argv[1]).read_text(encoding="utf-8") if Path(sys.argv[1]).exists() else "<div>Quoted thread</div>"
subject = Path(sys.argv[2]).read_text(encoding="utf-8") if Path(sys.argv[2]).exists() else "13846 Phuse Cream 200"
content_type = Path(sys.argv[3]).read_text(encoding="utf-8") if Path(sys.argv[3]).exists() else "HTML"
to_address = Path(sys.argv[4]).read_text(encoding="utf-8").strip() if Path(sys.argv[4]).exists() else "phusecream7@gmail.com"
payload = {
    "id": "DRAFT-1",
    "subject": subject,
    "conversationId": "CONV-PHUSE",
    "toRecipients": [{"emailAddress": {"address": to_address}}],
    "ccRecipients": [],
    "body": {"contentType": content_type, "content": body},
}
print(json.dumps(payload))
PY
        ;;
      *)
        echo "unexpected microsoft.mail.get id: $message_id" >&2
        exit 1
        ;;
    esac
    ;;
  microsoft.mail.reply.draft)
    cat <<'JSON'
{"id":"DRAFT-1","subject":"Re: Need the updated quote option","conversationId":"CONV-PHUSE","toRecipients":[{"emailAddress":{"address":"phusecream7@gmail.com"}}],"ccRecipients":[],"body":{"contentType":"HTML","content":"<div>Quoted thread</div>"}}
JSON
    ;;
  microsoft.mail.draft.update)
    body=""
    subject=""
    content_type=""
    to=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --message-id) shift 2 ;;
        --to) to="$2"; shift 2 ;;
        --cc) shift 2 ;;
        --subject) subject="$2"; shift 2 ;;
        --body) body="$2"; shift 2 ;;
        --content-type) content_type="$2"; shift 2 ;;
        --mailbox) shift 2 ;;
        *) shift ;;
      esac
    done
    printf '%s' "$body" >"${SPINE_STATE}/draft-body.txt"
    printf '%s' "$subject" >"${SPINE_STATE}/draft-subject.txt"
    printf '%s' "$content_type" >"${SPINE_STATE}/draft-content-type.txt"
    printf '%s' "$to" >"${SPINE_STATE}/draft-to.txt"
    cat <<JSON
{"id":"DRAFT-1","subject":"$subject","conversationId":"CONV-PHUSE","toRecipients":[{"emailAddress":{"address":"${to:-phusecream7@gmail.com}"}}],"ccRecipients":[]}
JSON
    ;;
  mint.customer.record.snapshot)
    cat <<'JSON'
{"data":{"query_mode":"email","fresh_slate":{"customer":null,"customers":[],"identity":null,"customer_match_count":0},"legacy_hold":{"orders":[]},"quote_intelligence":{"customer_context_match":{"matched":false,"match_mode":"none","record_file":null,"selector":{},"summary":null},"customer_context":{}}}}
JSON
    ;;
  mint.customer.quote.intake)
    echo '{"data":{}}'
    ;;
  mint.customer.lifecycle.resolve)
    echo '{"data":{}}'
    ;;
  communications.mail.search)
    echo '{"value":[]}'
    ;;
  *)
    echo "unsupported capability: $capability" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$SPINE_ROOT/bin/ops"

json_out="$(
  "$REPLY" --message-id MSG-PHUSE --mailbox team@mintprints.com --reply-mode formal_quote_ready --author-mode morpheus \
    --packet-file "$packet_file" \
    --job-number 13846 \
    --job-nickname "Phuse Cream 200" \
    --quote-subject "13846 Phuse Cream 200" \
    --quote-url "https://mint-prints-4019cb.printavo.com/invoice/6ffcbebd3178266014a48b4c74e9e055" \
    --json
)"

[[ "$(echo "$json_out" | jq -r '.data.customer_contact_name')" == "Catherine Gustave-Whyte" ]] || fail "direct sender self-introduction should override branded mailbox display name"
grep -F 'Greetings Catherine,' "${SPINE_STATE}/draft-body.txt" >/dev/null || fail "draft should greet the introduced human name, not the brand mailbox display name"
if grep -F 'Greetings Phuse,' "${SPINE_STATE}/draft-body.txt" >/dev/null; then
  fail "draft should not derive a first-name greeting from the branded mailbox display name"
fi

history_json="$(
  "$REPLY" --message-id MSG-PHUSE-HISTORY --mailbox team@mintprints.com --reply-mode formal_quote_ready --author-mode morpheus \
    --packet-file "$history_packet_file" \
    --job-number 13846 \
    --job-nickname "Phuse Cream 200" \
    --quote-subject "13846 Phuse Cream 200" \
    --quote-url "https://mint-prints-4019cb.printavo.com/invoice/6ffcbebd3178266014a48b4c74e9e055" \
    --json
)"

[[ "$(echo "$history_json" | jq -r '.data.customer_contact_name')" == "Phuse Cream" ]] || fail "history fixture should preserve the branded mailbox display name at the contact layer"
grep -F 'Greetings Catherine,' "${SPINE_STATE}/draft-body.txt" >/dev/null || fail "draft should reuse the human name mined from governed packet evidence when the latest message body does not self-identify"
if grep -F 'Greetings Phuse,' "${SPINE_STATE}/draft-body.txt" >/dev/null; then
  fail "packet-evidence greeting fallback should suppress branded first-name guesses"
fi

neutral_json="$(
  "$REPLY" --message-id MSG-BRAND --mailbox team@mintprints.com --reply-mode formal_quote_ready --author-mode morpheus \
    --packet-file "$neutral_packet_file" \
    --job-number 13846 \
    --job-nickname "Brand Only 200" \
    --quote-subject "13846 Brand Only 200" \
    --quote-url "https://mint-prints-4019cb.printavo.com/invoice/neutral-brand-only" \
    --json
)"

grep -F 'Hello,' "${SPINE_STATE}/draft-body.txt" >/dev/null || fail "draft should fail closed to a neutral salutation when no governed human greeting exists"
if grep -F 'Greetings Brand,' "${SPINE_STATE}/draft-body.txt" >/dev/null; then
  fail "draft should not derive a greeting from the brand alias when salutation mode is neutral"
fi
[[ "$(echo "$neutral_json" | jq -r '.data.mail_identity_projection.mail_salutation_mode')" == "neutral" ]] || fail "neutral fixture should persist the neutral salutation mode"

pass "customer-reply-draft prefers direct-sender self-identification over branded mailbox display names"

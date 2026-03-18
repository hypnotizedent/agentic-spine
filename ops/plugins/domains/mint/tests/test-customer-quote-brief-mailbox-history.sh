#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
BRIEF="$ROOT/ops/plugins/domains/mint/bin/customer-quote-brief"
POLICY_CONTRACT="$ROOT/ops/bindings/mint.quote.intelligence.policy.contract.yaml"
OPERATOR_POLICY_CONTRACT="$ROOT/ops/bindings/mint.customer.operator.policy.contract.yaml"
QUOTE_BRIEF_CONTRACT="$ROOT/ops/bindings/mint.customer.quote.brief.contract.yaml"
DISPOSITION_CONTRACT="$ROOT/ops/bindings/mint.customer.inbox.disposition.contract.yaml"
QUOTE_INTAKE_CONTRACT="$ROOT/ops/bindings/mint.customer.quote.intake.contract.yaml"
MAILBOX_STANDARD_CONTRACT="$ROOT/ops/bindings/mint.customer.mailbox.standard.contract.yaml"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || fail "jq required"
[[ -x "$BRIEF" ]] || fail "missing customer-quote-brief executable"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export SPINE_ROOT="$tmp/spine"
export SPINE_STATE="$tmp/state"
export MINT_QUOTE_INTELLIGENCE_POLICY_CONTRACT="$POLICY_CONTRACT"
export MINT_CUSTOMER_OPERATOR_POLICY_CONTRACT="$OPERATOR_POLICY_CONTRACT"
export MINT_CUSTOMER_QUOTE_BRIEF_CONTRACT="$QUOTE_BRIEF_CONTRACT"
export MINT_CUSTOMER_INBOX_DISPOSITION_CONTRACT="$DISPOSITION_CONTRACT"
export MINT_CUSTOMER_QUOTE_INTAKE_CONTRACT="$QUOTE_INTAKE_CONTRACT"
export MINT_CUSTOMER_MAILBOX_STANDARD_CONTRACT="$MAILBOX_STANDARD_CONTRACT"
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
    cat <<'JSON'
{"id":"MSG-KYLE","subject":"Re: Print Request","conversationId":"CONV-KYLE","internetMessageId":"<live-kyle@example.com>","receivedDateTime":"2026-03-16T13:00:00Z","from":{"emailAddress":{"address":"kyle@example.com","name":"Kyle"}},"body":{"contentType":"Text","content":"We have the garment and artwork direction now. Still waiting on final piece counts and sizes."}}
JSON
    ;;
  microsoft.mail.attachments.list)
    cat <<'JSON'
{"value":[]}
JSON
    ;;
  communications.mail.search)
    cat <<'JSON'
{"data":{"microsoft":{"value":[
  {"id":"MSG-KYLE","conversationId":"CONV-KYLE","internetMessageId":"<live-kyle@example.com>","subject":"Re: Print Request","receivedDateTime":"2026-03-16T13:00:00Z","from":{"emailAddress":{"address":"kyle@example.com","name":"Kyle"}}}
]}}}
JSON
    ;;
  communications.mailarchiver.search)
    cat <<'JSON'
{"data":{"messages":[
  {"id":"mailarchiver:101","archiveMailbox":"team@mintprints.com","history_lane":"mail_archiver","internetMessageId":"<info-kyle@example.com>","subject":"Print Request","receivedDateTime":"2026-03-13T16:16:00Z","from":{"emailAddress":{"address":"kyle@example.com","name":"Kyle"}},"toRecipients":[{"emailAddress":{"address":"info@mintprints.com"}}],"ccRecipients":[],"bodyPreview":"Client will have everything finalized by March 20.","body":{"contentType":"Text","content":"Client will have everything finalized by March 20 and we do not have the piece counts yet."}},
  {"id":"mailarchiver:102","archiveMailbox":"ronny@mintprints.com","history_lane":"mail_archiver","internetMessageId":"<ronny-kyle@example.com>","subject":"Re: Print Request","receivedDateTime":"2026-03-14T10:11:00Z","from":{"emailAddress":{"address":"kyle@example.com","name":"Kyle"}},"toRecipients":[{"emailAddress":{"address":"ronny@mintprints.com"}}],"ccRecipients":[],"bodyPreview":"Still waiting on the final counts.","body":{"contentType":"Text","content":"Still waiting on the final counts and size breakdown from the client."}}
]}}
JSON
    ;;
  mint.customer.record.snapshot)
    cat <<'JSON'
{"data":{
  "fresh_slate":{"customer":{"record_id":"cust-kyle","company":"Kyle Co","email":"kyle@example.com"},"identity":{"display_name":"Kyle","legal_name":"Kyle"}} ,
  "legacy_hold":{"latest_order":null,"latest_order_line_items":[],"latest_order_imprints":[]},
  "artifact_visibility":{"state":"no_active_artifacts","active_count":0},
  "artwork_intelligence_visibility":{"state":"none"},
  "printavo_visibility":{"state":"none"},
  "company_contact_graph":{"match_mode":"email_exact","summary":{"contact_names":["Kyle"]}},
  "quote_intelligence":{"customer_context_match":{"matched":false,"match_mode":"none","selector":{},"summary":null,"context":null},"customer_context":null}
}}
JSON
    ;;
  mint.customer.quote.intake)
    cat <<'JSON'
{"data":{"record_file":"","summary":{"work_type":"quote_request"}}}
JSON
    ;;
  mint.customer.lifecycle.resolve)
    cat <<'JSON'
{"data":{"state":"no_lifecycle_binding"}}
JSON
    ;;
  *)
    echo "unsupported capability: $capability" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$SPINE_ROOT/bin/ops"

json_out="$("$BRIEF" MSG-KYLE --mailbox team@mintprints.com --json)"

[[ "$(echo "$json_out" | jq -r '.data.operator_brief.prior_context[] | select(.kind=="mail_history") | .count')" == "2" ]] || fail "archive history should contribute two prior hits"
[[ "$(echo "$json_out" | jq -r '.data.history_messages[0].history_lane')" == "mail_archiver" ]] || fail "history_messages should preserve archive lane"
[[ "$(echo "$json_out" | jq -r '.data.history_messages[0].source_mailbox')" == "ronny@mintprints.com" ]] || fail "history_messages should preserve source mailbox"
[[ "$(echo "$json_out" | jq -r '.data.history_messages[1].source_mailbox')" == "team@mintprints.com" ]] || fail "team archive lane should remain visible"

pass "customer-quote-brief carries governed history from archived team/info and ronny mailboxes into the operator view"

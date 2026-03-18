#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
REPLY="$ROOT/ops/plugins/domains/mint/bin/customer-reply-draft"
REPLY_POLICY="$ROOT/ops/bindings/mint.customer.reply.draft.policy.contract.yaml"
QUOTE_POLICY="$ROOT/ops/bindings/mint.quote.intelligence.policy.contract.yaml"
OPERATOR_POLICY="$ROOT/ops/bindings/mint.customer.operator.policy.contract.yaml"
DISPOSITION_CONTRACT="$ROOT/ops/bindings/mint.customer.inbox.disposition.contract.yaml"
QUOTE_INTAKE_CONTRACT="$ROOT/ops/bindings/mint.customer.quote.intake.contract.yaml"
MACHINE_CONTRACT="$ROOT/ops/bindings/mint.customer.inbox.machine.contract.yaml"

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
export MINT_CUSTOMER_INBOX_MACHINE_CONTRACT="$MACHINE_CONTRACT"

mkdir -p "$SPINE_ROOT/bin" "$SPINE_STATE/mint/customer-inbox-items/current" "$SPINE_STATE/mint/customer-inbox-items/by-message-id"

cat >"$SPINE_STATE/mint/customer-inbox-items/current/MII-TESTPROMO.json" <<EOF
{
  "inbox_item_id": "MII-TESTPROMO",
  "workflow_state": "queued",
  "disposition": "unsupported_scope",
  "team_message_anchor": {"message_id": "MSG-PROMOTED"},
  "source_message_anchor": {"message_id": "MSG-RONNY-1", "mailbox": "ronny@mintprints.com", "from": "marwan@icosf.org", "subject": "Print Request"},
  "transition_history": []
}
EOF

cat >"$SPINE_STATE/mint/customer-inbox-items/by-message-id/MSG-PROMOTED.json" <<EOF
{"message_id":"MSG-PROMOTED","inbox_item_id":"MII-TESTPROMO","record_file":"$SPINE_STATE/mint/customer-inbox-items/current/MII-TESTPROMO.json"}
EOF

cat >"$SPINE_ROOT/bin/ops" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

capability="${3:-}"
shift 3 || true
if [[ "${1:-}" == "--" ]]; then
  shift
fi

printf '%s\n' "$capability" >>"${SPINE_STATE}/ops.log"
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
      MSG-PROMOTED)
        cat <<'JSON'
{"id":"MSG-PROMOTED","subject":"FW: Print Request","conversationId":"CONV-PROMOTED","internetMessageId":"<promoted@example.com>","from":{"emailAddress":{"address":"ronny@mintprints.com","name":"Ronny"}},"toRecipients":[{"emailAddress":{"address":"team@mintprints.com","name":"Mint Team"}}],"ccRecipients":[],"body":{"contentType":"Text","content":"MINT TEAM PROMOTE\npromote_id: MIP-TEST-1\nsource_mailbox: ronny@mintprints.com\nsource_message_id: MSG-RONNY-1\nsource_received_at: 2026-03-17T12:04:00Z\nsource_from: marwan@icosf.org\nsource_subject: Print Request\nsource_customer_email: marwan@icosf.org\ntarget_mailbox: team@mintprints.com\nreply_anchor_mode: fresh_outbound\nnote: Governed promote into the canonical Mint team inbox.\nEND MINT TEAM PROMOTE\n\nFrom: Marwan <marwan@icosf.org>\nSubject: Print Request\n\nCan you do vinyl floor signage for us?"},"bodyPreview":"Can you do vinyl floor signage for us."}
JSON
        ;;
      DRAFT-NEW)
        cat <<'JSON'
{"id":"DRAFT-NEW","subject":"Re: FW: Print Request","from":{"emailAddress":{"address":"team@mintprints.com","name":"Mint Team"}},"toRecipients":[{"emailAddress":{"address":"marwan@icosf.org","name":"Marwan"}}],"ccRecipients":[],"body":{"contentType":"HTML","content":"<p>Greetings Marwan,</p><p>I want to be straight with you about the cleanest lane we can actually support.</p><p>We specialize in apparel printing and do not have the equipment for vinyl floor signage.</p>"}}
JSON
        ;;
      *)
        echo "unexpected message id: $message_id" >&2
        exit 1
        ;;
    esac
    ;;
  communications.mail.search)
    echo '{"value":[]}'
    ;;
  mint.customer.record.snapshot)
    echo '{"data":{"quote_intelligence":{}}}'
    ;;
  microsoft.mail.draft.create)
    cat <<'JSON'
{"id":"DRAFT-NEW","subject":"Re: FW: Print Request","toRecipients":[{"emailAddress":{"address":"marwan@icosf.org","name":"Marwan"}}],"ccRecipients":[],"body":{"contentType":"HTML","content":"<p>draft</p>"}}
JSON
    ;;
  microsoft.mail.reply.draft)
    echo "reply_draft should not run for promoted fresh-outbound threads" >&2
    exit 91
    ;;
  microsoft.mail.draft.update)
    echo "draft_update should not be the creation path for promoted fresh-outbound threads" >&2
    exit 92
    ;;
  *)
    echo "unsupported capability: $capability" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$SPINE_ROOT/bin/ops"

json_out="$("$REPLY" --message-id MSG-PROMOTED --mailbox team@mintprints.com --reply-mode not_a_fit --author-mode morpheus --json)"

[[ "$(echo "$json_out" | jq -r '.data.thread_mode')" == "fresh_outbound" ]] || fail "promoted forward should draft in fresh_outbound mode"
[[ "$(echo "$json_out" | jq -r '.data.draft_to')" == "marwan@icosf.org" ]] || fail "fresh_outbound draft should target the original customer"
grep -Fx 'microsoft.mail.draft.create' "$SPINE_STATE/ops.log" >/dev/null || fail "promoted forward should create a fresh draft"
if grep -Fx 'microsoft.mail.reply.draft' "$SPINE_STATE/ops.log" >/dev/null; then
  fail "promoted forward should not try to create a reply-chain draft"
fi

updated_item="$SPINE_STATE/mint/customer-inbox-items/current/MII-TESTPROMO.json"
[[ "$(jq -r '.workflow_state' "$updated_item")" == "drafted" ]] || fail "successful draft should transition the inbox item to drafted"

pass "customer-reply-draft uses fresh_outbound drafting for governed promoted-forward customer mail"

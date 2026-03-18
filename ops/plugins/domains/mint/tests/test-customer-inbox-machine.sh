#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
WORK_ITEMS="$ROOT/ops/plugins/domains/mint/bin/customer-inbox-work-items"
ITEM_GET="$ROOT/ops/plugins/domains/mint/bin/customer-inbox-item-get"
TRANSITION="$ROOT/ops/plugins/domains/mint/bin/customer-inbox-transition"
DISPOSITION_CONTRACT="$ROOT/ops/bindings/mint.customer.inbox.disposition.contract.yaml"
QUOTE_INTAKE_CONTRACT="$ROOT/ops/bindings/mint.customer.quote.intake.contract.yaml"
MACHINE_CONTRACT="$ROOT/ops/bindings/mint.customer.inbox.machine.contract.yaml"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || fail "jq required"
[[ -x "$WORK_ITEMS" ]] || fail "missing customer-inbox-work-items executable"
[[ -x "$ITEM_GET" ]] || fail "missing customer-inbox-item-get executable"
[[ -x "$TRANSITION" ]] || fail "missing customer-inbox-transition executable"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export SPINE_ROOT="$tmp/spine"
export SPINE_STATE="$tmp/state"
export MINT_CUSTOMER_INBOX_DISPOSITION_CONTRACT="$DISPOSITION_CONTRACT"
export MINT_CUSTOMER_QUOTE_INTAKE_CONTRACT="$QUOTE_INTAKE_CONTRACT"
export MINT_CUSTOMER_INBOX_MACHINE_CONTRACT="$MACHINE_CONTRACT"
export MINT_CUSTOMER_REORDER_CUSTOMERS_EXPORT="$tmp/customers.csv"
export MINT_CUSTOMER_REORDER_ORDERS_EXPORT="$tmp/orders.csv"
export MINT_CUSTOMER_REORDER_CLIENT_ASSETS_ROOT="$tmp/client-assets"
mkdir -p "$SPINE_ROOT/bin" "$SPINE_STATE" "$MINT_CUSTOMER_REORDER_CLIENT_ASSETS_ROOT"

cat >"$MINT_CUSTOMER_REORDER_CUSTOMERS_EXPORT" <<'CSV'
Customer ID,First Name,Last Name,Company,Email,Phone,Created
1,Marwan,Customer,ICOSF,marwan@icosf.org,+1,2026-03-01 00:00:00 -0500
CSV

cat >"$MINT_CUSTOMER_REORDER_ORDERS_EXPORT" <<'CSV'
Invoice #,Nickname,Created Date,Production Due Date,Customer Full Name,Customer Email,Customer Company,Customer Id,Total Quantity,Paid?,Invoice Status,Public Invoice View URL,Invoice URL
CSV

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
  microsoft.mail.folder.messages)
    cat <<'JSON'
{"value":[
  {"id":"MSG-TEAM-DIRECT","conversationId":"CONV-DIRECT","subject":"Need 24 polos","receivedDateTime":"2026-03-17T12:00:00Z","from":{"emailAddress":{"address":"direct@example.com","name":"Direct Buyer"}},"bodyPreview":"Need 24 polos next week.","isRead":false},
  {"id":"MSG-TEAM-PROMOTED","conversationId":"CONV-PROMOTED","subject":"FW: Print Request","receivedDateTime":"2026-03-17T12:05:00Z","from":{"emailAddress":{"address":"ronny@mintprints.com","name":"Ronny"}},"bodyPreview":"MINT TEAM PROMOTE","isRead":false}
]}
JSON
    ;;
  communications.mail.search)
    cat <<'JSON'
{"data":{"microsoft":{"value":[
  {"id":"MSG-TEAM-DIRECT","conversationId":"CONV-DIRECT","subject":"Need 24 polos","receivedDateTime":"2026-03-17T12:00:00Z","from":{"emailAddress":{"address":"direct@example.com","name":"Direct Buyer"}},"bodyPreview":"Need 24 polos next week.","isRead":false},
  {"id":"MSG-TEAM-PROMOTED","conversationId":"CONV-PROMOTED","subject":"FW: Print Request","receivedDateTime":"2026-03-17T12:05:00Z","from":{"emailAddress":{"address":"ronny@mintprints.com","name":"Ronny"}},"bodyPreview":"MINT TEAM PROMOTE","isRead":false}
]}}}
JSON
    ;;
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
      MSG-TEAM-DIRECT)
        cat <<'JSON'
{"id":"MSG-TEAM-DIRECT","conversationId":"CONV-DIRECT","subject":"Need 24 polos","receivedDateTime":"2026-03-17T12:00:00Z","from":{"emailAddress":{"address":"direct@example.com","name":"Direct Buyer"}},"bodyPreview":"Need 24 polos next week.","body":{"contentType":"Text","content":"Need 24 polos next week."},"hasAttachments":false}
JSON
        ;;
      MSG-TEAM-PROMOTED)
        cat <<'JSON'
{"id":"MSG-TEAM-PROMOTED","conversationId":"CONV-PROMOTED","subject":"FW: Print Request","receivedDateTime":"2026-03-17T12:05:00Z","from":{"emailAddress":{"address":"ronny@mintprints.com","name":"Ronny"}},"bodyPreview":"MINT TEAM PROMOTE","body":{"contentType":"Text","content":"MINT TEAM PROMOTE\npromote_id: MIP-TEST-1\nsource_mailbox: ronny@mintprints.com\nsource_message_id: MSG-RONNY-1\nsource_received_at: 2026-03-17T12:04:00Z\nsource_from: marwan@icosf.org\nsource_subject: Print Request\nsource_customer_email: marwan@icosf.org\ntarget_mailbox: team@mintprints.com\nreply_anchor_mode: fresh_outbound\nnote: Governed promote into the canonical Mint team inbox.\nEND MINT TEAM PROMOTE\n\nFrom: Marwan <marwan@icosf.org>\nSubject: Print Request\n\nCan you do vinyl floor signage for us?"},"hasAttachments":false}
JSON
        ;;
      *)
        echo "unexpected message id: $message_id" >&2
        exit 1
        ;;
    esac
    ;;
  *)
    echo "unsupported capability: $capability" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$SPINE_ROOT/bin/ops"

json_out="$("$WORK_ITEMS" --mailbox team@mintprints.com --top 10 --json)"

direct_state="$(echo "$json_out" | jq -r '.work_items[] | select(.effective_message_id=="MSG-TEAM-DIRECT") | .queue_item.workflow_state')"
direct_source_mode="$(echo "$json_out" | jq -r '.work_items[] | select(.effective_message_id=="MSG-TEAM-DIRECT") | .queue_item.source_mode')"
direct_reply_anchor="$(echo "$json_out" | jq -r '.work_items[] | select(.effective_message_id=="MSG-TEAM-DIRECT") | .queue_item.reply_anchor_mode')"
promoted_item_id="$(echo "$json_out" | jq -r '.work_items[] | select(.effective_message_id=="MSG-TEAM-PROMOTED") | .queue_item.inbox_item_id')"
promoted_source_mode="$(echo "$json_out" | jq -r '.work_items[] | select(.effective_message_id=="MSG-TEAM-PROMOTED") | .queue_item.source_mode')"
promoted_reply_anchor="$(echo "$json_out" | jq -r '.work_items[] | select(.effective_message_id=="MSG-TEAM-PROMOTED") | .queue_item.reply_anchor_mode')"
promoted_from="$(echo "$json_out" | jq -r '.work_items[] | select(.effective_message_id=="MSG-TEAM-PROMOTED") | .from')"
promoted_subject="$(echo "$json_out" | jq -r '.work_items[] | select(.effective_message_id=="MSG-TEAM-PROMOTED") | .subject')"

[[ "$direct_state" == "queued" ]] || fail "direct actionable mail should default to queued"
[[ "$direct_source_mode" == "team_direct" ]] || fail "direct team mail should use team_direct source mode"
[[ "$direct_reply_anchor" == "reply_chain" ]] || fail "direct team mail should use reply_chain mode"
[[ "$promoted_source_mode" == "promoted_forward" ]] || fail "promoted forward should use promoted_forward source mode"
[[ "$promoted_reply_anchor" == "fresh_outbound" ]] || fail "promoted forward should switch to fresh_outbound mode"
[[ "$promoted_from" == "marwan@icosf.org" ]] || fail "promoted forward should display the original customer sender"
[[ "$promoted_subject" == "Print Request" ]] || fail "promoted forward should display the original customer subject"

item_json="$("$ITEM_GET" --message-id MSG-TEAM-PROMOTED --json)"
[[ "$(echo "$item_json" | jq -r '.inbox_item_id')" == "$promoted_item_id" ]] || fail "item get by message id should resolve the same inbox item"
[[ "$(echo "$item_json" | jq -r '.reply_anchor_mode')" == "fresh_outbound" ]] || fail "item get should preserve fresh_outbound anchor mode"

transition_json="$("$TRANSITION" --message-id MSG-TEAM-PROMOTED --state unsupported_scope --note "unsupported signage request" --json)"
[[ "$(echo "$transition_json" | jq -r '.workflow_state')" == "unsupported_scope" ]] || fail "transition should update the inbox item workflow state"

item_json_after="$("$ITEM_GET" --inbox-item-id "$promoted_item_id" --json)"
[[ "$(echo "$item_json_after" | jq -r '.workflow_state')" == "unsupported_scope" ]] || fail "item get by id should reflect the transitioned state"

pass "customer inbox machine persists direct and promoted items, exposes them by id/message, and applies governed state transitions"

#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
WORK_ITEMS="$ROOT/ops/plugins/domains/mint/bin/customer-inbox-work-items"
DISPOSITION_CONTRACT="$ROOT/ops/bindings/mint.customer.inbox.disposition.contract.yaml"
QUOTE_INTAKE_CONTRACT="$ROOT/ops/bindings/mint.customer.quote.intake.contract.yaml"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || fail "jq required"
[[ -x "$WORK_ITEMS" ]] || fail "missing customer-inbox-work-items executable"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export SPINE_ROOT="$tmp/spine"
export SPINE_STATE="$tmp/state"
export FAKE_OPS_LOG="$tmp/ops.log"
export MINT_CUSTOMER_INBOX_DISPOSITION_CONTRACT="$DISPOSITION_CONTRACT"
export MINT_CUSTOMER_QUOTE_INTAKE_CONTRACT="$QUOTE_INTAKE_CONTRACT"
export MINT_CUSTOMER_REORDER_CUSTOMERS_EXPORT="$tmp/customers.csv"
export MINT_CUSTOMER_REORDER_ORDERS_EXPORT="$tmp/orders.csv"
export MINT_CUSTOMER_REORDER_CLIENT_ASSETS_ROOT="$tmp/client-assets"
mkdir -p "$SPINE_ROOT/bin" "$SPINE_STATE" "$MINT_CUSTOMER_REORDER_CLIENT_ASSETS_ROOT/George Mouakar/13623 TowMaxx towing polos"

cat >"$MINT_CUSTOMER_REORDER_CUSTOMERS_EXPORT" <<'CSV'
Customer ID,First Name,Last Name,Company,Email,Phone,Created
10077020,George,Mouakar,TowMaxx towing,George@towmaxxtowing.com,+19548509905,2025-11-05 11:32:55 -0500
CSV

cat >"$MINT_CUSTOMER_REORDER_ORDERS_EXPORT" <<'CSV'
Invoice #,Nickname,Created Date,Production Due Date,Customer Full Name,Customer Email,Customer Company,Customer Id,Total Quantity,Paid?,Invoice Status,Public Invoice View URL,Invoice URL
13623,TowMaxx towing polos,2025-11-05,2025-11-05,George Mouakar,George@towmaxxtowing.com,TowMaxx towing,10077020,28,true,COMPLETE,https://example.test/public/13623,https://example.test/internal/13623
CSV

printf 'dst' >"$MINT_CUSTOMER_REORDER_CLIENT_ASSETS_ROOT/George Mouakar/13623 TowMaxx towing polos/13623 TowMaxx towing polos.DST"

cat >"$SPINE_ROOT/bin/ops" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

log_file="${FAKE_OPS_LOG:?}"
capability="${3:-}"
shift 3 || true
if [[ "${1:-}" == "--" ]]; then
  shift
fi

printf '%s' "$capability" >>"$log_file"
for arg in "$@"; do
  printf ' %s' "$arg" >>"$log_file"
done
printf '\n' >>"$log_file"

echo "Receipt: /tmp/${capability}.receipt.md"

case "$capability" in
  microsoft.mail.folder.messages)
    cat <<'JSON'
{"value":[
  {"id":"MSG-QUOTE","conversationId":"C-QUOTE","subject":"Need quote for 24 hoodies","receivedDateTime":"2026-03-12T14:10:00Z","from":{"emailAddress":{"address":"newcustomer@example.com","name":"Alex Customer"}},"bodyPreview":"Need pricing for 24 black hoodies next week.","isRead":false},
  {"id":"MSG-ART","conversationId":"C-ART","subject":"Artwork attached for the new order","receivedDateTime":"2026-03-12T14:09:00Z","from":{"emailAddress":{"address":"artcustomer@example.com","name":"Ari Art"}},"bodyPreview":"See attached logo pdf for the order.","isRead":false},
  {"id":"MSG-PROOF","conversationId":"C-PROOF","subject":"Proof looks good with one change","receivedDateTime":"2026-03-12T14:08:00Z","from":{"emailAddress":{"address":"proofcustomer@example.com","name":"Pat Proof"}},"bodyPreview":"The proof looks good, but please move the back print up.","isRead":true},
  {"id":"FWD-REORDER","conversationId":"C-REORDER","subject":"FW: TowMaxx Towing shirts","receivedDateTime":"2026-03-12T14:07:00Z","from":{"emailAddress":{"address":"ronny@mintprints.com","name":"Ronny"}},"bodyPreview":"Forwarded TowMaxx reorder note.","isRead":false},
  {"id":"MSG-REORDER","conversationId":"C-REORDER","subject":"TowMaxx Towing shirts","receivedDateTime":"2026-03-12T14:06:00Z","from":{"emailAddress":{"address":"george@towmaxxtowing.com","name":"George Mouakar"}},"bodyPreview":"I want the same shirts as last time but black this time.","isRead":false},
  {"id":"MSG-VENDOR","conversationId":"C-VENDOR","subject":"FW: Sheik revision for PapaPalooza","receivedDateTime":"2026-03-12T14:05:00Z","from":{"emailAddress":{"address":"team@mintprints.com","name":"Mint Team"}},"bodyPreview":"Latest vendor revision is attached for the PapaPalooza correction pass.","isRead":false},
  {"id":"MSG-SPAM","conversationId":"C-SPAM","subject":"Jason Beeker / Hit Promo weekly deals","receivedDateTime":"2026-03-12T14:04:00Z","from":{"emailAddress":{"address":"jason@hitpromo.example","name":"Jason Beeker"}},"bodyPreview":"Special offer this week. Unsubscribe any time.","isRead":false},
  {"id":"MSG-INVITE","conversationId":"C-INVITE","subject":"Invitation: Routine maintenance planned","receivedDateTime":"2026-03-12T14:03:30Z","from":{"emailAddress":{"address":"alerts@mail.zapier.com","name":"Zapier Alerts"}},"bodyPreview":"Join with Google Meet. Meeting link included.","isRead":false},
  {"id":"MSG-UNICODE","conversationId":"C-UNICODE","subject":"All beauty, no beasts","receivedDateTime":"2026-03-12T14:03:15Z","from":{"emailAddress":{"address":"hello@everybody.world","name":"Everybody.World"}},"bodyPreview":"Oh, to be an enjoyer of wishes. ͏ ͏ ͏ ͏ ͏ ͏ ͏ ͏ ͏ ͏ ͏ ͏","isRead":false},
  {"id":"MSG-AMB","conversationId":"C-AMB","subject":"Checking in","receivedDateTime":"2026-03-12T14:03:00Z","from":{"emailAddress":{"address":"unknown@example.com","name":"Unknown"}},"bodyPreview":"Wanted to follow up.","isRead":false}
]}
JSON
    ;;
  communications.mail.search)
    query=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --query) query="$2"; shift 2 ;;
        --top) shift 2 ;;
        --mailbox) shift 2 ;;
        --json) shift ;;
        *) shift ;;
      esac
    done
    if [[ "$query" != "*" ]]; then
      echo '{"data":{"microsoft":{"value":[]}}}'
      exit 0
    fi
    cat <<'JSON'
{"data":{"microsoft":{"value":[
  {"id":"MSG-QUOTE","conversationId":"C-QUOTE","subject":"Need quote for 24 hoodies","receivedDateTime":"2026-03-12T14:10:00Z","from":{"emailAddress":{"address":"newcustomer@example.com","name":"Alex Customer"}},"bodyPreview":"Need pricing for 24 black hoodies next week.","isRead":false},
  {"id":"MSG-ART","conversationId":"C-ART","subject":"Artwork attached for the new order","receivedDateTime":"2026-03-12T14:09:00Z","from":{"emailAddress":{"address":"artcustomer@example.com","name":"Ari Art"}},"bodyPreview":"See attached logo pdf for the order.","isRead":false},
  {"id":"MSG-PROOF","conversationId":"C-PROOF","subject":"Proof looks good with one change","receivedDateTime":"2026-03-12T14:08:00Z","from":{"emailAddress":{"address":"proofcustomer@example.com","name":"Pat Proof"}},"bodyPreview":"The proof looks good, but please move the back print up.","isRead":true},
  {"id":"FWD-REORDER","conversationId":"C-REORDER","subject":"FW: TowMaxx Towing shirts","receivedDateTime":"2026-03-12T14:07:00Z","from":{"emailAddress":{"address":"ronny@mintprints.com","name":"Ronny"}},"bodyPreview":"Forwarded TowMaxx reorder note.","isRead":false},
  {"id":"MSG-REORDER","conversationId":"C-REORDER","subject":"TowMaxx Towing shirts","receivedDateTime":"2026-03-12T14:06:00Z","from":{"emailAddress":{"address":"george@towmaxxtowing.com","name":"George Mouakar"}},"bodyPreview":"I want the same shirts as last time but black this time.","isRead":false},
  {"id":"MSG-VENDOR","conversationId":"C-VENDOR","subject":"FW: Sheik revision for PapaPalooza","receivedDateTime":"2026-03-12T14:05:00Z","from":{"emailAddress":{"address":"team@mintprints.com","name":"Mint Team"}},"bodyPreview":"Latest vendor revision is attached for the PapaPalooza correction pass.","isRead":false},
  {"id":"MSG-SPAM","conversationId":"C-SPAM","subject":"Jason Beeker / Hit Promo weekly deals","receivedDateTime":"2026-03-12T14:04:00Z","from":{"emailAddress":{"address":"jason@hitpromo.example","name":"Jason Beeker"}},"bodyPreview":"Special offer this week. Unsubscribe any time.","isRead":false},
  {"id":"MSG-INVITE","conversationId":"C-INVITE","subject":"Invitation: Routine maintenance planned","receivedDateTime":"2026-03-12T14:03:30Z","from":{"emailAddress":{"address":"alerts@mail.zapier.com","name":"Zapier Alerts"}},"bodyPreview":"Join with Google Meet. Meeting link included.","isRead":false},
  {"id":"MSG-UNICODE","conversationId":"C-UNICODE","subject":"All beauty, no beasts","receivedDateTime":"2026-03-12T14:03:15Z","from":{"emailAddress":{"address":"hello@everybody.world","name":"Everybody.World"}},"bodyPreview":"Oh, to be an enjoyer of wishes. ͏ ͏ ͏ ͏ ͏ ͏ ͏ ͏ ͏ ͏ ͏ ͏","isRead":false},
  {"id":"MSG-AMB","conversationId":"C-AMB","subject":"Checking in","receivedDateTime":"2026-03-12T14:03:00Z","from":{"emailAddress":{"address":"unknown@example.com","name":"Unknown"}},"bodyPreview":"Wanted to follow up.","isRead":false}
  {"id":"MSG-SENT","conversationId":"C-SENT","subject":"RE: Need quote for 24 hoodies","receivedDateTime":"2026-03-12T14:11:00Z","from":{"emailAddress":{"address":"team@mintprints.com","name":"Mint Team"}},"bodyPreview":"Greetings Alex, here's your quote.","isRead":true}
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
      MSG-QUOTE)
        cat <<'JSON'
{"id":"MSG-QUOTE","conversationId":"C-QUOTE","subject":"Need quote for 24 hoodies","receivedDateTime":"2026-03-12T14:10:00Z","from":{"emailAddress":{"address":"newcustomer@example.com","name":"Alex Customer"}},"bodyPreview":"Need pricing for 24 black hoodies next week.","body":{"contentType":"Text","content":"Can you quote 24 black hoodies for next week?"},"hasAttachments":false}
JSON
        ;;
      MSG-ART)
        cat <<'JSON'
{"id":"MSG-ART","conversationId":"C-ART","subject":"Artwork attached for the new order","receivedDateTime":"2026-03-12T14:09:00Z","from":{"emailAddress":{"address":"artcustomer@example.com","name":"Ari Art"}},"bodyPreview":"See attached logo pdf for the order.","body":{"contentType":"Text","content":"Attached logo pdf for the order. Please use this art file."},"hasAttachments":true}
JSON
        ;;
      MSG-PROOF)
        cat <<'JSON'
{"id":"MSG-PROOF","conversationId":"C-PROOF","subject":"Proof looks good with one change","receivedDateTime":"2026-03-12T14:08:00Z","from":{"emailAddress":{"address":"proofcustomer@example.com","name":"Pat Proof"}},"bodyPreview":"The proof looks good, but please move the back print up.","body":{"contentType":"Text","content":"The proof looks good, but please move the back print up before approval."},"hasAttachments":false}
JSON
        ;;
      FWD-REORDER)
        cat <<'JSON'
{"id":"FWD-REORDER","conversationId":"C-REORDER","subject":"FW: TowMaxx Towing shirts","receivedDateTime":"2026-03-12T14:07:00Z","from":{"emailAddress":{"address":"ronny@mintprints.com","name":"Ronny"}},"bodyPreview":"Forwarded TowMaxx reorder note.","body":{"contentType":"Text","content":"Please handle this forwarded TowMaxx reorder."},"hasAttachments":false}
JSON
        ;;
      MSG-REORDER)
        cat <<'JSON'
{"id":"MSG-REORDER","conversationId":"C-REORDER","subject":"TowMaxx Towing shirts","receivedDateTime":"2026-03-12T14:06:00Z","from":{"emailAddress":{"address":"george@towmaxxtowing.com","name":"George Mouakar"}},"bodyPreview":"I want the same shirts as last time but black this time.","body":{"contentType":"Text","content":"I want the same shirts as last time but black this time. We need 20 total."},"hasAttachments":false}
JSON
        ;;
      MSG-VENDOR)
        cat <<'JSON'
{"id":"MSG-VENDOR","conversationId":"C-VENDOR","subject":"FW: Sheik revision for PapaPalooza","receivedDateTime":"2026-03-12T14:05:00Z","from":{"emailAddress":{"address":"team@mintprints.com","name":"Mint Team"}},"bodyPreview":"Latest vendor revision is attached for the PapaPalooza correction pass.","body":{"contentType":"Text","content":"Latest vendor revision is attached for the PapaPalooza correction pass from Sheik."},"hasAttachments":true}
JSON
        ;;
      MSG-SPAM)
        cat <<'JSON'
{"id":"MSG-SPAM","conversationId":"C-SPAM","subject":"Jason Beeker / Hit Promo weekly deals","receivedDateTime":"2026-03-12T14:04:00Z","from":{"emailAddress":{"address":"jason@hitpromo.example","name":"Jason Beeker"}},"bodyPreview":"Special offer this week. Unsubscribe any time.","body":{"contentType":"Text","content":"Special offer this week. Unsubscribe any time."},"hasAttachments":false}
JSON
        ;;
      MSG-INVITE)
        cat <<'JSON'
{"id":"MSG-INVITE","conversationId":"C-INVITE","subject":"Invitation: Routine maintenance planned","receivedDateTime":"2026-03-12T14:03:30Z","from":{"emailAddress":{"address":"alerts@mail.zapier.com","name":"Zapier Alerts"}},"bodyPreview":"Join with Google Meet. Meeting link included.","body":{"contentType":"Text","content":"Join with Google Meet. Meeting link included. Scheduled maintenance is planned."},"hasAttachments":false}
JSON
        ;;
      MSG-UNICODE)
        cat <<'JSON'
{"id":"MSG-UNICODE","conversationId":"C-UNICODE","subject":"All beauty, no beasts","receivedDateTime":"2026-03-12T14:03:15Z","from":{"emailAddress":{"address":"hello@everybody.world","name":"Everybody.World"}},"bodyPreview":"Oh, to be an enjoyer of wishes. ͏ ͏ ͏ ͏ ͏ ͏ ͏ ͏ ͏ ͏ ͏ ͏","body":{"contentType":"Text","content":"Oh, to be an enjoyer of wishes. ͏ ͏ ͏ ͏ ͏ ͏ ͏ ͏ ͏ ͏ ͏ ͏ ͏ ͏ ͏ ͏ ͏ ͏ ͏"},"hasAttachments":false}
JSON
        ;;
      MSG-AMB)
        cat <<'JSON'
{"id":"MSG-AMB","conversationId":"C-AMB","subject":"Checking in","receivedDateTime":"2026-03-12T14:03:00Z","from":{"emailAddress":{"address":"unknown@example.com","name":"Unknown"}},"bodyPreview":"Wanted to follow up.","body":{"contentType":"Text","content":"Wanted to follow up."},"hasAttachments":false}
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

json_out="$("$WORK_ITEMS" --mailbox team@mintprints.com --top 20 --json)"
record_file="$(echo "$json_out" | jq -r '.record_file')"

[[ "$(echo "$json_out" | jq -r '.backlog_count')" == "9" ]] || fail "backlog should collapse into 9 Inbox thread work items"
[[ "$(echo "$json_out" | jq -r '.selection_order')" == "oldest_first" ]] || fail "selection order should default to oldest_first"
[[ -f "$record_file" ]] || fail "record file should exist"
[[ "$(echo "$json_out" | jq -r '.work_items[0].thread_id')" == "C-AMB" ]] || fail "oldest thread should appear first by default"
[[ "$(echo "$json_out" | jq -r '.work_items[-1].thread_id')" == "C-QUOTE" ]] || fail "newest thread should appear last by default"

quote_type="$(echo "$json_out" | jq -r '.work_items[] | select(.thread_id=="C-QUOTE") | .work_type')"
quote_gate="$(echo "$json_out" | jq -r '.work_items[] | select(.thread_id=="C-QUOTE") | .gate_status')"
quote_intake_file="$(echo "$json_out" | jq -r '.work_items[] | select(.thread_id=="C-QUOTE") | .intake_record.record_file')"
reorder_customer="$(echo "$json_out" | jq -r '.work_items[] | select(.thread_id=="C-REORDER") | .customer_status')"
reorder_assets="$(echo "$json_out" | jq -r '.work_items[] | select(.thread_id=="C-REORDER") | .asset_history_status')"
reorder_step="$(echo "$json_out" | jq -r '.work_items[] | select(.thread_id=="C-REORDER") | .next_business_step')"
spam_step="$(echo "$json_out" | jq -r '.work_items[] | select(.thread_id=="C-SPAM") | .next_business_step')"
spam_disposition="$(echo "$json_out" | jq -r '.work_items[] | select(.thread_id=="C-SPAM") | .disposition')"
spam_visible="$(echo "$json_out" | jq -r '.work_items[] | select(.thread_id=="C-SPAM") | .primary_queue_visible')"
spam_folder="$(echo "$json_out" | jq -r '.work_items[] | select(.thread_id=="C-SPAM") | .recoverable_folder')"
invite_disposition="$(echo "$json_out" | jq -r '.work_items[] | select(.thread_id=="C-INVITE") | .disposition')"
invite_visible="$(echo "$json_out" | jq -r '.work_items[] | select(.thread_id=="C-INVITE") | .primary_queue_visible')"
unicode_disposition="$(echo "$json_out" | jq -r '.work_items[] | select(.thread_id=="C-UNICODE") | .disposition')"
unicode_visible="$(echo "$json_out" | jq -r '.work_items[] | select(.thread_id=="C-UNICODE") | .primary_queue_visible')"
sent_present="$(echo "$json_out" | jq -r '[.work_items[] | select(.thread_id=="C-SENT")] | length')"
art_type="$(echo "$json_out" | jq -r '.work_items[] | select(.thread_id=="C-ART") | .work_type')"
proof_type="$(echo "$json_out" | jq -r '.work_items[] | select(.thread_id=="C-PROOF") | .work_type')"
vendor_type="$(echo "$json_out" | jq -r '.work_items[] | select(.thread_id=="C-VENDOR") | .work_type')"
vendor_disposition="$(echo "$json_out" | jq -r '.work_items[] | select(.thread_id=="C-VENDOR") | .disposition')"
vendor_truth_allowed="$(echo "$json_out" | jq -r '.work_items[] | select(.thread_id=="C-VENDOR") | .customer_truth_allowed')"
amb_type="$(echo "$json_out" | jq -r '.work_items[] | select(.thread_id=="C-AMB") | .work_type')"
amb_disposition="$(echo "$json_out" | jq -r '.work_items[] | select(.thread_id=="C-AMB") | .disposition')"
quote_disposition="$(echo "$json_out" | jq -r '.work_items[] | select(.thread_id=="C-QUOTE") | .disposition')"

[[ "$quote_type" == "quote_request" ]] || fail "quote thread should classify as quote_request"
[[ "$quote_disposition" == "customer_actionable" ]] || fail "quote thread should resolve to customer_actionable"
[[ "$quote_gate" == "go" ]] || fail "customer_actionable intake should be ready to enter the module lane"
[[ -f "$quote_intake_file" ]] || fail "quote thread should write the immutable intake record before any deeper work"
[[ "$art_type" == "art_delivery" ]] || fail "art thread should classify as art_delivery"
[[ "$proof_type" == "proof_review" ]] || fail "proof thread should classify as proof_review"
[[ "$vendor_type" == "vendor_revision" ]] || fail "vendor thread should classify as vendor_revision"
[[ "$vendor_disposition" == "vendor_revision" ]] || fail "vendor thread should route outside the customer lane"
[[ "$vendor_truth_allowed" == "false" ]] || fail "vendor revision should never be allowed to create customer truth"
[[ "$amb_type" == "ambiguous" ]] || fail "ambiguous thread should remain ambiguous"
[[ "$amb_disposition" == "waiting_on_customer" ]] || fail "ambiguous thread should stay in waiting_on_customer until the customer clarifies"
[[ "$reorder_customer" == "existing" ]] || fail "TowMaxx reorder should resolve as existing customer"
[[ "$reorder_assets" == "found" ]] || fail "TowMaxx reorder should resolve history/assets"
[[ "$reorder_step" == "customer_clarification" ]] || fail "TowMaxx reorder should stop at customer clarification when quote is not ready"
[[ "$spam_disposition" == "supplier_marketing" ]] || fail "supplier/promo mail should leave the primary customer lane"
[[ "$spam_visible" == "false" ]] || fail "supplier marketing should be hidden from the primary queue"
[[ "$spam_step" == "route_supplier_marketing" ]] || fail "supplier marketing should route to the recoverable supplier lane"
[[ "$spam_folder" == "Supplier Marketing" ]] || fail "supplier marketing should route into the recoverable supplier-marketing folder"
[[ "$invite_disposition" == "supplier_marketing" ]] || fail "calendar/system invite mail should leave the customer lane"
[[ "$invite_visible" == "false" ]] || fail "calendar/system invite mail should be hidden from the primary queue"
[[ "$unicode_disposition" == "risky_junk" ]] || fail "unicode-garbage mail should route to risky_junk"
[[ "$unicode_visible" == "false" ]] || fail "unicode-garbage mail should be hidden from the primary queue"
[[ "$sent_present" == "0" ]] || fail "mailbox-global sent echoes should not appear when the queue reads Inbox scope"

pass "customer-inbox-work-items writes immutable intake anchors, routes vendor/promotional noise out of the customer lane, and keeps the backlog operator-first"

: >"$FAKE_OPS_LOG"
preview_json="$("$WORK_ITEMS" --mailbox team@mintprints.com --top 20 --preview-only --json)"
[[ "$(echo "$preview_json" | jq -r '.hydration_mode')" == "preview_only" ]] || fail "preview-only mode should be reported in the summary"
[[ "$(echo "$preview_json" | jq -r '.work_items[] | select(.thread_id=="C-ART") | .work_type')" == "art_delivery" ]] || fail "preview-only mode should still classify art delivery from preview text"
[[ "$(echo "$preview_json" | jq -r '.work_items[] | select(.thread_id=="C-QUOTE") | .work_type')" == "quote_request" ]] || fail "preview-only mode should still classify quote requests from preview text"
if grep '^microsoft.mail.get ' "$FAKE_OPS_LOG" >/dev/null; then
  fail "preview-only work-items should not hydrate messages with microsoft.mail.get"
fi

pass "customer-inbox-work-items preview-only mode skips full message hydration while preserving operator classification"

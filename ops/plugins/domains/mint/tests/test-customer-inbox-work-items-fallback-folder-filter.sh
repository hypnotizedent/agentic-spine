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
export MINT_CUSTOMER_INBOX_DISPOSITION_CONTRACT="$DISPOSITION_CONTRACT"
export MINT_CUSTOMER_QUOTE_INTAKE_CONTRACT="$QUOTE_INTAKE_CONTRACT"
export MINT_CUSTOMER_REORDER_CUSTOMERS_EXPORT="$tmp/customers.csv"
export MINT_CUSTOMER_REORDER_ORDERS_EXPORT="$tmp/orders.csv"
export MINT_CUSTOMER_REORDER_CLIENT_ASSETS_ROOT="$tmp/client-assets"
mkdir -p "$SPINE_ROOT/bin" "$SPINE_STATE" "$MINT_CUSTOMER_REORDER_CLIENT_ASSETS_ROOT"

cat >"$MINT_CUSTOMER_REORDER_CUSTOMERS_EXPORT" <<'CSV'
Customer ID,First Name,Last Name,Company,Email,Phone,Created
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
    echo "simulated failure" >&2
    exit 1
    ;;
  microsoft.mail.folders)
    cat <<'JSON'
{"folders":[
  {"id":"F-INBOX","displayName":"Inbox","totalItemCount":10,"unreadItemCount":2},
  {"id":"F-DRAFTS","displayName":"Drafts","totalItemCount":1,"unreadItemCount":0},
  {"id":"F-SENT","displayName":"Sent Items","totalItemCount":5,"unreadItemCount":0},
  {"id":"F-DELETED","displayName":"Deleted Items","totalItemCount":3,"unreadItemCount":0}
]}
JSON
    ;;
  communications.mail.search)
    cat <<'JSON'
{"data":{"microsoft":{"value":[
  {"id":"MSG-INBOX-CUST","conversationId":"C-CUST","subject":"Need pricing for 48 tees","receivedDateTime":"2026-03-17T14:00:00Z","from":{"emailAddress":{"address":"buyer@example.com","name":"Buyer"}},"bodyPreview":"Need pricing for 48 tees.","parentFolderId":"F-INBOX","isRead":false},
  {"id":"MSG-DRAFT-PHUSE","conversationId":"C-CUST","subject":"RE: Need pricing for 48 tees","receivedDateTime":"2026-03-17T14:05:00Z","from":{"emailAddress":{"address":"team@mintprints.com","name":"Mint Team"}},"bodyPreview":"Greetings Buyer, here's your quote.","parentFolderId":"F-DRAFTS","isRead":true},
  {"id":"MSG-SENT-PHUSE","conversationId":"C-CUST","subject":"RE: Need pricing for 48 tees","receivedDateTime":"2026-03-17T14:06:00Z","from":{"emailAddress":{"address":"team@mintprints.com","name":"Mint Team"}},"bodyPreview":"Greetings Buyer, here's your quote.","parentFolderId":"F-SENT","isRead":true},
  {"id":"MSG-DELETED-PHUSE","conversationId":"C-CUST","subject":"13846 Buyer Quote","receivedDateTime":"2026-03-17T14:07:00Z","from":{"emailAddress":{"address":"team@mintprints.com","name":"Mint Team"}},"bodyPreview":"Older deleted draft.","parentFolderId":"F-DELETED","isRead":true}
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
      MSG-INBOX-CUST)
        cat <<'JSON'
{"id":"MSG-INBOX-CUST","conversationId":"C-CUST","subject":"Need pricing for 48 tees","receivedDateTime":"2026-03-17T14:00:00Z","from":{"emailAddress":{"address":"buyer@example.com","name":"Buyer"}},"bodyPreview":"Need pricing for 48 tees.","body":{"contentType":"Text","content":"Need pricing for 48 tees."},"hasAttachments":false}
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

[[ "$(echo "$json_out" | jq -r '.backlog_count')" == "1" ]] || fail "fallback search should keep only inbox-scoped messages"
[[ "$(echo "$json_out" | jq -r '.work_items[0].effective_message_id')" == "MSG-INBOX-CUST" ]] || fail "customer message should remain the effective inbox item"
[[ "$(echo "$json_out" | jq -r '.work_items[0].source_message_ids | join(",")')" == "MSG-INBOX-CUST" ]] || fail "draft/sent/deleted echoes must not contaminate source message ids"

pass "customer-inbox-work-items fallback search excludes Drafts, Sent Items, and Deleted Items by folder scope"

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
mkdir -p "$SPINE_ROOT/bin" "$SPINE_STATE/mint/customer-history-restores" "$MINT_CUSTOMER_REORDER_CLIENT_ASSETS_ROOT"

cat >"$MINT_CUSTOMER_REORDER_CUSTOMERS_EXPORT" <<'CSV'
Customer ID,First Name,Last Name,Company,Email,Phone,Created
1001,Lilian,Perez,FIU,lilperez@fiu.edu,+10000000000,2025-11-05 11:32:55 -0500
CSV

cat >"$MINT_CUSTOMER_REORDER_ORDERS_EXPORT" <<'CSV'
Invoice #,Nickname,Created Date,Production Due Date,Customer Full Name,Customer Email,Customer Company,Customer Id,Total Quantity,Paid?,Invoice Status,Public Invoice View URL,Invoice URL
13623,FIU shirts,2025-11-05,2025-11-05,Lilian Perez,lilperez@fiu.edu,FIU,1001,24,true,COMPLETE,https://example.test/public/13623,https://example.test/internal/13623
CSV

cat >"$SPINE_STATE/mint/customer-history-restores/index.ndjson" <<'JSON'
{"internetMessageId":"<history-1@example.com>","record_file":"/tmp/history.json"}
JSON

cat >"$SPINE_ROOT/bin/ops" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

capability="${3:-}"
shift 3 || true
if [[ "${1:-}" == "--" ]]; then
  shift
fi

case "$capability" in
  microsoft.mail.folder.messages)
    cat <<'JSON'
{"value":[
  {"id":"MSG-HISTORY","conversationId":"C-HISTORY","internetMessageId":"<history-1@example.com>","subject":"Re: Green School Student T-shirts","receivedDateTime":"2025-12-22T16:38:41Z","from":{"emailAddress":{"address":"lilperez@fiu.edu","name":"Lilian Perez"}},"bodyPreview":"Old recovered history message.","isRead":true},
  {"id":"MSG-LIVE","conversationId":"C-LIVE","internetMessageId":"<live-1@example.com>","subject":"Green School Student T-shirts","receivedDateTime":"2026-03-16T17:27:08Z","from":{"emailAddress":{"address":"lilperez@fiu.edu","name":"Lilian Perez"}},"bodyPreview":"Current live customer reply.","isRead":false}
]}
JSON
    ;;
  microsoft.mail.get)
    cat <<'JSON'
{"id":"MSG-LIVE","conversationId":"C-LIVE","internetMessageId":"<live-1@example.com>","subject":"Green School Student T-shirts","receivedDateTime":"2026-03-16T17:27:08Z","from":{"emailAddress":{"address":"lilperez@fiu.edu","name":"Lilian Perez"}},"body":{"contentType":"Text","content":"Current live customer reply."},"bodyPreview":"Current live customer reply.","hasAttachments":false}
JSON
    ;;
  *)
    echo "unsupported capability: $capability" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$SPINE_ROOT/bin/ops"

json_out="$("$WORK_ITEMS" --mailbox team@mintprints.com --top 10 --json)"

[[ "$(echo "$json_out" | jq -r '.backlog_count')" == "1" ]] || fail "restored history items should be shielded from the live work queue"
[[ "$(echo "$json_out" | jq -r '.work_items[0].effective_message_id')" == "MSG-LIVE" ]] || fail "live message should remain as the only actionable queue item"
[[ "$(echo "$json_out" | jq -r '[.work_items[] | select(.effective_message_id=="MSG-HISTORY")] | length')" == "0" ]] || fail "restored history message should not surface as work"

pass "customer-inbox-work-items shields restored legacy history from the team@ work queue"

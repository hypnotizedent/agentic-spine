#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
RESOLVE="$ROOT/ops/plugins/domains/mint/bin/customer-reorder-resolve"
MAILBOX_STANDARD_CONTRACT="$ROOT/ops/bindings/mint.customer.mailbox.standard.contract.yaml"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || fail "jq required"
[[ -x "$RESOLVE" ]] || fail "missing customer-reorder-resolve executable"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export SPINE_ROOT="$tmp/spine"
export SPINE_STATE="$tmp/state"
export MINT_CUSTOMER_MAILBOX_STANDARD_CONTRACT="$MAILBOX_STANDARD_CONTRACT"
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
printf 'mock' >"$MINT_CUSTOMER_REORDER_CLIENT_ASSETS_ROOT/George Mouakar/13623 TowMaxx towing polos/1200W-60487-DeepBlack-12-K200PDeepBlackFlatFront.jpg"
printf '%s\n' 'dummy pdf' >"$MINT_CUSTOMER_REORDER_CLIENT_ASSETS_ROOT/George Mouakar/13623 TowMaxx towing polos/13623 TowMaxx towing polos.pdf"

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
      FWD-1)
        cat <<'JSON'
{"id":"FWD-1","subject":"FW: TowMaxx Towing polos","receivedDateTime":"2026-03-11T16:00:00Z","bodyPreview":"Forwarded message from George about TowMaxx polos.","body":{"contentType":"Text","content":"Please handle this.\n\nFrom: George Mouakar <george@towmaxxtowing.com>\nSubject: TowMaxx Towing polos\n"},"from":{"emailAddress":{"address":"ronny@mintprints.com","name":"Ronny"}}}
JSON
        ;;
      MSG-DIRECT)
        cat <<'JSON'
{"id":"MSG-DIRECT","subject":"TowMaxx Towing polos","receivedDateTime":"2026-03-11T15:42:04Z","bodyPreview":"I want to do the same polos as my last order but black this time!","body":{"contentType":"Text","content":"I need to order:\n5 M\n4 L\n5 XL\n4 XXL\n2 XXXL\n\nI want to do the same polos as my last order but black this time!"},"from":{"emailAddress":{"address":"george@towmaxxtowing.com","name":"George Mouakar"}}}
JSON
        ;;
      MSG-OLD)
        cat <<'JSON'
{"id":"MSG-OLD","subject":"TowMaxx towing polos","receivedDateTime":"2025-11-05T15:00:00Z","bodyPreview":"Old TowMaxx order","body":{"contentType":"Text","content":"Previous TowMaxx order confirmation."},"from":{"emailAddress":{"address":"george@towmaxxtowing.com","name":"George Mouakar"}}}
JSON
        ;;
      *)
        echo "unexpected message id: $message_id" >&2
        exit 1
        ;;
    esac
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
    case "$query" in
      "TowMaxx Towing polos")
        cat <<'JSON'
{"data":{"microsoft":{"value":[{"id":"MSG-DIRECT","subject":"TowMaxx Towing polos","receivedDateTime":"2026-03-11T15:42:04Z","from":{"emailAddress":{"address":"george@towmaxxtowing.com","name":"George Mouakar"}}},{"id":"FWD-1","subject":"FW: TowMaxx Towing polos","receivedDateTime":"2026-03-11T16:00:00Z","from":{"emailAddress":{"address":"ronny@mintprints.com","name":"Ronny"}}}]}}}
JSON
        ;;
      "george@towmaxxtowing.com")
        cat <<'JSON'
{"data":{"microsoft":{"value":[{"id":"MSG-DIRECT","subject":"TowMaxx Towing shirts","receivedDateTime":"2026-03-11T15:42:04Z","from":{"emailAddress":{"address":"george@towmaxxtowing.com","name":"George Mouakar"}}},{"id":"MSG-OLD","subject":"TowMaxx towing polos","receivedDateTime":"2025-11-05T15:00:00Z","from":{"emailAddress":{"address":"george@towmaxxtowing.com","name":"George Mouakar"}}}]}}}
JSON
        ;;
      *)
        cat <<'JSON'
{"data":{"microsoft":{"value":[]}}}
JSON
        ;;
    esac
    ;;
  mint.customer.reply.draft)
    body=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --body) body="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    printf '%s' "$body" >"$SPINE_STATE/reorder-reply-body.txt"
    cat <<'JSON'
{"data":{"reply_draft_id":"MRD-TEST-1234","draft_id":"DRAFT-1234","record_file":"/tmp/customer-reply-record.json","draft_subject":"Re: TowMaxx Towing shirts","draft_to":"george@towmaxxtowing.com"}}
JSON
    ;;
  *)
    echo "unsupported capability: $capability" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$SPINE_ROOT/bin/ops"

json_out="$("$RESOLVE" FWD-1 --mailbox team@mintprints.com --json)"
record_file="$(echo "$json_out" | jq -r '.record_file')"
index_file="$(echo "$json_out" | jq -r '.index_file')"
work_type="$(echo "$json_out" | jq -r '.work_type')"
effective_message_id="$(echo "$json_out" | jq -r '.effective_message_id')"
prior_job="$(echo "$json_out" | jq -r '.matched_prior_job.summary')"
requested_color="$(echo "$json_out" | jq -r '.changed.requested_color.current')"
requested_total="$(echo "$json_out" | jq -r '.changed.requested_total_quantity')"
work_object_state="$(echo "$json_out" | jq -r '.work_object_state')"
reply_draft_id="$(echo "$json_out" | jq -r '.reply_draft.reply_draft_id')"
reply_body="$SPINE_STATE/reorder-reply-body.txt"

[[ "$work_type" == "reorder" ]] || fail "work_type should classify as reorder"
[[ "$effective_message_id" == "MSG-DIRECT" ]] || fail "resolver should switch from forwarded wrapper to direct customer message"
[[ "$prior_job" == "13623 TowMaxx towing polos" ]] || fail "resolver should match the historical TowMaxx job"
[[ "$requested_color" == "black" ]] || fail "resolver should capture requested color"
[[ "$requested_total" == "20" ]] || fail "resolver should total the size breakdown"
[[ "$work_object_state" == "draft_ready" ]] || fail "resolver should keep a blocker-free reorder transactional"
[[ "$reply_draft_id" == "MRD-TEST-1234" ]] || fail "resolver should create a reply draft from the governed object"
[[ -f "$record_file" ]] || fail "record file should exist"
[[ -f "$index_file" ]] || fail "index file should exist"
grep -F 'Got the reorder for 20 pieces.' "$reply_body" >/dev/null || fail "reorder reply should confirm the reorder transactionally"
grep -F 'What due date do you need for this reorder?' "$reply_body" >/dev/null && fail "reorder reply should not ask for a due date by default"
grep -F '13623 TowMaxx towing polos' "$reply_body" >/dev/null && fail "reorder reply should not restate the historical design/job name"
[[ "$(jq -r '.receipts.thread_search_receipt' "$record_file")" == "/tmp/communications.mail.search.receipt.md" ]] || fail "record should keep thread search receipt"
[[ "$(jq -r '.receipts.effective_get_receipt' "$record_file")" == "/tmp/microsoft.mail.get.receipt.md" ]] || fail "record should keep effective message receipt"
[[ "$(jq -r '.receipts.reply_draft_receipt' "$record_file")" == "/tmp/mint.customer.reply.draft.receipt.md" ]] || fail "record should keep reply draft receipt"
grep -F '"reorder_id"' "$index_file" >/dev/null || fail "index should record reorder entry"
pass "customer-reorder-resolve keeps reordered customer replies transactional and free of default due-date/design restatement drift"

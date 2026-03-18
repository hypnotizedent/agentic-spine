#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
BIN="$ROOT/ops/plugins/domains/mint/bin/customer-inbox-first-email"
CONTRACT="$ROOT/ops/bindings/mint.customer.inbox.startup.contract.yaml"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || fail "jq required"
[[ -x "$BIN" ]] || fail "missing customer-inbox-first-email executable"
[[ -f "$CONTRACT" ]] || fail "missing startup contract"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fake_spine="$tmp/spine"
fake_state="$tmp/state"
ops_log="$tmp/ops.log"
mkdir -p "$fake_spine/bin" "$fake_state/sessions/SES-FIRST-001" "$fake_state/sessions/SES-FIRST-002"

cat >"$fake_state/sessions/SES-FIRST-001/session.yaml" <<EOF
id: SES-FIRST-001
pid: $$
EOF

cat >"$fake_state/sessions/SES-FIRST-002/session.yaml" <<EOF
id: SES-FIRST-002
pid: $$
EOF

cat >"$fake_spine/bin/ops" <<'EOF'
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

message_id=""
email=""
mailbox=""
query=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --message-id) message_id="${2:-}"; shift 2 ;;
    --email) email="${2:-}"; shift 2 ;;
    --mailbox) mailbox="${2:-}"; shift 2 ;;
    --query) query="${2:-}"; shift 2 ;;
    *) shift ;;
  esac
done

case "$capability" in
  mint.customer.inbox.work_items)
    cat <<'JSON'
{"mailbox":"team@mintprints.com","backlog_count":3,"selection_order":"oldest_first","work_items":[
  {"thread_id":"C-OLD","effective_message_id":"MSG-OLD","subject":"Oldest quote request","work_type":"quote_request","disposition":"customer_actionable","gate_status":"go","from":"oldest@example.com","primary_queue_visible":true,"customer_truth_allowed":true,"customer_status":"new","customer_summary":"Alex Customer","asset_history_status":"missing","next_business_step":"customer_clarification","confidence":"medium","message_anchor":{"mailbox":"team@mintprints.com","message_id":"MSG-OLD","conversation_id":"C-OLD","from":"oldest@example.com","subject":"Oldest quote request","received_at":"2026-03-11T09:00:00Z","normalized_latest_customer_text":"Need 24 hoodies next week."},"intake_record":{"intake_id":"MCII-OLD","record_file":"/tmp/fake-state/mint/customer-inbox-intakes/records/2026/03/11/MCII-OLD.json"}},
  {"thread_id":"C-NEXT","effective_message_id":"MSG-NEXT","subject":"Second quote request","work_type":"quote_request","disposition":"customer_actionable","gate_status":"go","from":"second@example.com","primary_queue_visible":true,"customer_truth_allowed":true,"customer_status":"new","customer_summary":"Blake Buyer","asset_history_status":"missing","next_business_step":"customer_clarification","confidence":"medium","message_anchor":{"mailbox":"team@mintprints.com","message_id":"MSG-NEXT","conversation_id":"C-NEXT","from":"second@example.com","subject":"Second quote request","received_at":"2026-03-11T10:00:00Z","normalized_latest_customer_text":"Need 36 tees."},"intake_record":{"intake_id":"MCII-NEXT","record_file":"/tmp/fake-state/mint/customer-inbox-intakes/records/2026/03/11/MCII-NEXT.json"}},
  {"thread_id":"C-THIRD","effective_message_id":"MSG-THIRD","subject":"Third quote request","work_type":"quote_request","disposition":"customer_actionable","gate_status":"go","from":"third@example.com","primary_queue_visible":true,"customer_truth_allowed":true,"customer_status":"new","customer_summary":"Casey Client","asset_history_status":"missing","next_business_step":"customer_clarification","confidence":"medium","message_anchor":{"mailbox":"team@mintprints.com","message_id":"MSG-THIRD","conversation_id":"C-THIRD","from":"third@example.com","subject":"Third quote request","received_at":"2026-03-11T11:00:00Z","normalized_latest_customer_text":"Need 12 polos."},"intake_record":{"intake_id":"MCII-THIRD","record_file":"/tmp/fake-state/mint/customer-inbox-intakes/records/2026/03/11/MCII-THIRD.json"}}
]}
JSON
    ;;
  microsoft.mail.get)
    case "$message_id" in
      MSG-OLD)
        cat <<'JSON'
{"id":"MSG-OLD","conversationId":"C-OLD","subject":"Oldest quote request","receivedDateTime":"2026-03-11T09:00:00Z","from":{"emailAddress":{"address":"oldest@example.com","name":"Alex Customer"}},"bodyPreview":"Need 24 hoodies next week.","body":{"contentType":"Text","content":"Need 24 hoodies next week. Can you quote them?"},"hasAttachments":false}
JSON
        ;;
      MSG-NEXT)
        cat <<'JSON'
{"id":"MSG-NEXT","conversationId":"C-NEXT","subject":"Second quote request","receivedDateTime":"2026-03-11T10:00:00Z","from":{"emailAddress":{"address":"second@example.com","name":"Blake Buyer"}},"bodyPreview":"Need 36 tees.","body":{"contentType":"Text","content":"Need 36 tees and pricing for next Friday."},"hasAttachments":false}
JSON
        ;;
      MSG-THIRD)
        cat <<'JSON'
{"id":"MSG-THIRD","conversationId":"C-THIRD","subject":"Third quote request","receivedDateTime":"2026-03-11T11:00:00Z","from":{"emailAddress":{"address":"third@example.com","name":"Casey Client"}},"bodyPreview":"Need 12 polos.","body":{"contentType":"Text","content":"Need 12 polos next week."},"hasAttachments":false}
JSON
        ;;
      *)
        echo "unexpected message id: $message_id" >&2
        exit 1
        ;;
    esac
    ;;
  mint.customer.record.snapshot)
    case "$email" in
      oldest@example.com)
        cat <<'JSON'
{"data":{"agent_state":{"state":"no_record_found"},"fresh_slate":{"identity":{"display_name":"Alex Customer"},"customer":{"company":"Alex Co"},"latest_seed":null},"legacy_hold":{}}}
JSON
        ;;
      second@example.com)
        cat <<'JSON'
{"data":{"agent_state":{"state":"no_record_found"},"fresh_slate":{"identity":{"display_name":"Blake Buyer"},"customer":{"company":"Buyer LLC"},"latest_seed":null},"legacy_hold":{}}}
JSON
        ;;
      third@example.com)
        cat <<'JSON'
{"data":{"agent_state":{"state":"no_record_found"},"fresh_slate":{"identity":{"display_name":"Casey Client"},"customer":{"company":"Client Inc"},"latest_seed":null},"legacy_hold":{}}}
JSON
        ;;
      *)
        echo "unexpected email: $email" >&2
        exit 1
        ;;
    esac
    ;;
  communications.mail.search)
    case "$mailbox:$query" in
      "team@mintprints.com:oldest@example.com")
        cat <<'JSON'
{"data":{"microsoft":{"value":[
  {"id":"MSG-OLD-HIST-TEAM","conversationId":"C-OLD-HIST-TEAM","internetMessageId":"<hist-team@example.com>","subject":"Original hoodie request","receivedDateTime":"2026-03-10T09:00:00Z","from":{"emailAddress":{"address":"oldest@example.com","name":"Alex Customer"}},"bodyPreview":"Original team mailbox ask"}
]}}}
JSON
        ;;
      *)
        echo "unexpected history search: mailbox=$mailbox query=$query" >&2
        exit 1
        ;;
    esac
    ;;
  communications.mailarchiver.search)
    cat <<'JSON'
{"data":{"messages":[
  {"id":"mailarchiver:501","archiveMailbox":"team@mintprints.com","history_lane":"mail_archiver","internetMessageId":"<hist-archive-info@example.com>","subject":"Legacy info mailbox history","receivedDateTime":"2026-03-08T09:00:00Z","from":{"emailAddress":{"address":"oldest@example.com","name":"Alex Customer"}},"toRecipients":[{"emailAddress":{"address":"info@mintprints.com"}}],"ccRecipients":[],"bodyPreview":"Legacy info mailbox history","body":{"contentType":"Text","content":"Legacy info mailbox history"}},
  {"id":"mailarchiver:502","archiveMailbox":"ronny@mintprints.com","history_lane":"mail_archiver","internetMessageId":"<hist-archive-ronny@example.com>","subject":"Executive safety copy history","receivedDateTime":"2026-03-07T09:00:00Z","from":{"emailAddress":{"address":"oldest@example.com","name":"Alex Customer"}},"toRecipients":[{"emailAddress":{"address":"ronny@mintprints.com"}}],"ccRecipients":[],"bodyPreview":"Executive safety copy history","body":{"contentType":"Text","content":"Executive safety copy history"}}
]}}
JSON
    ;;
  mint.customer.seed.ensure)
    case "$message_id" in
      MSG-OLD)
        cat <<'JSON'
{"action":"created","customer_display_name":"Alex Customer","seed":{"id":"seed-old"}}
JSON
        ;;
      MSG-NEXT)
        cat <<'JSON'
{"action":"created","customer_display_name":"Blake Buyer","seed":{"id":"seed-next"}}
JSON
        ;;
      MSG-THIRD)
        cat <<'JSON'
{"action":"created","customer_display_name":"Casey Client","seed":{"id":"seed-third"}}
JSON
        ;;
      *)
        echo "unexpected seed ensure message id: $message_id" >&2
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
chmod +x "$fake_spine/bin/ops"

env_common=(
  "SPINE_ROOT=$fake_spine"
  "SPINE_STATE=$fake_state"
  "OPS_TERMINAL_ROLE=MINT-MORPHEUS-01"
  "FAKE_OPS_LOG=$ops_log"
  "MINT_CUSTOMER_INBOX_STARTUP_CONTRACT=$CONTRACT"
)

first_json="$(
  env "${env_common[@]}" SPINE_SESSION_ID="SES-FIRST-001" "$BIN" --mailbox team@mintprints.com --json
)"
[[ "$(echo "$first_json" | jq -r '.selected_item.effective_message_id')" == "MSG-OLD" ]] || fail "first session should claim the oldest eligible email"
[[ "$(echo "$first_json" | jq -r '.claim_status')" == "claimed" ]] || fail "first claim should be new"
[[ "$(echo "$first_json" | jq -r '.operator_report.disposition')" == "customer_actionable" ]] || fail "first email should surface the canonical disposition"
[[ "$(echo "$first_json" | jq -r '.operator_report.gate_status')" == "go" ]] || fail "first email should carry the intake/disposition gate status"
[[ "$(echo "$first_json" | jq -r '.operator_report.customer_identity.display_name')" == "Alex Customer" ]] || fail "first email should surface the governed customer name"
[[ "$(echo "$first_json" | jq -r '.operator_report.customer_identity.company')" == "Alex Co" ]] || fail "first email should surface the governed customer company"
[[ "$(echo "$first_json" | jq -r '.operator_report.draft_eligible')" == "false" ]] || fail "first email should stay report-first and draft-ineligible"
[[ "$(echo "$first_json" | jq -r '.operator_report.mailbox_history.count')" == "3" ]] || fail "first email should carry governed cross-mailbox history count"
[[ "$(echo "$first_json" | jq -r '.operator_report.mailbox_history.source_mailboxes | index("team@mintprints.com")')" != "null" ]] || fail "first email should carry team mailbox history visibility"
[[ "$(echo "$first_json" | jq -r '.operator_report.mailbox_history.source_mailboxes | index("ronny@mintprints.com")')" != "null" ]] || fail "first email should carry ronny mailbox history visibility"
[[ "$(echo "$first_json" | jq -r '.operator_briefing.Confirmed')" == *"prior history=3 across"* ]] || fail "first email confirmed summary should surface prior history"

repeat_json="$(
  env "${env_common[@]}" SPINE_SESSION_ID="SES-FIRST-001" "$BIN" --mailbox team@mintprints.com --json
)"
[[ "$(echo "$repeat_json" | jq -r '.claim_status')" == "reused_existing_claim" ]] || fail "repeat first-email should reuse the active session claim"
[[ "$(echo "$repeat_json" | jq -r '.selected_item.effective_message_id')" == "MSG-OLD" ]] || fail "repeat first-email should stay on the same claimed email"

parallel_json="$(
  env "${env_common[@]}" SPINE_SESSION_ID="SES-FIRST-002" "$BIN" --mailbox team@mintprints.com --json
)"
[[ "$(echo "$parallel_json" | jq -r '.selected_item.effective_message_id')" == "MSG-NEXT" ]] || fail "second session should skip the first session's claimed email"

advance_json="$(
  env "${env_common[@]}" SPINE_SESSION_ID="SES-FIRST-001" "$BIN" --mailbox team@mintprints.com --advance --json
)"
[[ "$(echo "$advance_json" | jq -r '.claim_status')" == "advanced_claim" ]] || fail "advance should release the current claim before taking the next email"
[[ "$(echo "$advance_json" | jq -r '.released_claim.message_id')" == "MSG-OLD" ]] || fail "advance should report the released claim"
[[ "$(echo "$advance_json" | jq -r '.selected_item.effective_message_id')" == "MSG-THIRD" ]] || fail "advance should move to the next unclaimed oldest email"
grep '^mint.customer.inbox.work_items --mailbox team@mintprints.com --top 25 --json --preview-only$' "$ops_log" >/dev/null || fail "first-email should source preview-only work items"
grep '^microsoft.mail.get --message-id MSG-OLD --mailbox team@mintprints.com$' "$ops_log" >/dev/null || fail "first-email should explicitly hydrate the selected message"
grep '^communications.mail.search --json --query oldest@example.com --top 5 --mailbox team@mintprints.com$' "$ops_log" >/dev/null || fail "first-email should search team mailbox history"
grep '^communications.mailarchiver.search --json --query oldest@example.com --top 5 --mailbox team@mintprints.com --mailbox ronny@mintprints.com$' "$ops_log" >/dev/null || fail "first-email should search governed archive history"
if grep '^mint.customer.seed.ensure ' "$ops_log" >/dev/null; then
  fail "first-email should not create or mutate customer truth during queue selection"
fi

pass "customer-inbox-first-email stays record-first, carries governed mailbox history, avoids seed mutation, and preserves session-based queue claims"

echo "customer-inbox-first-email tests"

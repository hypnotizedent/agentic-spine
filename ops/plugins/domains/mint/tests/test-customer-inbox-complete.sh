#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
COMPLETE="$ROOT/ops/plugins/domains/mint/bin/customer-inbox-complete"
MACHINE_CONTRACT="$ROOT/ops/bindings/mint.customer.inbox.machine.contract.yaml"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || fail "jq required"
[[ -x "$COMPLETE" ]] || fail "missing customer-inbox-complete executable"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export SPINE_ROOT="$tmp/spine"
export SPINE_STATE="$tmp/state"
export MINT_CUSTOMER_INBOX_MACHINE_CONTRACT="$MACHINE_CONTRACT"
mkdir -p "$SPINE_ROOT/bin" "$SPINE_STATE/mint/customer-inbox-items/current" "$SPINE_STATE/mint/customer-inbox-items/by-message-id" "$SPINE_STATE/mint/customer-reply-drafts/records/2026/03/17"

cat >"$SPINE_ROOT/bin/ops" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

capability="${3:-}"
shift 3 || true
if [[ "${1:-}" == "--" ]]; then
  shift
fi

printf '%s' "$capability" >>"${SPINE_STATE}/ops.log"
for arg in "$@"; do
  printf ' %s' "$arg" >>"${SPINE_STATE}/ops.log"
done
printf '\n' >>"${SPINE_STATE}/ops.log"

echo "Receipt: /tmp/${capability}.receipt.md"

case "$capability" in
  microsoft.mail.get)
    draft_id=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --message-id) draft_id="$2"; shift 2 ;;
        --mailbox) shift 2 ;;
        *) shift ;;
      esac
    done
    case "$draft_id" in
      DRAFT-SEND)
        cat <<'JSON'
{"id":"DRAFT-SEND","subject":"Re: Need 24 polos","toRecipients":[{"emailAddress":{"address":"customer-send@example.com"}}],"ccRecipients":[],"body":{"contentType":"HTML","content":"<p>Greetings Customer,</p><p>Quote attached.</p>"}}
JSON
        ;;
      DRAFT-PARK)
        cat <<'JSON'
{"id":"DRAFT-PARK","subject":"Re: Print Request","toRecipients":[{"emailAddress":{"address":"customer-park@example.com"}}],"ccRecipients":[],"body":{"contentType":"HTML","content":"<p>Greetings Customer,</p><p>We cannot support signage.</p>"}}
JSON
        ;;
      *)
        echo "unexpected draft id: $draft_id" >&2
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

cat >"$SPINE_STATE/mint/customer-inbox-items/current/MII-SEND.json" <<'JSON'
{"capability":"mint.customer.inbox.machine","schema_version":"1.0","inbox_item_id":"MII-SEND","stored_at_utc":"2026-03-17T16:20:00Z","updated_at_utc":"2026-03-17T16:20:00Z","mailbox":"team@mintprints.com","workflow_state":"drafted","disposition":"customer_actionable","work_type":"quote_request","primary_queue_visible":true,"customer_truth_allowed":true,"reply_allowed":true,"recoverable_folder":"","source_mode":"team_direct","reply_anchor_mode":"reply_chain","team_message_anchor":{"message_id":"MSG-SEND","subject":"Need 24 polos","from":"customer-send@example.com"},"source_message_anchor":{"message_id":"MSG-SEND","subject":"Need 24 polos","from":"customer-send@example.com"},"promote_metadata":{},"operator_report":{},"linked_records":{},"queue_claim":{"session_id":"SES-1","message_id":"MSG-SEND"},"transition_history":[]}
JSON
cat >"$SPINE_STATE/mint/customer-inbox-items/by-message-id/MSG-SEND.json" <<EOF
{"message_id":"MSG-SEND","inbox_item_id":"MII-SEND","record_file":"$SPINE_STATE/mint/customer-inbox-items/current/MII-SEND.json"}
EOF

cat >"$SPINE_STATE/mint/customer-inbox-items/current/MII-PARK.json" <<'JSON'
{"capability":"mint.customer.inbox.machine","schema_version":"1.0","inbox_item_id":"MII-PARK","stored_at_utc":"2026-03-17T16:21:00Z","updated_at_utc":"2026-03-17T16:21:00Z","mailbox":"team@mintprints.com","workflow_state":"drafted","disposition":"unsupported_scope","work_type":"ambiguous","primary_queue_visible":true,"customer_truth_allowed":false,"reply_allowed":true,"recoverable_folder":"","source_mode":"team_direct","reply_anchor_mode":"reply_chain","team_message_anchor":{"message_id":"MSG-PARK","subject":"Print Request","from":"customer-park@example.com"},"source_message_anchor":{"message_id":"MSG-PARK","subject":"Print Request","from":"customer-park@example.com"},"promote_metadata":{},"operator_report":{},"linked_records":{},"queue_claim":{"session_id":"SES-2","message_id":"MSG-PARK"},"transition_history":[]}
JSON
cat >"$SPINE_STATE/mint/customer-inbox-items/by-message-id/MSG-PARK.json" <<EOF
{"message_id":"MSG-PARK","inbox_item_id":"MII-PARK","record_file":"$SPINE_STATE/mint/customer-inbox-items/current/MII-PARK.json"}
EOF

cat >"$SPINE_STATE/mint/customer-reply-drafts/records/2026/03/17/MRD-SEND.json" <<'JSON'
{"reply_draft_id":"MRD-SEND","author_mode":"morpheus","mailbox":"team@mintprints.com","inbox_item_id":"MII-SEND","source_message_id":"MSG-SEND","draft_id":"DRAFT-SEND","draft_subject":"Re: Need 24 polos","draft_to":"customer-send@example.com","draft_cc":"","draft_content_type":"HTML","body_preview":"Greetings Customer, Quote attached.","attachments":[],"stored_at_utc":"2026-03-17T16:22:00Z","thread_mode":"reply_chain"}
JSON
cat >"$SPINE_STATE/mint/customer-reply-drafts/records/2026/03/17/MRD-PARK.json" <<'JSON'
{"reply_draft_id":"MRD-PARK","author_mode":"morpheus","mailbox":"team@mintprints.com","inbox_item_id":"MII-PARK","source_message_id":"MSG-PARK","draft_id":"DRAFT-PARK","draft_subject":"Re: Print Request","draft_to":"customer-park@example.com","draft_cc":"","draft_content_type":"HTML","body_preview":"Greetings Customer, We cannot support signage.","attachments":[],"stored_at_utc":"2026-03-17T16:23:00Z","thread_mode":"reply_chain"}
JSON
cat >"$SPINE_STATE/mint/customer-reply-drafts/index.ndjson" <<EOF
{"reply_draft_id":"MRD-SEND","author_mode":"morpheus","mailbox":"team@mintprints.com","inbox_item_id":"MII-SEND","source_message_id":"MSG-SEND","draft_id":"DRAFT-SEND","thread_mode":"reply_chain","stored_at_utc":"2026-03-17T16:22:00Z","record_file":"$SPINE_STATE/mint/customer-reply-drafts/records/2026/03/17/MRD-SEND.json"}
{"reply_draft_id":"MRD-PARK","author_mode":"morpheus","mailbox":"team@mintprints.com","inbox_item_id":"MII-PARK","source_message_id":"MSG-PARK","draft_id":"DRAFT-PARK","thread_mode":"reply_chain","stored_at_utc":"2026-03-17T16:23:00Z","record_file":"$SPINE_STATE/mint/customer-reply-drafts/records/2026/03/17/MRD-PARK.json"}
EOF

review_json="$("$COMPLETE" --action review --inbox-item-id MII-SEND --json)"
[[ "$(echo "$review_json" | jq -r '.data.workflow_state_before')" == "drafted" ]] || fail "review should report the drafted state"
[[ "$(echo "$review_json" | jq -r '.data.workflow_state_after')" == "drafted" ]] || fail "review should not change workflow state"
[[ "$(echo "$review_json" | jq -r '.data.draft_id')" == "DRAFT-SEND" ]] || fail "review should surface the governed draft id"
review_record="$(echo "$review_json" | jq -r '.data.record_file')"
[[ -f "$review_record" ]] || fail "review should persist a completion record"

set +e
send_out="$("$COMPLETE" --action send --message-id MSG-SEND --note "approved and sent" --json 2>&1)"
send_rc=$?
set -e
[[ "$send_rc" -eq 2 ]] || fail "send should be blocked by policy"
echo "$send_out" | grep -F "disabled by policy" >/dev/null || fail "send block should explain the policy"
[[ "$(jq -r '.workflow_state' "$SPINE_STATE/mint/customer-inbox-items/current/MII-SEND.json")" == "drafted" ]] || fail "blocked send should leave workflow state drafted"
[[ ! -f "$SPINE_STATE/send.log" ]] || fail "blocked send should not dispatch a draft"

park_json="$("$COMPLETE" --action park --inbox-item-id MII-PARK --note "parked for operator follow-up" --json)"
[[ "$(echo "$park_json" | jq -r '.data.workflow_state_after')" == "closed" ]] || fail "park should close the inbox item"
[[ "$(jq -r '.workflow_state' "$SPINE_STATE/mint/customer-inbox-items/current/MII-PARK.json")" == "closed" ]] || fail "park should persist closed workflow state"
[[ "$(jq -r '.queue_claim | length' "$SPINE_STATE/mint/customer-inbox-items/current/MII-PARK.json")" == "0" ]] || fail "park should clear the queue claim"
park_record="$(echo "$park_json" | jq -r '.data.record_file')"
[[ -f "$park_record" ]] || fail "park should persist a completion record"
[[ "$(jq -r '.action' "$park_record")" == "park" ]] || fail "park record should persist the action"

pass "customer-inbox-complete reviews drafts, blocks send, and parks the inbox item"

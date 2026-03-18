#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
REVIEW="$ROOT/ops/plugins/domains/mint/bin/customer-junk-review"
DISPOSITION_CONTRACT="$ROOT/ops/bindings/mint.customer.inbox.disposition.contract.yaml"
QUOTE_INTAKE_CONTRACT="$ROOT/ops/bindings/mint.customer.quote.intake.contract.yaml"
JUNK_REVIEW_CONTRACT="$ROOT/ops/bindings/mint.customer.junk.review.contract.yaml"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || fail "jq required"
[[ -x "$REVIEW" ]] || fail "missing customer-junk-review executable"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export SPINE_ROOT="$tmp/spine"
export SPINE_STATE="$tmp/state"
export MINT_CUSTOMER_INBOX_DISPOSITION_CONTRACT="$DISPOSITION_CONTRACT"
export MINT_CUSTOMER_QUOTE_INTAKE_CONTRACT="$QUOTE_INTAKE_CONTRACT"
export MINT_CUSTOMER_JUNK_REVIEW_CONTRACT="$JUNK_REVIEW_CONTRACT"
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
  microsoft.mail.folder.messages)
    cat <<'JSON'
{"folderId":"JUNK-ID","folderDisplayName":"Junk Email","value":[
  {"id":"MSG-SUPPLIER","subject":"Advisors Needed","from":{"emailAddress":{"address":"jackson.simmons@boardsi.com","name":"Jackson Simmons"}},"receivedDateTime":"2026-03-17T07:00:00Z","bodyPreview":"Your profile is a good fit for a board opportunity.","conversationId":"CONV-SUPPLIER","parentFolderId":"JUNK-ID"},
  {"id":"MSG-RISKY","subject":"Urgent action required","from":{"emailAddress":{"address":"noreply@security-check.example","name":"NoReply Security"}},"receivedDateTime":"2026-03-17T07:01:00Z","bodyPreview":"Click here to verify account access.","conversationId":"CONV-RISKY","parentFolderId":"JUNK-ID"},
  {"id":"MSG-COLD","subject":"RE: quick check-in","from":{"emailAddress":{"address":"isabella@brandvisibility.info","name":"Isabella Rimeris"}},"receivedDateTime":"2026-03-17T07:01:30Z","bodyPreview":"Are you still interested in that custom cleaning quotation, or are you good for the time being?","conversationId":"CONV-COLD","parentFolderId":"JUNK-ID"},
  {"id":"MSG-DIGI","subject":"Order Your Free Trial Now. Acceptable For Cap and Chest Sizes.","from":{"emailAddress":{"address":"adam.classicpunch@gmail.com","name":"Adam Devine"}},"receivedDateTime":"2026-03-17T07:01:45Z","bodyPreview":"Free Digitizing Offer. Left chest or cap size logo: $5. Vectorizing price available now.","conversationId":"CONV-DIGI","parentFolderId":"JUNK-ID"},
  {"id":"MSG-CUSTOMER","subject":"Need 24 shirts for the event","from":{"emailAddress":{"address":"customer@example.com","name":"Customer"}},"receivedDateTime":"2026-03-17T07:02:00Z","bodyPreview":"We need shirts for our event.","conversationId":"CONV-CUSTOMER","parentFolderId":"JUNK-ID"}
]}
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
      MSG-SUPPLIER)
        cat <<'JSON'
{"id":"MSG-SUPPLIER","subject":"Advisors Needed","body":{"contentType":"Text","content":"Hi Ronny, your profile is a good fit for open board and advisory opportunities. Free for a quick conversation to learn more? https://calendly.com/boardsi/board-opportunities"},"from":{"emailAddress":{"address":"jackson.simmons@boardsi.com","name":"Jackson Simmons"}},"receivedDateTime":"2026-03-17T07:00:00Z","conversationId":"CONV-SUPPLIER","internetMessageId":"<supplier@example>"}
JSON
        ;;
      MSG-RISKY)
        cat <<'JSON'
{"id":"MSG-RISKY","subject":"Urgent action required","body":{"contentType":"Text","content":"Click here to verify account access and reset password immediately."},"from":{"emailAddress":{"address":"noreply@security-check.example","name":"NoReply Security"}},"receivedDateTime":"2026-03-17T07:01:00Z","conversationId":"CONV-RISKY","internetMessageId":"<risky@example>"}
JSON
        ;;
      MSG-CUSTOMER)
        cat <<'JSON'
{"id":"MSG-CUSTOMER","subject":"Need 24 shirts for the event","body":{"contentType":"Text","content":"Need 24 shirts for the event and would like pricing."},"from":{"emailAddress":{"address":"customer@example.com","name":"Customer"}},"receivedDateTime":"2026-03-17T07:02:00Z","conversationId":"CONV-CUSTOMER","internetMessageId":"<customer@example>"}
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

json_out="$("$REVIEW" --mailbox team@mintprints.com --top 10 --json)"
record_file="$(echo "$json_out" | jq -r '.record_file')"
index_file="$(echo "$json_out" | jq -r '.index_file')"

[[ "$(echo "$json_out" | jq -r '.reviewed_count')" == "5" ]] || fail "review should inspect five junk-folder messages"
[[ "$(echo "$json_out" | jq -r '.counts.supplier_marketing')" == "1" ]] || fail "supplier marketing should count once"
[[ "$(echo "$json_out" | jq -r '.counts.risky_junk')" == "3" ]] || fail "risky junk should count ambiguous cold outreach, risky junk, and digitizing outreach"
[[ "$(echo "$json_out" | jq -r '.counts.real_customer_false_positive')" == "1" ]] || fail "customer false positive should count once"
[[ "$(echo "$json_out" | jq -r '.items[] | select(.message_id=="MSG-SUPPLIER") | .action')" == "move_to_supplier_marketing" ]] || fail "supplier message should route to supplier marketing"
[[ "$(echo "$json_out" | jq -r '.items[] | select(.message_id=="MSG-COLD") | .action')" == "leave_in_junk" ]] || fail "ambiguous cold outreach already in junk should fail closed and stay in junk"
[[ "$(echo "$json_out" | jq -r '.items[] | select(.message_id=="MSG-DIGI") | .action')" == "leave_in_junk" ]] || fail "digitizing outreach with apparel keywords should still stay in junk"
[[ "$(echo "$json_out" | jq -r '.items[] | select(.message_id=="MSG-CUSTOMER") | .destination_folder')" == "Inbox" ]] || fail "customer false positive should restore to Inbox"
[[ "$(echo "$json_out" | jq -r '.items[] | select(.message_id=="MSG-RISKY") | .action')" == "leave_in_junk" ]] || fail "risky junk should stay in Junk Email"
[[ "$(echo "$json_out" | jq -r '.items[] | select(.message_id=="MSG-SUPPLIER") | .hydration_mode')" == "preview_only" ]] || fail "review should avoid full hydration for clearly junk supplier marketing"
[[ "$(echo "$json_out" | jq -r '.items[] | select(.message_id=="MSG-COLD") | .hydration_mode')" == "preview_only" ]] || fail "ambiguous cold junk that fails closed should stay preview-only"
[[ "$(echo "$json_out" | jq -r '.items[] | select(.message_id=="MSG-DIGI") | .hydration_mode')" == "preview_only" ]] || fail "digitizing outreach should be blocked at preview stage"
[[ "$(echo "$json_out" | jq -r '.items[] | select(.message_id=="MSG-CUSTOMER") | .hydration_mode')" == "full_body" ]] || fail "review should hydrate potential false positives before recommending Inbox restore"
[[ -f "$record_file" ]] || fail "review record file should exist"
[[ -f "$index_file" ]] || fail "review index file should exist"
pass "customer-junk-review classifies real Junk folder contents into boring legal actions"

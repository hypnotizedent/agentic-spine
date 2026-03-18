#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
CLEAR="$ROOT/ops/plugins/domains/mint/bin/customer-junk-clear"
DISPOSITION_CONTRACT="$ROOT/ops/bindings/mint.customer.inbox.disposition.contract.yaml"
QUOTE_INTAKE_CONTRACT="$ROOT/ops/bindings/mint.customer.quote.intake.contract.yaml"
JUNK_REVIEW_CONTRACT="$ROOT/ops/bindings/mint.customer.junk.review.contract.yaml"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || fail "jq required"
[[ -x "$CLEAR" ]] || fail "missing customer-junk-clear executable"

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
  microsoft.mail.move)
    message_id=""
    destination=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --message-id) message_id="$2"; shift 2 ;;
        --destination-folder) destination="$2"; shift 2 ;;
        --mailbox) shift 2 ;;
        *) shift ;;
      esac
    done
    printf '%s|%s\n' "$message_id" "$destination" >>"${SPINE_STATE}/moves.log"
    printf '{"id":"MOVED-%s","destinationFolderId":"%s-id","destinationFolderDisplayName":"%s"}\n' "$message_id" "$destination" "$destination"
    ;;
  microsoft.mail.folder.ensure)
    folder_name=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --display-name) folder_name="$2"; shift 2 ;;
        --mailbox) shift 2 ;;
        *) shift ;;
      esac
    done
    printf '{"id":"FOLDER-%s","displayName":"%s","created":false,"status":"existing"}\n' "$folder_name" "$folder_name"
    ;;
  *)
    echo "unsupported capability: $capability" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$SPINE_ROOT/bin/ops"

preview_json="$("$CLEAR" --mailbox team@mintprints.com --top 10 --json)"
[[ "$(echo "$preview_json" | jq -r '.status')" == "preview" ]] || fail "default clear should be preview only"
[[ "$(echo "$preview_json" | jq -r '.action_counts.move_to_supplier_marketing')" == "1" ]] || fail "clear should include supplier marketing reroute"
[[ "$(echo "$preview_json" | jq -r '.action_counts.restore_to_inbox')" == "1" ]] || fail "clear should include one Inbox restore"
[[ "$(echo "$preview_json" | jq -r '.action_counts.drain_to_deleted_items')" == "1" ]] || fail "clear should include one Deleted Items drain"
[[ ! -f "$SPINE_STATE/moves.log" ]] || fail "preview clear should not move anything"

apply_json="$("$CLEAR" --mailbox team@mintprints.com --top 10 --apply --json)"
[[ "$(echo "$apply_json" | jq -r '.status')" == "applied" ]] || fail "apply clear should report applied status"
[[ "$(grep -c '^' "$SPINE_STATE/moves.log")" == "3" ]] || fail "apply clear should perform three moves"
grep -Fx 'MSG-SUPPLIER|Supplier Marketing' "$SPINE_STATE/moves.log" >/dev/null || fail "supplier marketing should route to Supplier Marketing"
grep -Fx 'MSG-CUSTOMER|Inbox' "$SPINE_STATE/moves.log" >/dev/null || fail "false positive should restore to Inbox"
grep -Fx 'MSG-RISKY|Deleted Items' "$SPINE_STATE/moves.log" >/dev/null || fail "risky junk should drain to Deleted Items"
pass "customer-junk-clear performs the governed one-step junk clear path"

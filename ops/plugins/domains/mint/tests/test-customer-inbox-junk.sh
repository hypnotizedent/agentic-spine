#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
JUNK="$ROOT/ops/plugins/domains/mint/bin/customer-inbox-junk"
DISPOSITION_CONTRACT="$ROOT/ops/bindings/mint.customer.inbox.disposition.contract.yaml"
QUOTE_INTAKE_CONTRACT="$ROOT/ops/bindings/mint.customer.quote.intake.contract.yaml"
JUNK_REVIEW_CONTRACT="$ROOT/ops/bindings/mint.customer.junk.review.contract.yaml"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || fail "jq required"
[[ -x "$JUNK" ]] || fail "missing customer-inbox-junk executable"

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
      MSG-SPAM)
        cat <<'JSON'
{"id":"MSG-SPAM","subject":"Advisors Needed","body":{"contentType":"Text","content":"Hi Ronny, your profile is a good fit for open board and advisory opportunities. Free for a quick conversation to learn more? See our calendar below: https://calendly.com/boardsi/board-opportunities"},"from":{"emailAddress":{"address":"jackson.simmons@boardsi.com","name":"Jackson Simmons"}}}
JSON
        ;;
      MSG-RISKY)
        cat <<'JSON'
{"id":"MSG-RISKY","subject":"Urgent action required","body":{"contentType":"Text","content":"Click here to verify account access and reset password immediately."},"from":{"emailAddress":{"address":"noreply@security-check.example","name":"NoReply Security"}}}
JSON
        ;;
      MSG-CUSTOMER)
        cat <<'JSON'
{"id":"MSG-CUSTOMER","subject":"Need quote","body":{"contentType":"Text","content":"Need 24 shirts for the event."},"from":{"emailAddress":{"address":"customer@example.com","name":"Customer"}}}
JSON
        ;;
      *)
        echo "unexpected message id: $message_id" >&2
        exit 1
        ;;
    esac
    ;;
  microsoft.mail.move)
    destination=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --message-id) shift 2 ;;
        --destination-folder) destination="$2"; shift 2 ;;
        --mailbox) shift 2 ;;
        *) shift ;;
      esac
    done
    printf '{"id":"MSG-MOVED","destinationFolderId":"FOLDER-ID","destinationFolderDisplayName":"%s"}\n' "$destination"
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
    printf '{"id":"FOLDER-ID","displayName":"%s","created":false,"status":"existing"}\n' "$folder_name"
    ;;
  *)
    echo "unsupported capability: $capability" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$SPINE_ROOT/bin/ops"

json_out="$("$JUNK" MSG-SPAM --mailbox team@mintprints.com --json)"
record_file="$(echo "$json_out" | jq -r '.record_file')"
index_file="$(echo "$json_out" | jq -r '.index_file')"
classification="$(echo "$json_out" | jq -r '.classification.triage_class')"
disposition="$(echo "$json_out" | jq -r '.classification.disposition')"
destination="$(echo "$json_out" | jq -r '.destination_folder_display_name')"
moved_message_id="$(echo "$json_out" | jq -r '.moved_message_id')"

[[ "$classification" == "promotional" ]] || fail "promotional message should classify as promotional"
[[ "$disposition" == "supplier_marketing" ]] || fail "supplier outreach should classify as supplier_marketing"
[[ "$destination" == "Supplier Marketing" ]] || fail "supplier marketing should move to the recoverable supplier folder"
[[ "$moved_message_id" == "MSG-MOVED" ]] || fail "moved message id should be returned"
[[ -f "$record_file" ]] || fail "record file should exist"
[[ -f "$index_file" ]] || fail "index file should exist"
[[ "$(jq -r '.receipts.move_receipt' "$record_file")" == "/tmp/microsoft.mail.move.receipt.md" ]] || fail "record should keep move receipt"

risky_out="$("$JUNK" MSG-RISKY --mailbox team@mintprints.com --json)"
[[ "$(echo "$risky_out" | jq -r '.classification.disposition')" == "risky_junk" ]] || fail "risky message should classify as risky_junk"
[[ "$(echo "$risky_out" | jq -r '.destination_folder_display_name')" == "Junk Email" ]] || fail "risky message should stay in Junk Email"

set +e
customer_out="$("$JUNK" MSG-CUSTOMER --mailbox team@mintprints.com 2>&1)"
customer_rc=$?
set -e
[[ "$customer_rc" -ne 0 ]] || fail "customer message should refuse junk move by default"
echo "$customer_out" | grep "disposition is customer_actionable" >/dev/null || fail "customer refusal should mention disposition blocker"
pass "customer-inbox-junk routes supplier marketing recoverably, sends risky mail to Junk, and refuses real customer mail by default"

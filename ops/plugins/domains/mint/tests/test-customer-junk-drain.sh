#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
DRAIN="$ROOT/ops/plugins/domains/mint/bin/customer-junk-drain"
DISPOSITION_CONTRACT="$ROOT/ops/bindings/mint.customer.inbox.disposition.contract.yaml"
QUOTE_INTAKE_CONTRACT="$ROOT/ops/bindings/mint.customer.quote.intake.contract.yaml"
JUNK_REVIEW_CONTRACT="$ROOT/ops/bindings/mint.customer.junk.review.contract.yaml"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || fail "jq required"
[[ -x "$DRAIN" ]] || fail "missing customer-junk-drain executable"

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
  *)
    echo "unsupported capability: $capability" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$SPINE_ROOT/bin/ops"

preview_json="$("$DRAIN" --mailbox team@mintprints.com --top 10 --json)"
[[ "$(echo "$preview_json" | jq -r '.status')" == "preview" ]] || fail "default drain should be preview only"
[[ "$(echo "$preview_json" | jq -r '.drain_candidate_count')" == "1" ]] || fail "drain should target only risky junk"
[[ ! -f "$SPINE_STATE/moves.log" ]] || fail "preview drain should not move anything"

apply_json="$("$DRAIN" --mailbox team@mintprints.com --top 10 --apply --json)"
[[ "$(echo "$apply_json" | jq -r '.status')" == "applied" ]] || fail "apply drain should report applied status"
[[ "$(echo "$apply_json" | jq -r '.drain_candidate_count')" == "1" ]] || fail "apply drain should still target one risky message"
grep -Fx 'MSG-RISKY|Deleted Items' "$SPINE_STATE/moves.log" >/dev/null || fail "risky junk should move to Deleted Items"
if grep -F 'MSG-CUSTOMER' "$SPINE_STATE/moves.log" >/dev/null; then
  fail "drain should not move non-junk messages"
fi
pass "customer-junk-drain moves only confirmed risky junk into Deleted Items"

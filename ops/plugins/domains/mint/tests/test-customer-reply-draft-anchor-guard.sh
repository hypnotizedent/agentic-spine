#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
REPLY="$ROOT/ops/plugins/domains/mint/bin/customer-reply-draft"
REPLY_POLICY="$ROOT/ops/bindings/mint.customer.reply.draft.policy.contract.yaml"
QUOTE_POLICY="$ROOT/ops/bindings/mint.quote.intelligence.policy.contract.yaml"
OPERATOR_POLICY="$ROOT/ops/bindings/mint.customer.operator.policy.contract.yaml"
DISPOSITION_CONTRACT="$ROOT/ops/bindings/mint.customer.inbox.disposition.contract.yaml"
QUOTE_INTAKE_CONTRACT="$ROOT/ops/bindings/mint.customer.quote.intake.contract.yaml"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || fail "jq required"
[[ -x "$REPLY" ]] || fail "missing customer-reply-draft executable"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export SPINE_ROOT="$tmp/spine"
export SPINE_STATE="$tmp/state"
export MINT_CUSTOMER_REPLY_DRAFT_POLICY_CONTRACT="$REPLY_POLICY"
export MINT_QUOTE_INTELLIGENCE_POLICY_CONTRACT="$QUOTE_POLICY"
export MINT_CUSTOMER_OPERATOR_POLICY_CONTRACT="$OPERATOR_POLICY"
export MINT_CUSTOMER_INBOX_DISPOSITION_CONTRACT="$DISPOSITION_CONTRACT"
export MINT_CUSTOMER_QUOTE_INTAKE_CONTRACT="$QUOTE_INTAKE_CONTRACT"

mkdir -p "$SPINE_ROOT/bin" "$SPINE_STATE/mint/customer-quote-intakes/records/2026/03/17" "$SPINE_ROOT/runtime/domain-state/mint/quote-packets"

cat >"$SPINE_ROOT/runtime/domain-state/mint/quote-packets/quote_packet_wrong.yaml" <<'YAML'
quote_packet_id: packet-wrong
customer_ref:
  resolved_email: wrong@example.com
  resolved_name: Wrong Customer
line_items: []
YAML

cat >"$SPINE_STATE/mint/customer-quote-intakes/index.ndjson" <<EOF
{"message_id":"MSG-BAD","record_file":"$SPINE_STATE/mint/customer-quote-intakes/records/2026/03/17/MCQI-BAD.json","stored_at_utc":"2026-03-17T07:00:00Z"}
EOF

cat >"$SPINE_STATE/mint/customer-quote-intakes/records/2026/03/17/MCQI-BAD.json" <<EOF
{
  "stored_at_utc": "2026-03-17T07:00:00Z",
  "customer": {"email": "wrong@example.com", "name": "Wrong Customer"},
  "estimate_surface": {"quote_safe_line_item_count": 1, "clarification_needed_count": 0},
  "handoff": {
    "packet_file": "$SPINE_ROOT/runtime/domain-state/mint/quote-packets/quote_packet_wrong.yaml",
    "packet_id": "packet-wrong",
    "source_state": "completed",
    "estimate_state": "completed",
    "pricing_state": "blocked_insufficient_inputs"
  },
  "intake_quality": {"classification": "ideal"},
  "qualification_status": "qualified_enough_to_quote",
  "record_file": "$SPINE_STATE/mint/customer-quote-intakes/records/2026/03/17/MCQI-BAD.json"
}
EOF

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
      MSG-BAD)
        cat <<'JSON'
{"id":"MSG-BAD","subject":"Need quote for 24 shirts","conversationId":"CONV-BAD","internetMessageId":"<bad@example.com>","from":{"emailAddress":{"address":"correct@example.com","name":"Correct Customer"}},"toRecipients":[{"emailAddress":{"address":"team@mintprints.com"}}],"ccRecipients":[],"body":{"contentType":"Text","content":"Need quote for 24 shirts."},"bodyPreview":"Need quote for 24 shirts."}
JSON
        ;;
      *)
        echo "unexpected message id: $message_id" >&2
        exit 1
        ;;
    esac
    ;;
  communications.mail.search)
    echo '{"value":[]}'
    ;;
  microsoft.mail.reply.draft)
    echo "reply draft should not be called when anchor guard fails" >&2
    exit 91
    ;;
  mint.customer.record.snapshot)
    echo '{"data":{"quote_intelligence":{}}}'
    ;;
  *)
    echo "unsupported capability: $capability" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$SPINE_ROOT/bin/ops"

set +e
out="$(
  "$REPLY" --message-id MSG-BAD --mailbox team@mintprints.com --reply-mode formal_quote_ready --author-mode morpheus \
    --quote-subject "13846 Wrong Customer" \
    --quote-url "https://example.test/invoice/13846" \
    --packet-file "$SPINE_ROOT/runtime/domain-state/mint/quote-packets/quote_packet_wrong.yaml" \
    --json 2>&1
)"
status=$?
set -e

[[ "$status" -ne 0 ]] || fail "anchor mismatch should fail closed instead of drafting"
echo "$out" | grep -F "repair item recorded at" >/dev/null || fail "anchor mismatch failure should point to the recorded repair item"
repair_record="$(find "$SPINE_STATE/mint/customer-repair-items/records" -type f -name '*.json' | head -n1)"
[[ -f "$repair_record" ]] || fail "anchor mismatch should record a repair item"
[[ "$(jq -r '.issue_type' "$repair_record")" == "reply_draft_anchor_mismatch" ]] || fail "repair item should classify the anchor mismatch"

pass "customer-reply-draft fails closed and records a repair item when quote anchors do not match the source customer"

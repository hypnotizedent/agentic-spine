#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${SPINE_ROOT:-$(cd "$SCRIPT_DIR/../../../../.." && pwd)}"
RESOLVER="$ROOT/ops/plugins/domains/mint/bin/customer-lifecycle-resolve"
CONTRACT="$ROOT/ops/bindings/mint.customer.lifecycle.resolve.contract.yaml"
DISPOSITION_CONTRACT="$ROOT/ops/bindings/mint.customer.inbox.disposition.contract.yaml"
QUOTE_INTAKE_CONTRACT="$ROOT/ops/bindings/mint.customer.quote.intake.contract.yaml"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || fail "jq required"
[[ -x "$RESOLVER" ]] || fail "missing customer-lifecycle-resolve executable"
[[ -f "$CONTRACT" ]] || fail "missing lifecycle contract"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export SPINE_ROOT="$tmp/spine"
export SPINE_STATE="$tmp/state"
export MINT_CUSTOMER_LIFECYCLE_RESOLVE_CONTRACT="$CONTRACT"
export MINT_CUSTOMER_INBOX_DISPOSITION_CONTRACT="$DISPOSITION_CONTRACT"
export MINT_CUSTOMER_QUOTE_INTAKE_CONTRACT="$QUOTE_INTAKE_CONTRACT"

mkdir -p "$SPINE_ROOT/bin" "$SPINE_STATE/mint/customer-quote-intakes/records/2026/03/14" \
  "$SPINE_STATE/mint/customer-outbound-bindings/records" \
  "$SPINE_STATE/mint/artie-revision-reviews/records/2026/03/14" \
  "$SPINE_ROOT/runtime/domain-state/mint/quote-packets"

cat >"$SPINE_ROOT/bin/ops" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

capability="${3:-}"
shift 3 || true
if [[ "${1:-}" == "--" ]]; then
  shift
fi

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
      MSG-COVE)
        cat <<'JSON'
{"id":"MSG-COVE","subject":"Merch Quote Request - Cove Brewery","conversationId":"CONV-COVE","from":{"emailAddress":{"address":"marketing@covebrewery.com","name":"Spencer Todd"}}}
JSON
        ;;
      MSG-TROY-FWD)
        cat <<'JSON'
{"id":"MSG-TROY-FWD","subject":"FW: papapalooza","conversationId":"CONV-TROY-FWD","from":{"emailAddress":{"address":"team@mintprints.com","name":"Mint Team"}}}
JSON
        ;;
      MSG-MARWAN)
        cat <<'JSON'
{"id":"MSG-MARWAN","subject":"Fw: Print Request","conversationId":"CONV-MARWAN","from":{"emailAddress":{"address":"marwan@icosf.org","name":"Marwan"}}}
JSON
        ;;
      MSG-KIARA)
        cat <<'JSON'
{"id":"MSG-KIARA","subject":"Quote split order","conversationId":"CONV-KIARA","from":{"emailAddress":{"address":"kiara@example.com","name":"Kiara"}}}
JSON
        ;;
      *)
        echo "unexpected message id: $message_id" >&2
        exit 1
        ;;
    esac
    ;;
  mint.printavo.bridge.snapshot)
    args="$*"
    if [[ "$args" == *"seed-cove"* ]]; then
      cat <<'JSON'
{"capability":"mint.printavo.bridge.snapshot","state":"quote_live","latest":{"order_id":"order-cove","printavo_state":"quote_live","printavo_summary":{"printavo_state":"quote_live","printavo_public_invoice_url":"https://example.com/quote/13639","printavo_visual_id":"13639"}}}
JSON
    elif [[ "$args" == *"seed-troy"* ]] || [[ "$args" == *"info@papasrawbar.com"* ]]; then
      cat <<'JSON'
{"capability":"mint.printavo.bridge.snapshot","state":"paid","latest":{"order_id":"order-troy","printavo_state":"paid","printavo_summary":{"printavo_state":"paid","printavo_visual_id":"13823"}}}
JSON
    else
      cat <<'JSON'
{"capability":"mint.printavo.bridge.snapshot","state":"no_record_found","latest":null,"matches":[]}
JSON
    fi
    ;;
  mint.payment.record.snapshot)
    args="$*"
    if [[ "$args" == *"marketing@covebrewery.com"* ]]; then
      cat <<'JSON'
{"capability":"mint.payment.record.snapshot","state":"not_yet_visible","latest":{"payment_state":"unpaid","payment_visibility_state":"not_yet_visible"}}
JSON
    elif [[ "$args" == *"cust-troy"* ]] || [[ "$args" == *"info@papasrawbar.com"* ]]; then
      cat <<'JSON'
{"capability":"mint.payment.record.snapshot","state":"confirmed_in_records","latest":{"payment_state":"paid","payment_visibility_state":"confirmed_in_records"}}
JSON
    else
      cat <<'JSON'
{"capability":"mint.payment.record.snapshot","state":"no_record_found","latest":null}
JSON
    fi
    ;;
  mint.customer.quote.intake)
    echo "quote intake should not be called in this fixture" >&2
    exit 1
    ;;
  *)
    echo "unsupported capability: $capability" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$SPINE_ROOT/bin/ops"

cat >"$SPINE_ROOT/runtime/domain-state/mint/quote-packets/quote_packet_cove.yaml" <<'YAML'
quote_packet_id: packet-cove
customer_ref:
  customer_id: cust-cove
  resolved_email: marketing@covebrewery.com
  resolved_name: Spencer Todd
source_refs:
  - seed_id: seed-cove
YAML

cat >"$SPINE_ROOT/runtime/domain-state/mint/quote-packets/quote_packet_troy.yaml" <<'YAML'
quote_packet_id: packet-troy
customer_ref:
  customer_id: cust-troy
  resolved_email: info@papasrawbar.com
  resolved_name: Troy
source_refs:
  - seed_id: seed-troy
YAML

cat >"$SPINE_ROOT/runtime/domain-state/mint/quote-packets/quote_packet_marwan.yaml" <<'YAML'
quote_packet_id: packet-marwan
customer_ref:
  resolved_email: marwan@icosf.org
  resolved_name: Marwan
source_refs: []
YAML

cat >"$SPINE_ROOT/runtime/domain-state/mint/quote-packets/quote_packet_kiara.yaml" <<'YAML'
quote_packet_id: packet-kiara
customer_ref:
  resolved_email: kiara@example.com
  resolved_name: Kiara
source_refs:
  - seed_id: seed-kiara
YAML

cat >"$SPINE_STATE/mint/customer-quote-intakes/index.ndjson" <<EOF
{"message_id":"MSG-COVE","record_file":"$SPINE_STATE/mint/customer-quote-intakes/records/2026/03/14/MCQI-COVE.json"}
{"message_id":"MSG-TROY-FWD","record_file":"$SPINE_STATE/mint/customer-quote-intakes/records/2026/03/14/MCQI-TROY.json"}
{"message_id":"MSG-MARWAN","record_file":"$SPINE_STATE/mint/customer-quote-intakes/records/2026/03/14/MCQI-MARWAN.json"}
{"message_id":"MSG-KIARA","record_file":"$SPINE_STATE/mint/customer-quote-intakes/records/2026/03/14/MCQI-KIARA.json"}
EOF

cat >"$SPINE_STATE/mint/customer-quote-intakes/records/2026/03/14/MCQI-COVE.json" <<EOF
{
  "customer": {"email": "marketing@covebrewery.com", "name": "Spencer Todd"},
  "estimate_surface": {"quote_safe_line_item_count": 7, "clarification_needed_count": 0, "price_lane": "\$9.39-\$12.81"},
  "handoff": {
    "packet_file": "$SPINE_ROOT/runtime/domain-state/mint/quote-packets/quote_packet_cove.yaml",
    "packet_id": "packet-cove",
    "source_state": "completed",
    "estimate_state": "completed",
    "pricing_state": "blocked_insufficient_inputs"
  },
  "intake_quality": {"classification": "ideal"},
  "qualification_status": "qualified_enough_to_quote",
  "record_file": "$SPINE_STATE/mint/customer-quote-intakes/records/2026/03/14/MCQI-COVE.json"
}
EOF

cat >"$SPINE_STATE/mint/customer-quote-intakes/records/2026/03/14/MCQI-TROY.json" <<EOF
{
  "customer": {"email": "digitrace54@gmail.com", "name": "Sheikh Amaan"},
  "estimate_surface": {"quote_safe_line_item_count": 0, "clarification_needed_count": 0},
  "handoff": {
    "packet_file": "$SPINE_ROOT/runtime/domain-state/mint/quote-packets/quote_packet_troy.yaml",
    "packet_id": "packet-troy",
    "source_state": "not_attempted",
    "estimate_state": "not_attempted",
    "pricing_state": "not_attempted"
  },
  "intake_quality": {"classification": "headache"},
  "qualification_status": "headache_operator_burden",
  "record_file": "$SPINE_STATE/mint/customer-quote-intakes/records/2026/03/14/MCQI-TROY.json"
}
EOF

cat >"$SPINE_STATE/mint/customer-quote-intakes/records/2026/03/14/MCQI-MARWAN.json" <<EOF
{
  "customer": {"email": "marwan@icosf.org", "name": "Marwan"},
  "estimate_surface": {"quote_safe_line_item_count": 0, "clarification_needed_count": 0},
  "handoff": {
    "packet_file": "$SPINE_ROOT/runtime/domain-state/mint/quote-packets/quote_packet_marwan.yaml",
    "packet_id": "packet-marwan",
    "source_state": "not_attempted",
    "estimate_state": "not_attempted",
    "pricing_state": "not_attempted"
  },
  "intake_quality": {"classification": "headache"},
  "product_scope": {
    "classification": "out_of_scope",
    "category": "vinyl_signage",
    "customer_summary": "This request is for vinyl/signage work rather than apparel printing."
  },
  "qualification_status": "out_of_scope_not_supported",
  "customer_reply_guidance": {
    "mode": "not_a_fit",
    "summary": "This is not an apparel quote lane."
  },
  "record_file": "$SPINE_STATE/mint/customer-quote-intakes/records/2026/03/14/MCQI-MARWAN.json"
}
EOF

cat >"$SPINE_STATE/mint/customer-quote-intakes/records/2026/03/14/MCQI-KIARA.json" <<EOF
{
  "customer": {"email": "kiara@example.com", "name": "Kiara"},
  "estimate_surface": {"quote_safe_line_item_count": 0, "clarification_needed_count": 1},
  "handoff": {
    "packet_file": "$SPINE_ROOT/runtime/domain-state/mint/quote-packets/quote_packet_kiara.yaml",
    "packet_id": "packet-kiara",
    "source_state": "completed",
    "estimate_state": "blocked_insufficient_inputs",
    "pricing_state": "blocked_insufficient_inputs"
  },
  "intake_quality": {"classification": "workable"},
  "qualification_status": "clarification_needed",
  "customer_reply_guidance": {
    "mode": "ask_targeted_blocker_only",
    "summary": "Ask only for the smallest missing structured blocker.",
    "blockers": ["How many white cotton tees versus dry-fit cruise tees do you need out of the 25 total?"]
  },
  "record_file": "$SPINE_STATE/mint/customer-quote-intakes/records/2026/03/14/MCQI-KIARA.json"
}
EOF

cat >"$SPINE_STATE/mint/customer-outbound-bindings/index.ndjson" <<EOF
{"record_file":"$SPINE_STATE/mint/customer-outbound-bindings/records/MOB-COVE.json"}
{"record_file":"$SPINE_STATE/mint/customer-outbound-bindings/records/MOB-TROY.json"}
EOF

cat >"$SPINE_STATE/mint/customer-outbound-bindings/records/MOB-COVE.json" <<'EOF'
{
  "binding_id": "MOB-COVE",
  "external_message_id": "MSG-COVE",
  "external_sender": "marketing@covebrewery.com",
  "quote_binding": {
    "packet_id": "packet-cove",
    "quote_subject": "13639 Cove Brewery merch quote"
  },
  "participant_resolution": {
    "reply_target_role": "customer",
    "canonical_customer_thread": {
      "from": "marketing@covebrewery.com",
      "from_name": "Spencer Todd"
    }
  },
  "canonical_recipients": {"to": ["marketing@covebrewery.com"], "cc": []}
}
EOF

cat >"$SPINE_STATE/mint/customer-outbound-bindings/records/MOB-TROY.json" <<'EOF'
{
  "binding_id": "MOB-TROY",
  "selected_from_source_message_id": "MSG-TROY-FWD",
  "external_message_id": "MSG-TROY-CUSTOMER",
  "external_sender": "info@papasrawbar.com",
  "quote_binding": {
    "packet_id": "packet-troy",
    "quote_subject": "13823 PapaPalooza",
    "job_number": "13823",
    "job_nickname": "PapaPalooza"
  },
  "participant_resolution": {
    "reply_target_role": "customer",
    "canonical_customer_thread": {
      "from": "info@papasrawbar.com",
      "from_name": "Papa's Raw Bar"
    },
    "canonical_vendor_thread": {
      "from": "digitrace54@gmail.com",
      "from_name": "Sheikh Amaan"
    }
  },
  "canonical_recipients": {"to": ["info@papasrawbar.com"], "cc": []}
}
EOF

cat >"$SPINE_STATE/mint/artie-revision-reviews/index.ndjson" <<EOF
{"record_file":"$SPINE_STATE/mint/artie-revision-reviews/records/2026/03/14/MARR-TROY.json","job_identity":"13823","customer_identity":"Papa's Raw Bar","proof_readiness_state":"revision_required","review_confidence":"medium"}
EOF

cat >"$SPINE_STATE/mint/artie-revision-reviews/records/2026/03/14/MARR-TROY.json" <<'EOF'
{
  "job_identity": "13823",
  "customer_identity": "Papa's Raw Bar",
  "exact_miss": "Lighthouse Point, FL",
  "review_confidence": "medium",
  "morpheus_consumption": {
    "source_message_id": "MSG-TROY-FWD"
  },
  "proof_readiness": {
    "state": "revision_required"
  }
}
EOF

cove_json="$("$RESOLVER" --mailbox team@mintprints.com --message-id MSG-COVE --json)"
[[ "$(echo "$cove_json" | jq -r '.data.lifecycle_state')" == "quote_live_pending_customer_response" ]] || fail "Cove should resolve to quote_live_pending_customer_response"
[[ "$(echo "$cove_json" | jq -r '.data.reply_mode')" == "formal_quote_ready" ]] || fail "Cove should render formal_quote_ready"
[[ "$(echo "$cove_json" | jq -r '.data.quote_binding_patch.quote_url')" == "https://example.com/quote/13639" ]] || fail "Cove should carry the live quote URL"
echo "$cove_json" | jq -e '.data.generated_body | contains("I have the live quote ready here.")' >/dev/null || fail "Cove should produce a live-quote body"

troy_json="$("$RESOLVER" --mailbox team@mintprints.com --message-id MSG-TROY-FWD --json)"
[[ "$(echo "$troy_json" | jq -r '.data.lifecycle_state')" == "paid_art_revision_required" ]] || fail "Troy should resolve to paid_art_revision_required"
[[ "$(echo "$troy_json" | jq -r '.data.reply_mode')" == "art_revision" ]] || fail "Troy should render art_revision"
[[ "$(echo "$troy_json" | jq -r '.data.quote_binding_patch.customer_email')" == "info@papasrawbar.com" ]] || fail "Troy should carry the canonical customer email from the outbound binding"
echo "$troy_json" | jq -e '.data.generated_body | contains("Lighthouse Point, FL")' >/dev/null || fail "Troy body should surface the specific proof miss"

marwan_json="$("$RESOLVER" --mailbox team@mintprints.com --message-id MSG-MARWAN --json)"
[[ "$(echo "$marwan_json" | jq -r '.data.lifecycle_state')" == "needs_manual_resolution" ]] || fail "Marwan mismatch should fail closed into needs_manual_resolution"
[[ "$(echo "$marwan_json" | jq -r '.data.reply_mode')" == "" ]] || fail "Marwan mismatch should not publish a customer-facing lifecycle reply mode"
[[ "$(echo "$marwan_json" | jq -r '.data.customer_email')" == "marwan@icosf.org" ]] || fail "Marwan should keep the source customer identity"
[[ "$(echo "$marwan_json" | jq -r '.data.quote_binding_patch.quote_subject')" == "" ]] || fail "Marwan should not inherit an unrelated quote subject from an old outbound binding"
[[ "$(echo "$marwan_json" | jq -r '.data.repair_item.record_file')" != "" ]] || fail "Marwan mismatch should record a repair item"

kiara_json="$("$RESOLVER" --mailbox team@mintprints.com --message-id MSG-KIARA --json)"
[[ "$(echo "$kiara_json" | jq -r '.data.lifecycle_state')" == "clarification_needed_before_quote" ]] || fail "Kiara should resolve to clarification_needed_before_quote"
[[ "$(echo "$kiara_json" | jq -r '.data.reply_mode')" == "clarification_only" ]] || fail "Kiara should render clarification_only"
[[ "$(echo "$kiara_json" | jq -r '.data.blockers[0]')" == "How many white cotton tees versus dry-fit cruise tees do you need out of the 25 total?" ]] || fail "lifecycle clarification should keep the explicit blocker question"
[[ "$(echo "$kiara_json" | jq -r '.data.generated_body')" == "" ]] || fail "clarification lifecycle should leave the customer body empty for structured blocker rendering"

pass "customer lifecycle resolver keeps clarification replies blocker-only, separates live quote state from paid art revision state, and fails closed on anchor mismatch"

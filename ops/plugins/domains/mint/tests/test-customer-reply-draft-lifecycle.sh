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

mkdir -p "$SPINE_ROOT/bin" "$SPINE_STATE/mint/customer-quote-intakes/records/2026/03/14" "$SPINE_ROOT/runtime/domain-state/mint/quote-packets"
mkdir -p "$SPINE_STATE/mint/customer-lifecycle-resolutions/records/2026/03/14"

cat >"$SPINE_ROOT/runtime/domain-state/mint/quote-packets/quote_packet_cove.yaml" <<'YAML'
quote_packet_id: packet-cove
customer_ref:
  resolved_email: marketing@covebrewery.com
  resolved_name: Spencer Todd
line_items: []
YAML

cat >"$SPINE_ROOT/runtime/domain-state/mint/quote-packets/quote_packet_marwan.yaml" <<'YAML'
quote_packet_id: packet-marwan
customer_ref:
  resolved_email: marwan@icosf.org
  resolved_name: Marwan
line_items: []
YAML

cat >"$SPINE_ROOT/runtime/domain-state/mint/quote-packets/quote_packet_hold.yaml" <<'YAML'
quote_packet_id: packet-hold
customer_ref:
  resolved_email: phusecream7@gmail.com
  resolved_name: Catherine
line_items: []
YAML

cat >"$SPINE_STATE/mint/customer-quote-intakes/index.ndjson" <<EOF
{"message_id":"MSG-COVE","record_file":"$SPINE_STATE/mint/customer-quote-intakes/records/2026/03/14/MCQI-COVE.json"}
{"message_id":"MSG-GUIDED","record_file":"$SPINE_STATE/mint/customer-quote-intakes/records/2026/03/14/MCQI-GUIDED.json"}
{"message_id":"MSG-MARWAN","record_file":"$SPINE_STATE/mint/customer-quote-intakes/records/2026/03/14/MCQI-MARWAN.json"}
{"message_id":"MSG-HOLD","record_file":"$SPINE_STATE/mint/customer-quote-intakes/records/2026/03/14/MCQI-HOLD.json"}
EOF

cat >"$SPINE_STATE/mint/customer-quote-intakes/records/2026/03/14/MCQI-COVE.json" <<EOF
{
  "customer": {"email": "marketing@covebrewery.com", "name": "Spencer Todd"},
  "estimate_surface": {"quote_safe_line_item_count": 0, "clarification_needed_count": 0},
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

cat >"$SPINE_STATE/mint/customer-quote-intakes/records/2026/03/14/MCQI-GUIDED.json" <<EOF
{
  "customer": {"email": "marketing@covebrewery.com", "name": "Spencer Todd"},
  "estimate_surface": {
    "quote_safe_line_item_count": 1,
    "clarification_needed_count": 0,
    "line_item_estimates": [
      {
        "line_item_id": "line-1",
        "description": "Cove tee - vintage white",
        "recommended_method": "screen_print",
        "estimated_unit_price": 11.23,
        "estimated_decoration_profile": {
          "size_tier_label": "standard_print",
          "setup_mode": "new_setup",
          "underbase_needed": false
        },
        "quote_safe_now": true,
        "confidence_level": "high",
        "missing_clarifications": []
      }
    ]
  },
  "handoff": {
    "packet_file": "$SPINE_ROOT/runtime/domain-state/mint/quote-packets/quote_packet_missing.yaml",
    "packet_id": "packet-missing",
    "source_state": "completed",
    "estimate_state": "completed",
    "pricing_state": "blocked_insufficient_inputs"
  },
  "intake_quality": {"classification": "ideal"},
  "qualification_status": "qualified_enough_to_quote",
  "customer_reply_guidance": {
    "summary": "Acknowledge the organized order and keep it moving."
  },
  "record_file": "$SPINE_STATE/mint/customer-quote-intakes/records/2026/03/14/MCQI-GUIDED.json"
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

cat >"$SPINE_STATE/mint/customer-quote-intakes/records/2026/03/14/MCQI-HOLD.json" <<EOF
{
  "customer": {"email": "phusecream7@gmail.com", "name": "Catherine"},
  "estimate_surface": {"quote_safe_line_item_count": 0, "clarification_needed_count": 0},
  "handoff": {
    "packet_file": "$SPINE_ROOT/runtime/domain-state/mint/quote-packets/quote_packet_hold.yaml",
    "packet_id": "packet-hold",
    "source_state": "not_attempted",
    "estimate_state": "not_attempted",
    "pricing_state": "not_attempted"
  },
  "intake_quality": {"classification": "ideal"},
  "qualification_status": "qualified_enough_to_quote",
  "record_file": "$SPINE_STATE/mint/customer-quote-intakes/records/2026/03/14/MCQI-HOLD.json"
}
EOF

cat >"$SPINE_STATE/mint/customer-lifecycle-resolutions/index.ndjson" <<EOF
{"message_id":"MSG-COVE","record_file":"$SPINE_STATE/mint/customer-lifecycle-resolutions/records/2026/03/14/MCLR-COVE.json"}
{"message_id":"MSG-GUIDED","record_file":"$SPINE_STATE/mint/customer-lifecycle-resolutions/records/2026/03/14/MCLR-GUIDED.json"}
{"message_id":"MSG-MARWAN","record_file":"$SPINE_STATE/mint/customer-lifecycle-resolutions/records/2026/03/14/MCLR-MARWAN.json"}
{"message_id":"MSG-HOLD","record_file":"$SPINE_STATE/mint/customer-lifecycle-resolutions/records/2026/03/14/MCLR-HOLD.json"}
EOF

cat >"$SPINE_STATE/mint/customer-lifecycle-resolutions/records/2026/03/14/MCLR-COVE.json" <<'EOF'
{
  "lifecycle_id": "MCLR-COVE",
  "lifecycle_state": "quote_live_pending_customer_response",
  "confidence": "high",
  "reply_mode": "formal_quote_ready",
  "draft_allowed": true,
  "customer_safe_next_step": "Review the live quote and let me know if you want us to move forward.",
  "operator_next_action": "Track approval or requested edits on the live quote.",
  "current_action": "",
  "blockers": [],
  "generated_body": "I have the live quote ready here.\n\nYou can review it here: https://example.com/quote/13639\n\nReview the live quote and let me know if you want us to move forward.",
  "reference_links": [{"label":"13639 Cove Brewery merch quote","url":"https://example.com/quote/13639"}],
  "quote_binding_patch": {
    "quote_subject": "13639 Cove Brewery merch quote",
    "quote_url": "https://example.com/quote/13639",
    "job_number": "13639",
    "job_nickname": "Cove Brewery merch quote",
    "customer_email": "marketing@covebrewery.com",
    "customer_name": "Spencer Todd"
  },
  "provider_receipts": {}
}
EOF

cat >"$SPINE_STATE/mint/customer-lifecycle-resolutions/records/2026/03/14/MCLR-GUIDED.json" <<'EOF'
{
  "lifecycle_id": "MCLR-GUIDED",
  "lifecycle_state": "estimate_ready_pending_quote_creation",
  "confidence": "high",
  "reply_mode": "guided_estimate",
  "draft_allowed": true,
  "customer_safe_next_step": "Confirm the lane so I can turn it into the formal quote.",
  "operator_next_action": "Turn the estimate into the formal quote once the customer confirms the style lane.",
  "current_action": "",
  "blockers": [],
  "generated_body": "",
  "reference_links": [],
  "quote_binding_patch": {
    "quote_subject": "13639 Cove Brewery merch quote",
    "quote_url": "",
    "job_number": "13639",
    "job_nickname": "Cove Brewery merch quote",
    "customer_email": "marketing@covebrewery.com",
    "customer_name": "Spencer Todd"
  },
  "provider_receipts": {}
}
EOF

cat >"$SPINE_STATE/mint/customer-lifecycle-resolutions/records/2026/03/14/MCLR-MARWAN.json" <<'EOF'
{
  "lifecycle_id": "MCLR-MARWAN",
  "lifecycle_state": "estimate_ready_pending_quote_creation",
  "confidence": "medium",
  "reply_mode": "guided_estimate",
  "draft_allowed": true,
  "customer_email": "marketing@covebrewery.com",
  "customer_name": "Spencer Todd",
  "customer_safe_next_step": "Confirm the lane so I can turn it into the formal quote.",
  "operator_next_action": "Turn the estimate into the formal quote once the customer confirms the style lane.",
  "current_action": "",
  "blockers": [],
  "generated_body": "",
  "reference_links": [],
  "quote_context": {
    "packet_id": "packet-cove"
  },
  "quote_binding_patch": {
    "quote_subject": "13639 Cove Brewery merch quote",
    "quote_url": "",
    "job_number": "13639",
    "job_nickname": "Cove Brewery merch quote",
    "packet_id": "packet-cove",
    "customer_email": "marketing@covebrewery.com",
    "customer_name": "Spencer Todd"
  },
  "provider_receipts": {}
}
EOF

cat >"$SPINE_STATE/mint/customer-lifecycle-resolutions/records/2026/03/14/MCLR-HOLD.json" <<EOF
{
  "lifecycle_id": "MCLR-HOLD",
  "lifecycle_state": "needs_manual_resolution",
  "confidence": "low",
  "state_basis": ["anchor_conflict:outbound binding packet does not match lifecycle packet"],
  "reply_mode": "formal_quote_ready",
  "draft_allowed": false,
  "customer_email": "phusecream7@gmail.com",
  "customer_name": "Catherine",
  "customer_safe_next_step": "",
  "operator_next_action": "",
  "current_action": "",
  "blockers": ["Need governed lifecycle resolution before I can pick the next customer-safe step."],
  "generated_body": "",
  "reference_links": [],
  "quote_context": {
    "packet_id": "packet-hold"
  },
  "quote_binding_patch": {
    "packet_id": "packet-stale",
    "customer_email": "phusecream7@gmail.com",
    "customer_name": "Catherine"
  },
  "repair_item": {
    "issue_type": "lifecycle_anchor_mismatch",
    "record_file": "$SPINE_STATE/mint/customer-repair-items/records/2026/03/14/MCRI-HOLD.json"
  },
  "provider_receipts": {}
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
{"id":"MSG-COVE","subject":"Merch Quote Request - Cove Brewery","conversationId":"CONV-COVE","internetMessageId":"<cove@example.com>","from":{"emailAddress":{"address":"marketing@covebrewery.com","name":"Spencer Todd"}},"toRecipients":[{"emailAddress":{"address":"team@mintprints.com"}}],"ccRecipients":[],"body":{"contentType":"HTML","content":"<div>Need quote help</div>"}}
JSON
        ;;
      MSG-GUIDED)
        cat <<'JSON'
{"id":"MSG-GUIDED","subject":"Merch Quote Request - Cove Brewery","conversationId":"CONV-GUIDED","internetMessageId":"<guided@example.com>","from":{"emailAddress":{"address":"marketing@covebrewery.com","name":"Spencer Todd"}},"toRecipients":[{"emailAddress":{"address":"team@mintprints.com"}}],"ccRecipients":[],"body":{"contentType":"HTML","content":"<div>Need quote help</div>"}}
JSON
        ;;
      MSG-MARWAN)
        cat <<'JSON'
{"id":"MSG-MARWAN","subject":"Fw: Print Request","conversationId":"CONV-MARWAN","internetMessageId":"<marwan@example.com>","from":{"emailAddress":{"address":"marwan@icosf.org","name":"Marwan Hussain"}},"toRecipients":[{"emailAddress":{"address":"team@mintprints.com"}}],"ccRecipients":[],"body":{"contentType":"HTML","content":"<div>Need vinyl floor signage for the masjid</div>"}}
JSON
        ;;
      MSG-HOLD)
        cat <<'JSON'
{"id":"MSG-HOLD","subject":"Re: Quote follow-up","conversationId":"CONV-HOLD","internetMessageId":"<hold@example.com>","from":{"emailAddress":{"address":"phusecream7@gmail.com","name":"Catherine"}},"toRecipients":[{"emailAddress":{"address":"team@mintprints.com"}}],"ccRecipients":[],"body":{"contentType":"HTML","content":"<div>Can you send the 200pc option too?</div>"}}
JSON
        ;;
      DRAFT-1)
        python3 - <<'PY' "${SPINE_STATE}/draft-body.txt" "${SPINE_STATE}/draft-subject.txt" "${SPINE_STATE}/draft-content-type.txt" "${SPINE_STATE}/draft-to.txt" "${SPINE_STATE}/draft-cc.txt"
from pathlib import Path
import json
import sys

body = Path(sys.argv[1]).read_text(encoding="utf-8") if Path(sys.argv[1]).exists() else "<div>Quoted thread</div>"
subject = Path(sys.argv[2]).read_text(encoding="utf-8") if Path(sys.argv[2]).exists() else "Re: Merch Quote Request - Cove Brewery"
content_type = Path(sys.argv[3]).read_text(encoding="utf-8") if Path(sys.argv[3]).exists() else "HTML"
draft_to = Path(sys.argv[4]).read_text(encoding="utf-8").strip() if Path(sys.argv[4]).exists() else "marketing@covebrewery.com"
draft_cc = Path(sys.argv[5]).read_text(encoding="utf-8").strip() if Path(sys.argv[5]).exists() else ""

def parse_csv(text):
    out = []
    for item in text.split(","):
        cleaned = item.strip()
        if cleaned:
            out.append({"emailAddress": {"address": cleaned}})
    return out

payload = {
    "id": "DRAFT-1",
    "subject": subject,
    "conversationId": "CONV-COVE",
    "toRecipients": parse_csv(draft_to),
    "ccRecipients": parse_csv(draft_cc),
    "body": {"contentType": content_type, "content": body},
}
print(json.dumps(payload))
PY
        ;;
      *)
        echo "unexpected microsoft.mail.get id: $message_id" >&2
        exit 1
        ;;
    esac
    ;;
  mint.customer.lifecycle.resolve)
    echo "lifecycle resolve should not be called when governed lifecycle state already exists" >&2
    exit 1
    ;;
  mint.customer.record.snapshot)
    email=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --email) email="$2"; shift 2 ;;
        --json) shift ;;
        *) shift ;;
      esac
    done
    if [[ "$email" == "marwan@icosf.org" ]]; then
      cat <<'JSON'
{"capability":"mint.customer.record.snapshot","query_mode":"email","query_value":"marwan@icosf.org","fresh_slate":{"customers":[{"record_id":"cust-marwan","email":"marwan@icosf.org","name":"Marwan Hussain","company":"ICOSF"}],"identity":{"display_name":"Marwan Hussain","legal_name":"Marwan Hussain","email":"marwan@icosf.org"}},"quote_intelligence":{}}
JSON
    else
      cat <<'JSON'
{"capability":"mint.customer.record.snapshot","query_mode":"email","query_value":"marketing@covebrewery.com","fresh_slate":{"customers":[{"record_id":"cust-cove","email":"marketing@covebrewery.com","name":"Spencer Todd","company":"Cove Brewery"}],"identity":{"display_name":"Spencer Todd","greeting_name":"Spencer","legal_name":"Spencer Todd","email":"marketing@covebrewery.com"}},"quote_intelligence":{}}
JSON
    fi
    ;;
  microsoft.mail.reply.draft)
    cat <<'JSON'
{"id":"DRAFT-1","subject":"Re: Merch Quote Request - Cove Brewery","conversationId":"CONV-COVE","toRecipients":[{"emailAddress":{"address":"marketing@covebrewery.com"}}],"ccRecipients":[],"body":{"contentType":"HTML","content":"<div>Quoted thread</div>"}}
JSON
    ;;
  microsoft.mail.draft.update)
    body=""
    subject=""
    to_csv=""
    cc_csv=""
    content_type=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --message-id) shift 2 ;;
        --to) to_csv="$2"; shift 2 ;;
        --cc) cc_csv="$2"; shift 2 ;;
        --subject) subject="$2"; shift 2 ;;
        --body) body="$2"; shift 2 ;;
        --content-type) content_type="$2"; shift 2 ;;
        --mailbox) shift 2 ;;
        *) shift ;;
      esac
    done
    printf '%s' "$body" >"${SPINE_STATE}/draft-body.txt"
    printf '%s' "$subject" >"${SPINE_STATE}/draft-subject.txt"
    printf '%s' "$content_type" >"${SPINE_STATE}/draft-content-type.txt"
    printf '%s' "$to_csv" >"${SPINE_STATE}/draft-to.txt"
    printf '%s' "$cc_csv" >"${SPINE_STATE}/draft-cc.txt"
    python3 - <<'PY' "$subject" "$content_type" "$body" "$to_csv" "$cc_csv"
import json
import sys

def parse_csv(text):
    out = []
    for item in text.split(","):
        cleaned = item.strip()
        if cleaned:
            out.append({"emailAddress": {"address": cleaned}})
    return out

print(json.dumps({
    "id": "DRAFT-1",
    "subject": sys.argv[1],
    "conversationId": "CONV-COVE",
    "toRecipients": parse_csv(sys.argv[4]),
    "ccRecipients": parse_csv(sys.argv[5]),
    "body": {"contentType": sys.argv[2], "content": sys.argv[3]},
}))
PY
    ;;
  microsoft.mail.attachment.add)
    echo "unexpected attachment add" >&2
    exit 1
    ;;
  communications.mail.search)
    echo '{"value":[]}'
    ;;
  *)
    echo "unsupported capability: $capability" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$SPINE_ROOT/bin/ops"

json_out="$("$REPLY" --message-id MSG-COVE --mailbox team@mintprints.com --reply-mode general --author-mode morpheus --json)"

[[ "$(echo "$json_out" | jq -r '.data.reply_mode')" == "formal_quote_ready" ]] || fail "reply mode should be lifecycle-driven formal_quote_ready"
[[ "$(echo "$json_out" | jq -r '.data.lifecycle_context.lifecycle_state')" == "quote_live_pending_customer_response" ]] || fail "reply record should persist lifecycle state"
[[ "$(echo "$json_out" | jq -r '.data.body_input_mode')" == "auto_generated_lifecycle_context" ]] || fail "reply body should come from lifecycle context"
[[ "$(echo "$json_out" | jq -r '.data.quote_binding.quote_url')" == "https://example.com/quote/13639" ]] || fail "quote binding should inherit lifecycle quote url"
[[ "$(echo "$json_out" | jq -r '.data.draft_subject')" == "13639 Cove Brewery merch quote" ]] || fail "subject should be rebuilt from lifecycle quote binding"
grep -q 'I have the live quote ready here.' "${SPINE_STATE}/draft-body.txt" || fail "draft body should include lifecycle-driven live quote text"
grep -q '<a href="https://example.com/quote/13639">13639 Cove Brewery merch quote</a>' "${SPINE_STATE}/draft-body.txt" || fail "draft body should render the lifecycle quote ref as a hyperlink"

guided_json="$("$REPLY" --message-id MSG-GUIDED --mailbox team@mintprints.com --reply-mode general --author-mode morpheus --json)"

[[ "$(echo "$guided_json" | jq -r '.data.reply_mode')" == "guided_estimate" ]] || fail "guided message should resolve to guided_estimate"
[[ "$(echo "$guided_json" | jq -r '.data.body_input_mode')" == "auto_generated_quote_context" ]] || fail "guided body should fall back to quote context when lifecycle body is empty"
grep -q 'Here is the lane I would recommend:' "${SPINE_STATE}/draft-body.txt" || fail "guided draft should render the estimate lane"
grep -q 'about $11.23 each' "${SPINE_STATE}/draft-body.txt" || fail "guided draft should render the estimated unit price from intake truth"

hold_json="$(
  "$REPLY" --message-id MSG-HOLD --mailbox team@mintprints.com --reply-mode formal_quote_ready --author-mode morpheus \
    --job-number 13846 \
    --job-nickname "Phuse Cream 200" \
    --quote-subject "13846 Phuse Cream 200" \
    --quote-url "https://mint-prints-4019cb.printavo.com/invoice/6ffcbebd3178266014a48b4c74e9e055" \
    --current-action "Splitting the garment colors is no issue." \
    --json
)"

[[ "$(echo "$hold_json" | jq -r '.data.reply_mode')" == "formal_quote_ready" ]] || fail "hold fixture should stay formal_quote_ready"
[[ "$(echo "$hold_json" | jq -r '.data.lifecycle_context.draft_allowed')" == "false" ]] || fail "hold fixture should preserve the lifecycle hold"
[[ "$(echo "$hold_json" | jq -r '.data.lifecycle_gate_resolution.mode')" == "override_stale_anchor" ]] || fail "explicit formal quote binding should override a stale lifecycle anchor hold"
[[ "$(echo "$hold_json" | jq -r '.data.quote_binding.packet_id')" == "packet-hold" ]] || fail "override should keep the current governed packet anchor"
[[ "$(echo "$hold_json" | jq -r '.data.signature_mode')" == "canonical_morpheus_signature_with_receipt" ]] || fail "override path must keep governed Morpheus signature mode"
[[ "$(echo "$hold_json" | jq -r '.data.thread_mode')" == "reply_chain" ]] || fail "override path must stay on the reply chain"
grep -q 'Current action: Splitting the garment colors is no issue.' "${SPINE_STATE}/draft-body.txt" || fail "override draft should retain the structured current action"
grep -q '13846 Phuse Cream 200' "${SPINE_STATE}/draft-body.txt" || fail "override draft should include the governed quote reference"

if "$REPLY" --message-id MSG-COVE --mailbox team@mintprints.com --reply-mode general --author-mode morpheus --body "Manual customer prose should be blocked." --json >/dev/null 2>"$tmp/manual-body-error.log"; then
  fail "customer reply draft should block raw Morpheus --body outside the hard draft gate"
fi
grep -F 'blocks freeform --body/--body-file' "$tmp/manual-body-error.log" >/dev/null || fail "manual body rejection should explain the governed draft gate"

marwan_json="$("$REPLY" --message-id MSG-MARWAN --mailbox team@mintprints.com --reply-mode general --author-mode morpheus --json)"

[[ "$(echo "$marwan_json" | jq -r '.data.reply_mode')" == "not_a_fit" ]] || fail "Marwan should resolve to not_a_fit from current quote context"
[[ "$(echo "$marwan_json" | jq -r '.data.source_disposition.disposition')" == "unsupported_scope" ]] || fail "Marwan should classify as unsupported_scope at the source disposition gate"
[[ "$(echo "$marwan_json" | jq -r '.data.job_number')" == "" ]] || fail "Marwan should not inherit a foreign job number"
[[ "$(echo "$marwan_json" | jq -r '.data.draft_subject')" == *"Print Request"* ]] || fail "Marwan should fall back to the reply-chain subject"
[[ "$(echo "$marwan_json" | jq -r '.data.outbound_binding.record_file')" == "null" ]] || fail "unsupported_scope drafts must not create outbound binding truth"
grep -q 'I want to be straight with you about the cleanest lane we can actually support.' "${SPINE_STATE}/draft-body.txt" || fail "Marwan draft should use the governed not_a_fit voice"

manual_marwan_json="$(
  MORPHEUS_ALLOW_UNSAFE_REPLY_OVERRIDE=1 \
  "$REPLY" --message-id MSG-MARWAN --mailbox team@mintprints.com --reply-mode general --author-mode morpheus \
  --body "Yeah, we can help once you send over the clean specs." --json
)"

[[ "$(echo "$manual_marwan_json" | jq -r '.data.reply_mode')" == "not_a_fit" ]] || fail "break-glass unsupported_scope drafts should still keep the governed reply mode"
[[ "$(echo "$manual_marwan_json" | jq -r '.data.body_input_mode')" == "inline" ]] || fail "break-glass draft should preserve the operator-provided body mode"
grep -q 'Greetings Marwan,' "${SPINE_STATE}/draft-body.txt" || fail "greeting fallback should reduce full legal names to a cleaner first-name salutation"
if grep -q 'Greetings Marwan Hussain,' "${SPINE_STATE}/draft-body.txt"; then
  fail "greeting fallback should not keep the full legal name when only a direct sender name is available"
fi
grep -q 'Yeah, we can help once you send over the clean specs.' "${SPINE_STATE}/draft-body.txt" || fail "break-glass manual body should survive the unsupported_scope draft path"
if grep -q 'I want to be straight with you about the cleanest lane we can actually support.' "${SPINE_STATE}/draft-body.txt"; then
  fail "break-glass manual body should not be overwritten by the canned not_a_fit intro"
fi

pass "customer reply draft consumes governed lifecycle truth, blocks raw Morpheus bodies, and preserves unsupported-scope reply-chain subjects"

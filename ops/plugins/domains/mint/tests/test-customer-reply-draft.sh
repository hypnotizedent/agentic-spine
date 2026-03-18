#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
REPLY="$ROOT/ops/plugins/domains/mint/bin/customer-reply-draft"
POLICY_CONTRACT="$ROOT/ops/bindings/mint.customer.reply.draft.policy.contract.yaml"
QUOTE_POLICY_CONTRACT="$ROOT/ops/bindings/mint.quote.intelligence.policy.contract.yaml"
OPERATOR_POLICY_CONTRACT="$ROOT/ops/bindings/mint.customer.operator.policy.contract.yaml"
DISPOSITION_CONTRACT="$ROOT/ops/bindings/mint.customer.inbox.disposition.contract.yaml"
QUOTE_INTAKE_CONTRACT="$ROOT/ops/bindings/mint.customer.quote.intake.contract.yaml"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || fail "jq required"
[[ -x "$REPLY" ]] || fail "missing customer-reply-draft executable"
[[ -f "$POLICY_CONTRACT" ]] || fail "missing governed reply policy contract"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export SPINE_ROOT="$tmp/spine"
export SPINE_STATE="$tmp/state"
export MINT_CUSTOMER_REPLY_DRAFT_POLICY_CONTRACT="$POLICY_CONTRACT"
export MINT_QUOTE_INTELLIGENCE_POLICY_CONTRACT="$QUOTE_POLICY_CONTRACT"
export MINT_CUSTOMER_OPERATOR_POLICY_CONTRACT="$OPERATOR_POLICY_CONTRACT"
export MINT_CUSTOMER_INBOX_DISPOSITION_CONTRACT="$DISPOSITION_CONTRACT"
export MINT_CUSTOMER_QUOTE_INTAKE_CONTRACT="$QUOTE_INTAKE_CONTRACT"
export MORPHEUS_ALLOW_UNSAFE_REPLY_OVERRIDE=1
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
    printf '%s\n' "$message_id" >>"${SPINE_STATE}/mail-get-ids.log"
    case "$message_id" in
      MSG-1)
    cat <<'JSON'
{"id":"MSG-1","subject":"Respect March shirt quote request","conversationId":"CONV-1","internetMessageId":"<msg-1@example.com>","from":{"emailAddress":{"address":"fredofrancis1@icloud.com","name":"Alfred Francis"}},"bodyPreview":"Need 48 shirts for Respect March.","body":{"contentType":"Text","content":"Hi Mint Prints,\\n\\nNeed 48 shirts for Respect March and want to get the quote moving.\\n\\nThanks,\\nAlfred"}}
JSON
        ;;
      MSG-NONJOB)
    cat <<'JSON'
{"id":"MSG-NONJOB","subject":"Design File Request","conversationId":"CONV-2","internetMessageId":"<msg-2@example.com>","from":{"emailAddress":{"address":"fredofrancis1@icloud.com","name":"Alfred Francis"}}}
JSON
        ;;
      MSG-GUIDED)
    cat <<'JSON'
{"id":"MSG-GUIDED","subject":"Merch Quote Request - Cove Brewery","conversationId":"CONV-3","internetMessageId":"<msg-3@example.com>","from":{"emailAddress":{"address":"marketing@covebrewery.com","name":"Spencer Todd"}}}
JSON
        ;;
      MSG-KIARA)
    cat <<'JSON'
{"id":"MSG-KIARA","subject":"Class Reunion Shirt Request","conversationId":"CONV-4","internetMessageId":"<msg-4@example.com>","from":{"emailAddress":{"address":"imanikiara@gmail.com","name":"Kiara Imani"}}}
JSON
        ;;
      MSG-TROY)
    cat <<'JSON'
{"id":"MSG-TROY","subject":"PapaPalooza shirt quote request","conversationId":"CONV-5","internetMessageId":"<msg-5@example.com>","from":{"emailAddress":{"address":"troy@papasrawbar.com","name":"Troy"}},"bodyPreview":"Need 48 tri-blend tees for PapaPalooza.","body":{"contentType":"Text","content":"Need 48 tri-blend tees for PapaPalooza and want to get the quote lane moving."}}
JSON
        ;;
      MSG-KYLE)
    cat <<'JSON'
{"id":"MSG-KYLE","subject":"Full color tee art","conversationId":"CONV-6","internetMessageId":"<msg-6@example.com>","from":{"emailAddress":{"address":"kyle@example.com","name":"Kyle"}},"bodyPreview":"Please quote the attached PNG on 300 black tees.","body":{"contentType":"Text","content":"Please quote the attached PNG on 300 black tees and tell me the cleanest print lane."}}
JSON
        ;;
      MSG-XMAIL)
        echo "message not found in mailbox" >&2
        exit 1
        ;;
      DRAFT-1)
    draft_subject="$(cat "${SPINE_STATE}/last-draft-subject.txt" 2>/dev/null || printf 'Re: Respect March shirt quote request')"
    draft_content_type="$(cat "${SPINE_STATE}/last-draft-content-type.txt" 2>/dev/null || printf 'HTML')"
    draft_body="$(cat "${SPINE_STATE}/last-draft-body.txt" 2>/dev/null || printf '<div>Quoted thread</div>')"
    draft_to="$(cat "${SPINE_STATE}/last-draft-to.txt" 2>/dev/null || printf 'fredofrancis1@icloud.com')"
    draft_cc="$(cat "${SPINE_STATE}/last-draft-cc.txt" 2>/dev/null || printf '')"
        python3 - <<'PY' "${SPINE_STATE}/mail-get-draft.json" "$draft_subject" "$draft_content_type" "$draft_body" "$draft_to" "$draft_cc"
from pathlib import Path
import json
import sys

def parse_csv(text):
    out = []
    for item in text.split(","):
        cleaned = item.strip()
        if cleaned:
            out.append({"emailAddress": {"address": cleaned}})
    return out

payload = {
    "id": "DRAFT-1",
    "subject": sys.argv[2],
    "conversationId": "CONV-1",
    "toRecipients": parse_csv(sys.argv[5]),
    "ccRecipients": parse_csv(sys.argv[6]),
    "body": {
        "contentType": sys.argv[3],
        "content": sys.argv[4],
    },
}
Path(sys.argv[1]).write_text(json.dumps(payload), encoding="utf-8")
PY
        cat "${SPINE_STATE}/mail-get-draft.json"
        ;;
      DRAFT-2)
    draft_subject="$(cat "${SPINE_STATE}/last-draft-subject.txt" 2>/dev/null || printf 'Re: Design File Request')"
    draft_content_type="$(cat "${SPINE_STATE}/last-draft-content-type.txt" 2>/dev/null || printf 'HTML')"
    draft_body="$(cat "${SPINE_STATE}/last-draft-body.txt" 2>/dev/null || printf '<div>Quoted thread</div>')"
        python3 - <<'PY' "${SPINE_STATE}/mail-get-draft.json" "$draft_subject" "$draft_content_type" "$draft_body"
from pathlib import Path
import json
import sys

payload = {
    "id": "DRAFT-2",
    "subject": sys.argv[2],
    "conversationId": "CONV-2",
    "toRecipients": [{"emailAddress": {"address": "fredofrancis1@icloud.com"}}],
    "ccRecipients": [],
    "body": {
        "contentType": sys.argv[3],
        "content": sys.argv[4],
    },
}
Path(sys.argv[1]).write_text(json.dumps(payload), encoding="utf-8")
PY
        cat "${SPINE_STATE}/mail-get-draft.json"
        ;;
      DRAFT-3)
    draft_subject="$(cat "${SPINE_STATE}/last-draft-subject.txt" 2>/dev/null || printf 'Re: Merch Quote Request - Cove Brewery')"
    draft_content_type="$(cat "${SPINE_STATE}/last-draft-content-type.txt" 2>/dev/null || printf 'HTML')"
    draft_body="$(cat "${SPINE_STATE}/last-draft-body.txt" 2>/dev/null || printf '<div>Quoted thread</div>')"
        python3 - <<'PY' "${SPINE_STATE}/mail-get-draft.json" "$draft_subject" "$draft_content_type" "$draft_body"
from pathlib import Path
import json
import sys

payload = {
    "id": "DRAFT-3",
    "subject": sys.argv[2],
    "conversationId": "CONV-3",
    "toRecipients": [{"emailAddress": {"address": "marketing@covebrewery.com"}}],
    "ccRecipients": [],
    "body": {
        "contentType": sys.argv[3],
        "content": sys.argv[4],
    },
}
Path(sys.argv[1]).write_text(json.dumps(payload), encoding="utf-8")
PY
        cat "${SPINE_STATE}/mail-get-draft.json"
        ;;
      DRAFT-4)
    draft_subject="$(cat "${SPINE_STATE}/last-draft-subject.txt" 2>/dev/null || printf 'Re: Class Reunion Shirt Request')"
    draft_content_type="$(cat "${SPINE_STATE}/last-draft-content-type.txt" 2>/dev/null || printf 'HTML')"
    draft_body="$(cat "${SPINE_STATE}/last-draft-body.txt" 2>/dev/null || printf '<div>Quoted thread</div>')"
        python3 - <<'PY' "${SPINE_STATE}/mail-get-draft.json" "$draft_subject" "$draft_content_type" "$draft_body"
from pathlib import Path
import json
import sys

payload = {
    "id": "DRAFT-4",
    "subject": sys.argv[2],
    "conversationId": "CONV-4",
    "toRecipients": [{"emailAddress": {"address": "imanikiara@gmail.com"}}],
    "ccRecipients": [],
    "body": {
        "contentType": sys.argv[3],
        "content": sys.argv[4],
    },
}
Path(sys.argv[1]).write_text(json.dumps(payload), encoding="utf-8")
PY
        cat "${SPINE_STATE}/mail-get-draft.json"
        ;;
      DRAFT-5)
    draft_subject="$(cat "${SPINE_STATE}/last-draft-subject.txt" 2>/dev/null || printf 'Re: PapaPalooza shirt quote request')"
    draft_content_type="$(cat "${SPINE_STATE}/last-draft-content-type.txt" 2>/dev/null || printf 'HTML')"
    draft_body="$(cat "${SPINE_STATE}/last-draft-body.txt" 2>/dev/null || printf '<div>Quoted thread</div>')"
        python3 - <<'PY' "${SPINE_STATE}/mail-get-draft.json" "$draft_subject" "$draft_content_type" "$draft_body"
from pathlib import Path
import json
import sys

payload = {
    "id": "DRAFT-5",
    "subject": sys.argv[2],
    "conversationId": "CONV-5",
    "toRecipients": [{"emailAddress": {"address": "troy@papasrawbar.com"}}],
    "ccRecipients": [],
    "body": {
        "contentType": sys.argv[3],
        "content": sys.argv[4],
    },
}
Path(sys.argv[1]).write_text(json.dumps(payload), encoding="utf-8")
PY
        cat "${SPINE_STATE}/mail-get-draft.json"
        ;;
      DRAFT-6)
    draft_subject="$(cat "${SPINE_STATE}/last-draft-subject.txt" 2>/dev/null || printf 'Re: Full color tee art')"
    draft_content_type="$(cat "${SPINE_STATE}/last-draft-content-type.txt" 2>/dev/null || printf 'HTML')"
    draft_body="$(cat "${SPINE_STATE}/last-draft-body.txt" 2>/dev/null || printf '<div>Quoted thread</div>')"
        python3 - <<'PY' "${SPINE_STATE}/mail-get-draft.json" "$draft_subject" "$draft_content_type" "$draft_body"
from pathlib import Path
import json
import sys

payload = {
    "id": "DRAFT-6",
    "subject": sys.argv[2],
    "conversationId": "CONV-6",
    "toRecipients": [{"emailAddress": {"address": "kyle@example.com"}}],
    "ccRecipients": [],
    "body": {
        "contentType": sys.argv[3],
        "content": sys.argv[4],
    },
}
Path(sys.argv[1]).write_text(json.dumps(payload), encoding="utf-8")
PY
        cat "${SPINE_STATE}/mail-get-draft.json"
        ;;
      *)
        echo "unexpected message id: $message_id" >&2
        exit 1
        ;;
    esac
    ;;
  microsoft.mail.reply.draft)
    message_id=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --message-id) message_id="$2"; shift 2 ;;
        --mailbox) shift 2 ;;
        *) shift ;;
      esac
    done
    case "$message_id" in
      MSG-NONJOB)
    cat <<'JSON'
{"id":"DRAFT-2","subject":"Re: Design File Request","conversationId":"CONV-2","toRecipients":[{"emailAddress":{"address":"fredofrancis1@icloud.com"}}],"body":{"contentType":"HTML","content":"<div>Quoted thread</div>"}}
JSON
        ;;
      MSG-GUIDED)
    cat <<'JSON'
{"id":"DRAFT-3","subject":"Re: Merch Quote Request - Cove Brewery","conversationId":"CONV-3","toRecipients":[{"emailAddress":{"address":"marketing@covebrewery.com"}}],"body":{"contentType":"HTML","content":"<div>Quoted thread</div>"}}
JSON
        ;;
      MSG-KIARA)
    cat <<'JSON'
{"id":"DRAFT-4","subject":"Re: Class Reunion Shirt Request","conversationId":"CONV-4","toRecipients":[{"emailAddress":{"address":"imanikiara@gmail.com"}}],"body":{"contentType":"HTML","content":"<div>Quoted thread</div>"}}
JSON
        ;;
      MSG-TROY)
    cat <<'JSON'
{"id":"DRAFT-5","subject":"Re: papapalooza","conversationId":"CONV-5","toRecipients":[{"emailAddress":{"address":"troy@papasrawbar.com"}}],"body":{"contentType":"HTML","content":"<div>Quoted thread</div>"}}
JSON
        ;;
      MSG-KYLE)
    cat <<'JSON'
{"id":"DRAFT-6","subject":"Re: Full color tee art","conversationId":"CONV-6","toRecipients":[{"emailAddress":{"address":"kyle@example.com"}}],"body":{"contentType":"HTML","content":"<div>Quoted thread</div>"}}
JSON
        ;;
      *)
    cat <<'JSON'
{"id":"DRAFT-1","subject":"Re: New Order","conversationId":"CONV-1","toRecipients":[{"emailAddress":{"address":"fredofrancis1@icloud.com"}}],"body":{"contentType":"HTML","content":"<div>Quoted thread</div>"}}
JSON
        ;;
    esac
    ;;
  microsoft.mail.draft.update)
    body=""
    subject=""
    to=""
    cc=""
    mailbox=""
    content_type=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --message-id) shift 2 ;;
        --to) to="$2"; shift 2 ;;
        --cc) cc="$2"; shift 2 ;;
        --subject) subject="$2"; shift 2 ;;
        --body) body="$2"; shift 2 ;;
        --content-type) content_type="$2"; shift 2 ;;
        --mailbox) mailbox="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    printf '%s' "$body" >"${SPINE_STATE}/last-draft-body.txt"
    printf '%s' "$mailbox" >"${SPINE_STATE}/last-draft-mailbox.txt"
    printf '%s' "$to" >"${SPINE_STATE}/last-draft-to.txt"
    printf '%s' "$cc" >"${SPINE_STATE}/last-draft-cc.txt"
    printf '%s' "$subject" >"${SPINE_STATE}/last-draft-subject.txt"
    printf '%s' "$content_type" >"${SPINE_STATE}/last-draft-content-type.txt"
    python3 - <<'PY' "$subject" "$to" "$cc"
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
    "toRecipients": parse_csv(sys.argv[2]),
    "ccRecipients": parse_csv(sys.argv[3]),
}))
PY
    ;;
  mint.customer.record.snapshot)
    email=""
    name=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --email) email="$2"; shift 2 ;;
        --name) name="$2"; shift 2 ;;
        --record-id) shift 2 ;;
        --json) shift ;;
        *) shift ;;
      esac
    done
    if [[ "$email" == "fredofrancis1@icloud.com" ]]; then
      cat <<'JSON'
{"data":{"query_mode":"email","fresh_slate":{"customers":[],"customer_match_count":0},"legacy_hold":{"orders":[]}}}
JSON
      exit 0
    fi
    if [[ "$name" == "Alfred Francis" ]]; then
      cat <<'JSON'
{"data":{"query_mode":"name","fresh_slate":{"customer":{"record_id":"cust-fredo-1","email":"fredofrancis1@gmail.com","name":"Alfred Francis","first_name":"Alfred","last_name":"Francis","company":"Fredo Paints","metadata":{"customer_identity":{"schema_version":"1.0","legal_name":"Alfred Francis","preferred_name":"Fredo","greeting_name":"Fredo","display_name":"Fredo","aliases":["Fredo"],"provenance":{"source":"operator_confirmed","set_by":"ronny","confidence":"high","updated_at_utc":"2026-03-12T16:00:00Z"}}}},"customers":[{"record_id":"cust-fredo-1","email":"fredofrancis1@gmail.com","name":"Alfred Francis","first_name":"Alfred","last_name":"Francis","company":"Fredo Paints","metadata":{"customer_identity":{"schema_version":"1.0","legal_name":"Alfred Francis","preferred_name":"Fredo","greeting_name":"Fredo","display_name":"Fredo","aliases":["Fredo"],"provenance":{"source":"operator_confirmed","set_by":"ronny","confidence":"high","updated_at_utc":"2026-03-12T16:00:00Z"}}}}],"identity":{"schema_version":"1.0","legal_name":"Alfred Francis","preferred_name":"Fredo","greeting_name":"Fredo","display_name":"Fredo","aliases":["Fredo"],"provenance":{"source":"operator_confirmed","set_by":"ronny","confidence":"high","updated_at_utc":"2026-03-12T16:00:00Z"},"record_id":"cust-fredo-1","email":"fredofrancis1@gmail.com","has_customer_facing_name":true},"customer_match_count":1},"legacy_hold":{"orders":[]}}}
JSON
      exit 0
    fi
    cat <<'JSON'
{"data":{"query_mode":"fallback","fresh_slate":{"customers":[],"customer_match_count":0},"legacy_hold":{"orders":[]}}}
JSON
    exit 0
    ;;
  microsoft.mail.attachment.add)
    file=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --message-id) shift 2 ;;
        --file) file="$2"; shift 2 ;;
        --mailbox) shift 2 ;;
        *) shift ;;
      esac
    done
    printf '%s' "$file" >"${SPINE_STATE}/last-attachment-file.txt"
    printf '{"id":"ATT-1","name":"%s","size":%s,"contentType":"application/pdf"}\n' "$(basename "$file")" "$(wc -c <"$file" | tr -d ' ')"
    ;;
  *)
    echo "unsupported capability: $capability" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$SPINE_ROOT/bin/ops"

mkdir -p "$SPINE_STATE/mint/customer-quote-intakes/records/2026/03/13" "$tmp/packets"
cat >"$tmp/packets/quote_packet_guided.yaml" <<'EOF'
quote_packet_id: packet-guided
line_items:
  - line_item_id: li-guided-1
    description: Dry-Fit Tee - Silver
    brand: A4
    style_code: A4N3165
    decoration_method: screen_print
    quantity: 12
  - line_item_id: li-guided-2
    description: Cotton Tee - White
    brand: Gildan
    style_code: 5000
    decoration_method: screen_print
    quantity: 12
inventory_snapshot:
  supplier_results:
    - line_item_id: li-guided-1
      brand: A4
      style_code: A4N3165
      stock_available: true
      total_available: 188
    - line_item_id: li-guided-2
      brand: Gildan
      style_code: 5000
      stock_available: true
      total_available: 240
estimate_snapshot:
  estimate_state: completed
  quote_safe_line_item_count: 2
  clarification_needed_count: 0
  line_item_estimates:
    - line_item_id: li-guided-1
      description: Dry-Fit Tee - Silver
      recommended_method: screen_print
      quote_safe_now: true
      confidence_level: high
      estimated_unit_price: 14.25
      missing_clarifications: []
      estimated_decoration_profile:
        size_tier_label: standard_print
        underbase_needed: false
        setup_mode: new_setup
    - line_item_id: li-guided-2
      description: Cotton Tee - White
      recommended_method: screen_print
      quote_safe_now: true
      confidence_level: high
      estimated_unit_price: 9.75
      missing_clarifications: []
      estimated_decoration_profile:
        size_tier_label: standard_print
        underbase_needed: false
        setup_mode: new_setup
EOF

cat >"$tmp/packets/quote_packet_respect.yaml" <<'EOF'
quote_packet_id: packet-respect
customer_ref:
  resolved_email: fredofrancis1@icloud.com
  resolved_name: Alfred Francis
line_items:
  - line_item_id: li-respect-1
    description: Respect March Tee
    brand: Comfort Colors
    style_code: 1717
    decoration_method: screen_print
    quantity: 48
EOF

cat >"$tmp/packets/quote_packet_papapalooza_fredo.yaml" <<'EOF'
quote_packet_id: packet-papapalooza-fredo
customer_ref:
  resolved_email: fredofrancis1@icloud.com
  resolved_name: Alfred Francis
line_items:
  - line_item_id: li-papa-1
    description: PapaPalooza Tee
    brand: Next Level
    style_code: 6010
    decoration_method: screen_print
    quantity: 48
EOF

cat >"$tmp/packets/quote_packet_troy.yaml" <<'EOF'
quote_packet_id: packet-troy
customer_ref:
  resolved_email: troy@papasrawbar.com
  resolved_name: Troy
line_items:
  - line_item_id: li-troy-1
    description: Tri-Blend Tee
    brand: Next Level
    style_code: 6010
    decoration_method: screen_print
    quantity: 48
inventory_snapshot:
  supplier_results:
    - line_item_id: li-troy-1
      brand: Next Level
      style_code: 6010
      stock_available: true
      total_available: 640
      product_url: https://supplier.example/next-level-6010
      color: Black
      variants:
        - color_name: Black
          size_name: M
          quantity_available: 220
        - color_name: Heather Navy
          size_name: M
          quantity_available: 180
        - color_name: Indigo
          size_name: M
          quantity_available: 140
estimate_snapshot:
  estimate_state: completed
  quote_safe_line_item_count: 1
  clarification_needed_count: 0
  line_item_estimates:
    - line_item_id: li-troy-1
      description: Tri-Blend Tee
      recommended_method: screen_print
      quote_safe_now: true
      confidence_level: high
      estimated_unit_price: 11.5
      missing_clarifications: []
      estimated_decoration_profile:
        size_tier_label: standard_print
        underbase_needed: false
        setup_mode: new_setup
EOF

cat >"$tmp/packets/quote_packet_kyle.yaml" <<'EOF'
quote_packet_id: packet-kyle
line_items:
  - line_item_id: li-kyle-1
    description: Black Tee
    brand: Bella + Canvas
    style_code: BC3001
    decoration_method: dtg
    quantity: 300
artwork_analysis:
  state: captured
  summary: Attached art reads as full-color artwork with gradient transitions (about 24 colors, 1200x1200px). At 300 pieces, dtg looks like the cleaner recommendation.
  recommended_print_method: dtg
  recommendation_confidence: high
  recommendation_basis:
    - estimated_color_count>=5
    - gradient_signal
    - piece_quantity_in_range:300
  total_requested_quantity: 300
  attachments:
    - name: kyle-full-color-art.png
      content_type: image/png
      dimensions:
        width_px: 1200
        height_px: 1200
      estimated_color_count: 24
      has_gradients: true
      complexity_score: 0.96
      piece_quantity: 300
      recommended_print_method: dtg
      recommendation_confidence: high
      recommendation_basis:
        - estimated_color_count>=5
        - gradient_signal
        - piece_quantity_in_range:300
EOF

cat >"$tmp/packets/quote_packet_kiara.yaml" <<'EOF'
quote_packet_id: packet-kiara
line_items:
  - line_item_id: li-kiara-1
    description: White Cotton Tee
    brand: Gildan
    style_code: 5000
    decoration_method: screen_print
  - line_item_id: li-kiara-2
    description: Cruise Dry-Fit Tee
    brand: A4
    style_code: A4N3165
    decoration_method: screen_print
inventory_snapshot:
  supplier_results:
    - line_item_id: li-kiara-1
      brand: Gildan
      style_code: 5000
      stock_available: true
      total_available: 500
    - line_item_id: li-kiara-2
      brand: A4
      style_code: A4N3165
      stock_available: true
      total_available: 190
estimate_snapshot:
  estimate_state: blocked_insufficient_inputs
  quote_safe_line_item_count: 0
  clarification_needed_count: 1
  line_item_estimates:
    - line_item_id: li-kiara-1
      description: White Cotton Tee
      recommended_method: screen_print
      quote_safe_now: false
      confidence_level: medium
      estimated_unit_price:
      missing_clarifications:
        - How many white cotton tees versus dry-fit cruise tees do you need out of the 25 total?
      estimated_decoration_profile:
        size_tier_label: standard_print
        underbase_needed: false
        setup_mode: new_setup
    - line_item_id: li-kiara-2
      description: Cruise Dry-Fit Tee
      recommended_method: screen_print
      quote_safe_now: false
      confidence_level: medium
      estimated_unit_price:
      missing_clarifications:
        - How many white cotton tees versus dry-fit cruise tees do you need out of the 25 total?
      estimated_decoration_profile:
        size_tier_label: standard_print
        underbase_needed: false
        setup_mode: new_setup
EOF

cat >"$SPINE_STATE/mint/customer-quote-intakes/records/2026/03/13/MCQI-GUIDED.json" <<EOF
{"record_file":"$SPINE_STATE/mint/customer-quote-intakes/records/2026/03/13/MCQI-GUIDED.json","intake_id":"MCQI-GUIDED","message_id":"MSG-GUIDED","handoff":{"packet_id":"packet-guided","packet_file":"$tmp/packets/quote_packet_guided.yaml","source_state":"completed","estimate_state":"completed","pricing_state":"blocked_insufficient_inputs"},"intake_quality":{"classification":"ideal"},"qualification_status":"qualified_enough_to_quote","customer_reply_guidance":{"mode":"acknowledge_and_process","summary":"Everything important is already in the thread, so this should move with a recommendation instead of a blank clarification email."},"estimate_surface":{"quote_safe_line_item_count":2,"clarification_needed_count":0}}
EOF

cat >"$SPINE_STATE/mint/customer-quote-intakes/records/2026/03/13/MCQI-TROY.json" <<EOF
{"record_file":"$SPINE_STATE/mint/customer-quote-intakes/records/2026/03/13/MCQI-TROY.json","intake_id":"MCQI-TROY","message_id":"MSG-TROY","customer":{"name":"Troy","email":"troy@papasrawbar.com"},"handoff":{"packet_id":"packet-troy","packet_file":"$tmp/packets/quote_packet_troy.yaml","source_state":"completed","estimate_state":"completed","pricing_state":"blocked_insufficient_inputs"},"intake_quality":{"classification":"ideal"},"qualification_status":"qualified_enough_to_quote","customer_reply_guidance":{"mode":"acknowledge_and_process","summary":"Keep this tight, supplier-backed, and customer-safe."},"estimate_surface":{"quote_safe_line_item_count":1,"clarification_needed_count":0}}
EOF

cat >"$SPINE_STATE/mint/customer-quote-intakes/records/2026/03/13/MCQI-KIARA.json" <<EOF
{"record_file":"$SPINE_STATE/mint/customer-quote-intakes/records/2026/03/13/MCQI-KIARA.json","intake_id":"MCQI-KIARA","message_id":"MSG-KIARA","handoff":{"packet_id":"packet-kiara","packet_file":"$tmp/packets/quote_packet_kiara.yaml","source_state":"completed","estimate_state":"blocked_insufficient_inputs","pricing_state":"blocked_insufficient_inputs"},"intake_quality":{"classification":"workable"},"qualification_status":"clarification_needed","customer_reply_guidance":{"mode":"ask_targeted_blocker_only","summary":"We can help with the cotton and dry-fit shirts, but we should only ask for the missing split instead of rehashing the full request."},"estimate_surface":{"quote_safe_line_item_count":0,"clarification_needed_count":1}}
EOF

cat >"$SPINE_STATE/mint/customer-quote-intakes/records/2026/03/13/MCQI-KYLE.json" <<EOF
{"record_file":"$SPINE_STATE/mint/customer-quote-intakes/records/2026/03/13/MCQI-KYLE.json","intake_id":"MCQI-KYLE","message_id":"MSG-KYLE","customer":{"name":"Kyle","email":"kyle@example.com"},"handoff":{"packet_id":"packet-kyle","packet_file":"$tmp/packets/quote_packet_kyle.yaml","source_state":"not_attempted","estimate_state":"not_attempted","pricing_state":"not_attempted"},"intake_quality":{"classification":"workable"},"qualification_status":"qualified_enough_to_quote","customer_reply_guidance":{"mode":"ask_targeted_blocker_only","summary":"Ask only for the smallest missing structured blocker.","blockers":["final garment color","timeline"]},"estimate_surface":{"quote_safe_line_item_count":0,"clarification_needed_count":1},"artwork_surface":{"artwork_preflight":{"state":"captured","owner":"Artie","summary":"Attached art reads as full-color artwork with gradient transitions (about 24 colors, 1200x1200px). At 300 pieces, dtg looks like the cleaner recommendation.","customer_summary":"Attached art reads as full-color artwork with gradient transitions (about 24 colors, 1200x1200px). At 300 pieces, dtg looks like the cleaner recommendation.","recommended_print_method":"dtg","recommendation_confidence":"high","attachments":[{"name":"kyle-full-color-art.png","estimated_color_count":24,"has_gradients":true}]},"attachment_intelligence":{"state":"captured","owner":"Artie","summary":"Attached art reads as full-color artwork with gradient transitions (about 24 colors, 1200x1200px). At 300 pieces, dtg looks like the cleaner recommendation.","customer_summary":"Attached art reads as full-color artwork with gradient transitions (about 24 colors, 1200x1200px). At 300 pieces, dtg looks like the cleaner recommendation.","recommended_print_method":"dtg","recommendation_confidence":"high","attachments":[{"name":"kyle-full-color-art.png","estimated_color_count":24,"has_gradients":true}]}}}
EOF

cat >"$SPINE_STATE/mint/customer-quote-intakes/index.ndjson" <<EOF
{"message_id":"MSG-GUIDED","record_file":"$SPINE_STATE/mint/customer-quote-intakes/records/2026/03/13/MCQI-GUIDED.json","stored_at_utc":"2026-03-13T15:45:00Z"}
{"message_id":"MSG-TROY","record_file":"$SPINE_STATE/mint/customer-quote-intakes/records/2026/03/13/MCQI-TROY.json","stored_at_utc":"2026-03-13T15:45:30Z"}
{"message_id":"MSG-KIARA","record_file":"$SPINE_STATE/mint/customer-quote-intakes/records/2026/03/13/MCQI-KIARA.json","stored_at_utc":"2026-03-13T15:46:00Z"}
{"message_id":"MSG-KYLE","record_file":"$SPINE_STATE/mint/customer-quote-intakes/records/2026/03/13/MCQI-KYLE.json","stored_at_utc":"2026-03-13T15:46:30Z"}
EOF

json_out="$("$REPLY" MSG-1 \
  --body '<p>Hi Alfred, I have your <a href="https://example.test/q/13839">quote linked here</a>.</p>' \
  --mailbox team@mintprints.com \
  --customer "Respect March" \
  --job "13839 Respect march" \
  --job-number 13839 \
  --job-nickname "Respect march" \
  --quote-subject "13839 Respect march" \
  --packet-file "$tmp/packets/quote_packet_respect.yaml" \
  --json)"
record_file="$(echo "$json_out" | jq -r '.data.record_file')"
body_file="$SPINE_STATE/last-draft-body.txt"

[[ "$(echo "$json_out" | jq -r '.data.author_mode')" == "morpheus" ]] || fail "default author mode should be morpheus"
[[ "$(echo "$json_out" | jq -r '.data.draft_verified')" == "true" ]] || fail "draft must be verified by readback"
[[ "$(echo "$json_out" | jq -r '.data.coherence_passed')" == "true" ]] || fail "draft must pass coherence review before writeback"
[[ "$(echo "$json_out" | jq -r '.data.requested_content_type')" == "HTML" ]] || fail "policy should default body content mode to HTML"
[[ "$(echo "$json_out" | jq -r '.data.draft_subject')" == "13839 Respect march" ]] || fail "subject should follow governed format"
[[ "$(echo "$json_out" | jq -r '.data.draft_mode')" == "confirming" ]] || fail "quote-link drafts should reevaluate into confirming mode"
[[ "$(echo "$json_out" | jq -r '.data.draft_state.quote_link_present')" == "true" ]] || fail "draft state should capture quote link presence"
echo "$json_out" | jq -e '.data.outbound_receipt_id | startswith("MOR-OUT-")' >/dev/null || fail "visible outbound receipt id should be surfaced"
[[ -f "$record_file" ]] || fail "record file should exist"
grep -F '<a href="https://example.test/q/13839">' "$body_file" >/dev/null || fail "HTML body should preserve hyperlinks without needing --content-type HTML"
grep -F 'Greetings Fredo,' "$body_file" >/dev/null || fail "draft helper should use governed greeting name by default"
grep -F 'Alfred' "$body_file" >/dev/null && fail "draft helper should not keep the raw legal name when greeting truth exists"
grep -F 'MORPHEUS (Mint Prints operational intelligence)' "$body_file" >/dev/null || fail "default draft should include governed Morpheus signature"
grep -F 'Receipt: MOR-OUT-' "$body_file" >/dev/null || fail "default draft should include visible receipt id"
grep -F '<p><br>MORPHEUS (Mint Prints operational intelligence)<br>Receipt: MOR-OUT-' "$body_file" >/dev/null || fail "default draft should keep a visual separator before the Morpheus signature"
grep -F 'Ronny' "$body_file" >/dev/null && fail "default draft should not sign as Ronny"
grep -F 'Quoted thread' "$body_file" >/dev/null || fail "reply draft should preserve quoted chain"
[[ "$(jq -r '.author_mode' "$record_file")" == "morpheus" ]] || fail "record should store morpheus author mode"
[[ "$(jq -r '.thread_mode' "$record_file")" == "reply_chain" ]] || fail "record should store reply chain mode"
[[ "$(jq -r '.draft_verified' "$record_file")" == "true" ]] || fail "record should persist draft verification"
[[ "$(jq -r '.customer' "$record_file")" == "Respect March" ]] || fail "record should keep customer association"
[[ "$(jq -r '.job' "$record_file")" == "13839 Respect march" ]] || fail "record should keep job association"
[[ "$(jq -r '.job_number' "$record_file")" == "13839" ]] || fail "record should persist resolved job number"
[[ "$(jq -r '.job_nickname' "$record_file")" == "Respect march" ]] || fail "record should persist resolved job nickname"
[[ "$(jq -r '.policy_contract' "$record_file")" == "$POLICY_CONTRACT" ]] || fail "record should persist governed policy contract path"
[[ "$(jq -r '.agent_identity.presentation' "$record_file")" == "MORPHEUS (Mint Prints operational intelligence)" ]] || fail "record should persist governed Morpheus presentation"
[[ "$(jq -r '.customer_identity_lookup_mode' "$record_file")" == "legal_name_exact" ]] || fail "record should persist name-based identity fallback when email does not match"
[[ "$(jq -r '.customer_identity.greeting_name' "$record_file")" == "Fredo" ]] || fail "record should persist governed greeting name"
[[ "$(jq -r '.provider_receipts.reply_draft_receipt' "$record_file")" == "/tmp/microsoft.mail.reply.draft.receipt.md" ]] || fail "record should keep reply receipt"
[[ "$(jq -r '.provider_receipts.draft_update_receipt' "$record_file")" == "/tmp/microsoft.mail.draft.update.receipt.md" ]] || fail "record should keep draft update receipt"
[[ "$(jq -r '.provider_receipts.draft_readback_receipt' "$record_file")" == "/tmp/microsoft.mail.get.receipt.md" ]] || fail "record should keep draft readback receipt"
mail_get_calls="$(wc -l <"$SPINE_STATE/mail-get-ids.log" | tr -d ' ')"
[[ "$mail_get_calls" -ge 2 ]] || fail "draft creation should perform source and readback microsoft.mail.get calls"

cat >"$tmp/multi-paragraph-body.txt" <<'EOF'
First paragraph line one.
Still the first paragraph line two.

Second paragraph line one.
EOF
json_file_body="$("$REPLY" MSG-1 \
  --body-file "$tmp/multi-paragraph-body.txt" \
  --mailbox team@mintprints.com \
  --job-number 13839 \
  --job-nickname "Respect march" \
  --quote-subject "13839 Respect march" \
  --packet-file "$tmp/packets/quote_packet_respect.yaml" \
  --json)"
file_body="$SPINE_STATE/last-draft-body.txt"
[[ "$(echo "$json_file_body" | jq -r '.data.body_input_mode')" == "file" ]] || fail "body input mode should surface file-backed drafts"
grep -F '<p>First paragraph line one.<br>Still the first paragraph line two.</p><p>Second paragraph line one.</p>' "$file_body" >/dev/null || fail "body-file input should preserve paragraph wrapping without inline HTML hacks"

mkdir -p "$tmp/minio/artwork-intake/jobs/13823 PapaPalooza"
printf 'pdf-bytes' >"$tmp/minio/artwork-intake/jobs/13823 PapaPalooza/papapalooza.pdf"
export MINIO_MOUNT_ROOT="$tmp/minio"
resolved_attach="$(python3 - <<'PY' "$tmp/minio/artwork-intake/jobs/13823 PapaPalooza/papapalooza.pdf"
from pathlib import Path
import sys
print(Path(sys.argv[1]).resolve())
PY
)"
json_attach="$("$REPLY" MSG-1 \
  --body "Please see attached revision." \
  --mailbox team@mintprints.com \
  --job-number 13823 \
  --job-nickname "PapaPalooza" \
  --quote-subject "13823 PapaPalooza" \
  --packet-file "$tmp/packets/quote_packet_papapalooza_fredo.yaml" \
  --attach "$tmp/minio/artwork-intake/jobs/13823 PapaPalooza/papapalooza.pdf" \
  --cc "vendor@example.com" \
  --json)"
attach_record="$(echo "$json_attach" | jq -r '.data.record_file')"
[[ "$(echo "$json_attach" | jq -r '.data.attachment_count')" == "1" ]] || fail "attachment count should be surfaced"
[[ "$(echo "$json_attach" | jq -r '.data.draft_state.artwork_present')" == "true" ]] || fail "draft state should record artwork presence from canonical attachments"
[[ "$(cat "$SPINE_STATE/last-attachment-file.txt")" == "$resolved_attach" ]] || fail "attachment path should be passed through"
[[ "$(jq -r '.attachments[0].relative_key' "$attach_record")" == "artwork-intake/jobs/13823 PapaPalooza/papapalooza.pdf" ]] || fail "record should persist canonical attachment key"
[[ "$(jq -r '.provider_receipts.attachment_add_receipts[0]' "$attach_record")" == "/tmp/microsoft.mail.attachment.add.receipt.md" ]] || fail "record should keep attachment receipt"

json_override="$("$REPLY" MSG-1 --body "Operator override." --mailbox team@mintprints.com --author-mode ronny --json)"
override_body="$SPINE_STATE/last-draft-body.txt"
[[ "$(echo "$json_override" | jq -r '.data.author_mode')" == "ronny" ]] || fail "override should persist ronny mode"
grep -F 'Morpheus' "$override_body" >/dev/null && fail "ronny override should not append Morpheus signature"
grep -F 'MORPHEUS (Mint Prints operational intelligence)' "$override_body" >/dev/null && fail "ronny override should not append Morpheus signature block"

json_house="$("$REPLY" MSG-1 \
  --body "We are using the latest PapaPalooza revision for the next correction pass." \
  --mailbox team@mintprints.com \
  --job-number 13823 \
  --job-nickname "PapaPalooza" \
  --quote-subject "13823 PapaPalooza" \
  --packet-file "$tmp/packets/quote_packet_papapalooza_fredo.yaml" \
  --reply-mode delay \
  --current-action "Updating the latest PapaPalooza art revision now" \
  --blocker-question "Should the blue text stay on this version?" \
  --reference-link "Product page=https://example.test/products/pc61" \
  --reference-visual "Color swatch=https://example.test/swatches/navy.jpg" \
  --json)"
house_body="$SPINE_STATE/last-draft-body.txt"
grep -F 'Sorry for the slow follow-up here.' "$house_body" >/dev/null || fail "delay mode should acknowledge delay"
grep -F 'Current action: Updating the latest PapaPalooza art revision now.' "$house_body" >/dev/null || fail "house voice should surface current action"
grep -F 'Only thing we still need from you:' "$house_body" >/dev/null || fail "house voice should scope customer blockers"
grep -F 'https://example.test/products/pc61' "$house_body" >/dev/null || fail "reference links should render in the draft body"
grep -F 'https://example.test/swatches/navy.jpg' "$house_body" >/dev/null || fail "visual references should render in the draft body"
echo "$json_house" | jq -e '.data.reply_mode == "delay" and (.data.reference_links | length) == 1 and (.data.reference_visuals | length) == 1' >/dev/null || fail "reply output should expose structured references and reply mode"

json_terms="$("$REPLY" MSG-1 \
  --body "Please send the photo files so we can keep moving." \
  --mailbox team@mintprints.com \
  --job-number 13823 \
  --job-nickname "PapaPalooza" \
  --quote-subject "13823 PapaPalooza" \
  --packet-file "$tmp/packets/quote_packet_papapalooza_fredo.yaml" \
  --json)"
terms_body="$SPINE_STATE/last-draft-body.txt"
grep -F 'print-ready artwork (PNG or PDF)' "$terms_body" >/dev/null || fail "house terminology should rewrite photo files"
grep -F 'photo files' "$terms_body" >/dev/null && fail "draft body should not keep banned artwork wording"
[[ "$(echo "$json_terms" | jq -r '.data.terminology_replacements[0]')" == "photo files" ]] || fail "reply output should expose terminology replacement receipts"

if "$REPLY" MSG-1 \
  --body '<p>Hi Fredo, I have your <a href="https://example.test/q/13839">quote linked here</a>. I am still preparing the quote and will send it once it is ready.</p>' \
  --mailbox team@mintprints.com \
  --job-number 13839 \
  --job-nickname "Respect march" \
  --quote-subject "13839 Respect march" \
  --packet-file "$tmp/packets/quote_packet_respect.yaml" >/dev/null 2>"$tmp/quote-coherence-error.log"; then
  fail "quote-link drafts should fail if they still speak in preparing-the-quote mode"
fi
grep -F 'draft coherence check failed: quote_link_present conflicts with quote-preparing wording' "$tmp/quote-coherence-error.log" >/dev/null || fail "quote-link contradiction should explain the coherence failure"

if "$REPLY" MSG-1 \
  --body 'Payment received here. Please use the payment link to complete payment.' \
  --mailbox team@mintprints.com \
  --job-number 13839 \
  --job-nickname "Respect march" \
  --quote-subject "13839 Respect march" \
  --packet-file "$tmp/packets/quote_packet_respect.yaml" \
  --reply-mode in_progress \
  --current-action "Production is moving now" >/dev/null 2>"$tmp/payment-coherence-error.log"; then
  fail "payment-confirmed drafts should fail if they still ask for payment"
fi
grep -F 'draft coherence check failed: payment confirmed conflicts with payment-request wording' "$tmp/payment-coherence-error.log" >/dev/null || fail "payment contradiction should explain the coherence failure"

if "$REPLY" MSG-1 \
  --body 'Please send the logo and we can keep it moving.' \
  --mailbox team@mintprints.com \
  --job-number 13823 \
  --job-nickname "PapaPalooza" \
  --quote-subject "13823 PapaPalooza" \
  --packet-file "$tmp/packets/quote_packet_papapalooza_fredo.yaml" \
  --attach "$tmp/minio/artwork-intake/jobs/13823 PapaPalooza/papapalooza.pdf" >/dev/null 2>"$tmp/artwork-coherence-error.log"; then
  fail "artwork-present drafts should fail if they still ask for the logo"
fi
grep -F 'draft coherence check failed: artwork present conflicts with artwork-request wording' "$tmp/artwork-coherence-error.log" >/dev/null || fail "artwork contradiction should explain the coherence failure"

if "$REPLY" MSG-1 --body "I hope this email finds you well." --mailbox team@mintprints.com --job-number 13823 --job-nickname "PapaPalooza" --quote-subject "13823 PapaPalooza" --packet-file "$tmp/packets/quote_packet_papapalooza_fredo.yaml" >/dev/null 2>&1; then
  fail "generic filler should be blocked in Morpheus mode"
fi

if "$REPLY" MSG-1 \
  --mailbox team@mintprints.com \
  --reply-mode formal_quote_ready \
  --quote-url "https://example.test/invoice/13825" >/dev/null 2>"$tmp/formal-quote-subject-error.log"; then
  fail "formal_quote_ready should refuse reply-chain subject fallback when governed quote subject context is missing"
fi
grep -F 'Need governed job context or an existing reply-chain subject.' "$tmp/formal-quote-subject-error.log" >/dev/null || fail "formal_quote_ready should explain the governed subject blocker"

json_quote_ready="$("$REPLY" MSG-1 \
  --mailbox team@mintprints.com \
  --reply-mode formal_quote_ready \
  --job-number 13825 \
  --job-nickname "Freedland Scrubs" \
  --quote-subject "13825 Freedland Scrubs" \
  --quote-url "https://example.test/invoice/13825" \
  --packet-file "$tmp/packets/quote_packet_respect.yaml" \
  --json)"
quote_ready_body="$SPINE_STATE/last-draft-body.txt"
[[ "$(echo "$json_quote_ready" | jq -r '.data.reply_mode')" == "formal_quote_ready" ]] || fail "formal quote replies should preserve the governed formal_quote_ready mode"
[[ "$(echo "$json_quote_ready" | jq -r '.data.body_generation_mode')" == "structured_formal_quote_ready" ]] || fail "formal quote replies should render from structured quote bindings without requiring a freeform body"
[[ "$(echo "$json_quote_ready" | jq -r '.data.draft_subject')" == "13825 Freedland Scrubs" ]] || fail "formal quote replies should use the governed quote subject"
grep -F 'I have your quote linked here.' "$quote_ready_body" >/dev/null || fail "formal quote replies should add the governed quote-linked intro"
grep -F 'I have the quote lane cleaned up and ready to finalize.' "$quote_ready_body" >/dev/null || fail "formal quote replies should use the governed formal-quote intro"
grep -F 'https://example.test/invoice/13825' "$quote_ready_body" >/dev/null || fail "formal quote replies should render the governed quote link"
grep -F 'MORPHEUS (Mint Prints operational intelligence)' "$quote_ready_body" >/dev/null || fail "formal quote replies should keep the governed Morpheus footer"
grep -F 'Best,' "$quote_ready_body" >/dev/null && fail "formal quote replies should not fall back to a manual signoff"

json_guided="$("$REPLY" MSG-GUIDED --mailbox team@mintprints.com --json)"
guided_body="$SPINE_STATE/last-draft-body.txt"
[[ "$(echo "$json_guided" | jq -r '.data.reply_mode')" == "guided_estimate" ]] || fail "estimate-ready quote context should auto-switch into guided_estimate"
[[ "$(echo "$json_guided" | jq -r '.data.body_generation_mode')" == "auto_generated_quote_context" ]] || fail "guided_estimate should auto-generate the body from quote context"
[[ "$(echo "$json_guided" | jq -r '.data.quote_context.packet_id')" == "packet-guided" ]] || fail "guided_estimate should surface packet context"
grep -F 'Roughly $9.75-$14.25 per shirt based on the blanks below.' "$guided_body" >/dev/null || fail "guided_estimate should expose the rough per-shirt lane"
grep -F 'Dry-Fit Tee - Silver: A4 A4N3165 screen print, about $14.25 each.' "$guided_body" >/dev/null || fail "guided_estimate should show a supplier-backed blank, method, and price"
grep -F 'Current availability looks good.' "$guided_body" >/dev/null || fail "guided_estimate should surface availability cleanly"
grep -F 'Supplier-backed colors in sync: A4N3165.' "$guided_body" >/dev/null && fail "guided_estimate should not invent colors from style codes"
grep -F 'Cotton Tee - White: Gildan 5000 screen print, about $9.75 each.' "$guided_body" >/dev/null || fail "guided_estimate should show multiple recommended style lanes"
grep -F 'Estimate assumes standard print sizing unless you want a different placement or scale.' "$guided_body" >/dev/null || fail "guided_estimate should surface core assumptions"
grep -F 'If this lane looks right, reply with the styles and color you want and I will turn it into the formal quote.' "$guided_body" >/dev/null || fail "guided_estimate should end with one minimum next step"

json_troy_guided="$("$REPLY" MSG-TROY --mailbox team@mintprints.com --json)"
troy_guided_body="$SPINE_STATE/last-draft-body.txt"
[[ "$(echo "$json_troy_guided" | jq -r '.data.reply_mode')" == "guided_estimate" ]] || fail "Troy proving case should auto-switch into guided_estimate when supplier truth exists"
grep -F 'Tri-Blend Tee: Next Level 6010 screen print, about $11.50 each.' "$troy_guided_body" >/dev/null || fail "Troy guided estimate should use the sourced blank and estimate"
grep -F 'Supplier-backed colors in sync: Black, Heather Navy, Indigo.' "$troy_guided_body" >/dev/null || fail "Troy guided estimate should use governed supplier color truth"

json_kyle="$("$REPLY" MSG-KYLE --mailbox team@mintprints.com --json)"
kyle_body="$SPINE_STATE/last-draft-body.txt"
[[ "$(echo "$json_kyle" | jq -r '.data.quote_context.artwork_analysis.recommended_print_method')" == "dtg" ]] || fail "quote context should surface attachment intelligence into the draft lane"
[[ "$(echo "$json_kyle" | jq -r '.data.quote_context.artwork_analysis.owner')" == "Artie" ]] || fail "quote context artwork truth should remain Artie-owned"
[[ "$(echo "$json_kyle" | jq -r '.data.body_generation_mode')" == "structured_clarification_only" ]] || fail "clarification_only should render from the structured blocker path"
grep -F 'Can you confirm the final garment color?' "$kyle_body" >/dev/null || fail "clarification_only should ask the first explicit blocker"
grep -F 'dtg looks like the cleaner recommendation.' "$kyle_body" >/dev/null && fail "clarification_only should keep artwork-backed print-method reasoning out of customer copy"
grep -F 'I looked at the artwork you attached' "$kyle_body" >/dev/null && fail "clarification_only should not narrate attachment analysis to the customer"

json_troy_manual="$("$REPLY" MSG-TROY --mailbox team@mintprints.com --reply-mode art_revision --current-action "Reviewing the next revision with art dept now" --body "The art is with Sheik now, and we can hit your April 18th deadline." --json)"
troy_manual_body="$SPINE_STATE/last-draft-body.txt"
grep -F 'Sheik' "$troy_manual_body" >/dev/null && fail "customer-facing drafts should not expose the internal vendor name"
grep -F 'art dept' "$troy_manual_body" >/dev/null || fail "customer-facing drafts should rewrite internal vendor references"
grep -F 'we need this to be green light by the end of March for a smooth April 18th completion' "$troy_manual_body" >/dev/null || fail "deadline wording should use the governed March/April language"

json_kiara="$("$REPLY" MSG-KIARA --mailbox team@mintprints.com --json)"
kiara_body="$SPINE_STATE/last-draft-body.txt"
[[ "$(echo "$json_kiara" | jq -r '.data.reply_mode')" == "clarification_only" ]] || fail "blocked quote context should auto-switch into clarification_only"
[[ "$(echo "$json_kiara" | jq -r '.data.blocker_questions | length')" == "1" ]] || fail "clarification_only should ask one blocker question"
[[ "$(echo "$json_kiara" | jq -r '.data.body_generation_mode')" == "structured_clarification_only" ]] || fail "clarification_only should use the structured blocker path"
grep -F 'How many white cotton tees versus dry-fit cruise tees do you need out of the 25 total?' "$kiara_body" >/dev/null || fail "clarification_only should ask only the missing split"
grep -F 'I can help with the White Cotton Tee and Cruise Dry-Fit Tee lane.' "$kiara_body" >/dev/null && fail "clarification_only should not restate the workable lane"

json_nonjob="$("$REPLY" MSG-NONJOB --body "I can send that file over." --mailbox team@mintprints.com --json)"
[[ "$(echo "$json_nonjob" | jq -r '.data.draft_subject')" == "Re: Design File Request" ]] || fail "non-job threads should keep the reply-chain subject when no governed job context exists"
[[ "$(echo "$json_nonjob" | jq -r '.data.subject_source')" == "reply_chain_subject" ]] || fail "non-job subject fallback should be explicit"

if "$REPLY" MSG-1 --body "Need subject resolution." --mailbox team@mintprints.com --job-number 13839 --job-nickname "Respect march" --quote-subject "13839 Respect march" --packet-file "$tmp/packets/quote_packet_respect.yaml" --subject "Design File Request" >/dev/null 2>"$tmp/subject-error.log"; then
  fail "explicit Morpheus subject overrides should still respect the governed contract"
fi
grep -F 'subject must match governed format [job number] [job nickname]' "$tmp/subject-error.log" >/dev/null || fail "invalid subject override should remain governed"

if "$REPLY" MSG-1 --body "Wrong mailbox" --mailbox ronny@mintprints.com >/dev/null 2>&1; then
  fail "morpheus mode should reject ronny mailbox"
fi

if "$REPLY" MSG-XMAIL --body "Wrong message id" --mailbox team@mintprints.com --job-number 13823 --job-nickname "PapaPalooza" >/dev/null 2>"$tmp/xmail-error.log"; then
  fail "cross-mailbox message ids should fail with explicit guidance"
fi
grep -F 'Use the message id from team@mintprints.com.' "$tmp/xmail-error.log" >/dev/null || fail "cross-mailbox failures should explain the same-mailbox thread requirement"

pass "customer-reply-draft preserves multi-paragraph HTML formatting, falls back to reply-chain subjects for non-job inquiries, and preserves governed Morpheus provenance"

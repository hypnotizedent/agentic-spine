#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
BRIEF="$ROOT/ops/plugins/domains/mint/bin/customer-quote-brief"
QUOTE_POLICY_CONTRACT="$ROOT/ops/bindings/mint.quote.intelligence.policy.contract.yaml"
OPERATOR_POLICY_CONTRACT="$ROOT/ops/bindings/mint.customer.operator.policy.contract.yaml"
QUOTE_BRIEF_CONTRACT="$ROOT/ops/bindings/mint.customer.quote.brief.contract.yaml"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || fail "jq required"
[[ -x "$BRIEF" ]] || fail "missing customer-quote-brief executable"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export SPINE_ROOT="$tmp/spine"
export SPINE_STATE="$tmp/state"
export MINT_QUOTE_INTELLIGENCE_POLICY_CONTRACT="$QUOTE_POLICY_CONTRACT"
export MINT_CUSTOMER_OPERATOR_POLICY_CONTRACT="$OPERATOR_POLICY_CONTRACT"
export MINT_CUSTOMER_QUOTE_BRIEF_CONTRACT="$QUOTE_BRIEF_CONTRACT"
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
    cat <<'JSON'
{"id":"MSG-FWD-LINK","subject":"FW: EC embroidery update","conversationId":"CONV-FWD-LINK","from":{"emailAddress":{"address":"team@mintprints.com","name":"Ronny"}},"bodyPreview":"Please quote this embroidery add-on.","body":{"contentType":"Text","content":"Please quote this embroidery add-on.\n\nFrom: Emilio Colon <emilioacolon18@gmail.com>\nSubject: EC embroidery update\n\nHey Ronny,\nWe need 100 pc black polos with the same left chest logo as last time.\nLogo link: https://drive.google.com/file/d/abc123/view?usp=sharing\nCan you update the quote for embroidery?\n"}}
JSON
    ;;
  microsoft.mail.attachments.list)
    cat <<'JSON'
{"value":[]}
JSON
    ;;
  mint.customer.record.snapshot)
    cat <<'JSON'
{"data":{"quote_intelligence":{"customer_context_match":{"matched":false,"match_mode":"none","selector":{},"summary":null,"context":null},"customer_context":null},"legacy_hold":{"latest_order":{"invoice_number":"13639","nickname":"EC polos","legacy_order_row_id":"41001"},"latest_order_imprints":[{"imprint_id":"1","location":"Left Chest","width":"4","height":"4","decoration_type":"transfer","description":"left chest logo","colors_count":1,"line_item_ids":["10"]},{"imprint_id":"2","location":"Full Back","width":"11","height":"11","decoration_type":"transfer","description":"full back","colors_count":1,"line_item_ids":["10"]}]}}}
JSON
    ;;
  *)
    echo "unsupported capability: $capability" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$SPINE_ROOT/bin/ops"

json_out="$("$BRIEF" MSG-FWD-LINK --mailbox team@mintprints.com --json)"
reply_preview="$(echo "$json_out" | jq -r '.data.reply_preview.body_text')"

[[ "$(echo "$json_out" | jq -r '.data.source_artwork_links[0].url')" == "https://drive.google.com/file/d/abc123/view?usp=sharing" ]] || fail "forwarded Drive artwork links should be surfaced as governed source evidence"
[[ "$(echo "$json_out" | jq -r '.data.evidence_recommendation.matched')" == "true" ]] || fail "forwarded artwork links should trigger evidence-first embroidery reasoning"
[[ "$(echo "$json_out" | jq -r '.data.evidence_recommendation.recommended_location')" == "left chest" ]] || fail "forwarded link evidence should still carry forward prior left-chest placement"
[[ "$(echo "$json_out" | jq -r '.data.evidence_recommendation.recommended_width_inches')" == "4" ]] || fail "forwarded link evidence should still recommend the prior embroidery width"
[[ "$reply_preview" == *'I see the logo you shared'* ]] || fail "reply preview should acknowledge shared artwork links without pretending there was an attachment"
echo "$json_out" | jq -e '.data.operator_brief.missing | index("print-ready artwork (PNG or PDF)") | not' >/dev/null || fail "forwarded artwork links should clear the missing-artwork blocker"
echo "$json_out" | jq -e '.data.operator_brief.missing | map(select(test("below house minimum"))) | length == 0' >/dev/null || fail "forwarded 100-piece requests should not be misread as below minimum"

pass "customer-quote-brief uses forwarded artwork links and full forwarded-thread quantity context before flagging missing artwork or below-minimum quantity"

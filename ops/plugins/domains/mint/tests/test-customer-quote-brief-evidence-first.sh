#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
BRIEF="$ROOT/ops/plugins/domains/mint/bin/customer-quote-brief"
QUOTE_POLICY_CONTRACT="$ROOT/ops/bindings/mint.quote.intelligence.policy.contract.yaml"
OPERATOR_POLICY_CONTRACT="$ROOT/ops/bindings/mint.customer.operator.policy.contract.yaml"
QUOTE_BRIEF_CONTRACT="$ROOT/ops/bindings/mint.customer.quote.brief.contract.yaml"
DISPOSITION_CONTRACT="$ROOT/ops/bindings/mint.customer.inbox.disposition.contract.yaml"
QUOTE_INTAKE_CONTRACT="$ROOT/ops/bindings/mint.customer.quote.intake.contract.yaml"

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
export MINT_CUSTOMER_INBOX_DISPOSITION_CONTRACT="$DISPOSITION_CONTRACT"
export MINT_CUSTOMER_QUOTE_INTAKE_CONTRACT="$QUOTE_INTAKE_CONTRACT"
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
{"id":"MSG-MARVELY","subject":"Re: H&C order #13471 embroidery","conversationId":"CONV-MARVELY","from":{"emailAddress":{"address":"marvely@handcimprovements.com","name":"Marvely Gonzalez"}},"body":{"contentType":"Text","content":"Hey Ronny, we want to add embroidery to the polos. I attached the logo for it. Can you update the quote?"},"bodyPreview":"Hey Ronny, we want to add embroidery to the polos. I attached the logo for it. Can you update the quote?"}
JSON
    ;;
  microsoft.mail.attachments.list)
    cat <<'JSON'
{"value":[{"id":"ATT-1","name":"H&C Left Chest Logo.pdf","contentType":"application/pdf","size":24567,"isInline":false}]}
JSON
    ;;
  mint.customer.record.snapshot)
    cat <<'JSON'
{"data":{"quote_intelligence":{"customer_context_match":{"matched":false,"match_mode":"none","selector":{},"summary":null,"context":null},"customer_context":null},"legacy_hold":{"latest_order":{"invoice_number":"13471","nickname":"H&C improvment","legacy_order_row_id":"38052"},"latest_order_imprints":[{"imprint_id":"1","location":"Left Chest","width":"4","height":"4","decoration_type":"transfer","description":"left chest logo","colors_count":1,"line_item_ids":["10"]},{"imprint_id":"2","location":"Full Back","width":"11","height":"11","decoration_type":"transfer","description":"full back","colors_count":1,"line_item_ids":["10"]},{"imprint_id":"3","location":"Left Sleeve","width":"15","height":"15","decoration_type":"transfer","description":"left sleeve","colors_count":1,"line_item_ids":["10"]},{"imprint_id":"4","location":"Right Sleeve","width":"14","height":"14","decoration_type":"transfer","description":"right sleeve","colors_count":1,"line_item_ids":["10"]}]}}}
JSON
    ;;
  *)
    echo "unsupported capability: $capability" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$SPINE_ROOT/bin/ops"

json_out="$("$BRIEF" MSG-MARVELY --mailbox team@mintprints.com --json)"
reply_preview="$(echo "$json_out" | jq -r '.data.reply_preview.body_text')"

[[ "$(echo "$json_out" | jq -r '.data.operator_brief.source_attachments[0]')" == "H&C Left Chest Logo.pdf" ]] || fail "brief should surface source attachment evidence"
[[ "$(echo "$json_out" | jq -r '.data.evidence_recommendation.matched')" == "true" ]] || fail "brief should switch into evidence-first recommendation mode"
[[ "$(echo "$json_out" | jq -r '.data.evidence_recommendation.recommended_location')" == "left chest" ]] || fail "brief should infer left chest carry-forward"
[[ "$(echo "$json_out" | jq -r '.data.evidence_recommendation.recommended_width_inches')" == "4" ]] || fail "brief should recommend 4-inch left chest embroidery"
[[ "$(echo "$json_out" | jq -r '.data.operator_brief.next_step')" == "state the inferred embroidery carry-forward recommendation from attachment + prior-order evidence and ask one confirmation question" ]] || fail "brief should switch next step to assume-and-confirm"
echo "$json_out" | jq -e '.data.operator_brief.missing | index("print-ready artwork (PNG or PDF)") | not' >/dev/null || fail "brief should not ask for artwork when the logo is already attached"
[[ "$reply_preview" == *'I see the logo you attached'* ]] || fail "reply preview should state the attachment evidence"
[[ "$reply_preview" == *'4" wide embroidery on the left chest'* ]] || fail "reply preview should recommend the left chest embroidery size"
[[ "$reply_preview" == *'same 4 print locations as the last order'* ]] || fail "reply preview should carry forward the print setup"
[[ "$reply_preview" == *'Embroidery minimum is 12 pieces.'* ]] || fail "reply preview should surface embroidery minimum"

pass "customer-quote-brief uses attachment + prior-order evidence to recommend and confirm instead of interrogating for embroidery add-ons"

#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
BRIEF="$ROOT/ops/plugins/domains/mint/bin/customer-quote-brief"
POLICY_CONTRACT="$ROOT/ops/bindings/mint.quote.intelligence.policy.contract.yaml"
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
export MINT_QUOTE_INTELLIGENCE_POLICY_CONTRACT="$POLICY_CONTRACT"
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
{"id":"MSG-KYLE","subject":"BC3001 fronts and backs","conversationId":"CONV-KYLE","receivedDateTime":"2026-03-17T14:19:00Z","from":{"emailAddress":{"address":"kyle@example.com","name":"Kyle"}},"body":{"contentType":"Text","content":"Can you quote 300 BC3001 tees with the attached front-and-back art?"}}
JSON
    ;;
  microsoft.mail.attachments.list)
    cat <<'JSON'
{"value":[{"id":"ATT-KYLE-1","name":"kyle-full-color-art.png","contentType":"image/png","size":287331,"isInline":false}]}
JSON
    ;;
  communications.mail.search)
    cat <<'JSON'
{"data":{"microsoft":{"value":[]}}}
JSON
    ;;
  mint.customer.record.snapshot)
    cat <<'JSON'
{"data":{"fresh_slate":{"customer":{"record_id":"cust-kyle","name":"Kyle","company":"Kyle Brand","email":"kyle@example.com"},"identity":{"display_name":"Kyle"}},"legacy_hold":{},"quote_intelligence":{"customer_context_match":{"matched":false,"match_mode":"none","selector":{},"summary":null},"customer_context":{}}}}
JSON
    ;;
  mint.customer.quote.intake)
    cat <<'JSON'
{"data":{"record_file":"/tmp/MCQI-KYLE.json","message_anchor":{"mailbox":"team@mintprints.com","message_id":"MSG-KYLE","conversation_id":"CONV-KYLE","from":"kyle@example.com","subject":"BC3001 fronts and backs","received_at":"2026-03-17T14:19:00Z","normalized_latest_customer_text":"Can you quote 300 BC3001 tees with the attached front-and-back art?"},"artwork_readiness":{"classification":"mockup_reference","basis":["1 non-inline image attachment analyzed"],"artwork_preflight":{"state":"captured","owner":"Artie","summary":"Attached art reads as full-color artwork with gradient transitions (about 24 colors, 1200x1200px). At 300 pieces, dtg looks like the cleaner recommendation.","recommended_print_method":"dtg","recommendation_confidence":"high","attachments":[{"name":"kyle-full-color-art.png","estimated_color_count":24,"has_gradients":true}]},"attachment_intelligence":{"state":"captured","owner":"Artie","summary":"Attached art reads as full-color artwork with gradient transitions (about 24 colors, 1200x1200px). At 300 pieces, dtg looks like the cleaner recommendation.","recommended_print_method":"dtg","recommendation_confidence":"high","attachments":[{"name":"kyle-full-color-art.png","estimated_color_count":24,"has_gradients":true}]}},"artwork_surface":{"classification":"mockup_reference","artwork_preflight":{"state":"captured","owner":"Artie","summary":"Attached art reads as full-color artwork with gradient transitions (about 24 colors, 1200x1200px). At 300 pieces, dtg looks like the cleaner recommendation.","recommended_print_method":"dtg","recommendation_confidence":"high","attachments":[{"name":"kyle-full-color-art.png","estimated_color_count":24,"has_gradients":true}]},"attachment_intelligence":{"state":"captured","owner":"Artie","summary":"Attached art reads as full-color artwork with gradient transitions (about 24 colors, 1200x1200px). At 300 pieces, dtg looks like the cleaner recommendation.","recommended_print_method":"dtg","recommendation_confidence":"high","attachments":[{"name":"kyle-full-color-art.png","estimated_color_count":24,"has_gradients":true}]}},"invoked_modules":[{"module":"microsoft.mail.attachment.download","state":"captured"},{"module":"mint.artwork.preflight","state":"captured"}],"customer_reply_guidance":{"blockers":["final garment color","timeline"]},"supplier_surface":{},"estimate_surface":{},"pricing_surface":{"truth_state":"blocked","price_lane":"","pricing_basis":[]}}}
JSON
    ;;
  mint.customer.seed.ensure)
    cat <<'JSON'
{"data":{"seed":{"id":"seed-kyle-001","status":"new","source":"email"}}}
JSON
    ;;
  *)
    echo "unsupported capability: $capability" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$SPINE_ROOT/bin/ops"

json_out="$("$BRIEF" MSG-KYLE --mailbox team@mintprints.com --json)"
text_out="$("$BRIEF" MSG-KYLE --mailbox team@mintprints.com)"

[[ "$(echo "$json_out" | jq -r '.data.operator_report.module_truth.artwork_truth.attachment_intelligence.state')" == "captured" ]] || fail "operator report should carry captured attachment intelligence"
[[ "$(echo "$json_out" | jq -r '.data.operator_report.module_truth.artwork_truth.artwork_preflight.owner')" == "Artie" ]] || fail "operator report should surface the Artie-owned preflight field"
[[ "$(echo "$json_out" | jq -r '.data.operator_report.module_truth.artwork_truth.attachment_intelligence.recommended_print_method')" == "dtg" ]] || fail "operator report should surface the recommended print method"
[[ "$(echo "$json_out" | jq -r '.data.operator_report.module_truth.artwork_truth.attachment_intelligence.attachments[0].has_gradients')" == "true" ]] || fail "operator report should preserve gradient detection"
[[ "$(echo "$json_out" | jq -r '.data.operator_brief.artwork_preflight_summary')" == "Attached art reads as full-color artwork with gradient transitions (about 24 colors, 1200x1200px). At 300 pieces, dtg looks like the cleaner recommendation." ]] || fail "operator brief should surface the Artie preflight summary"
[[ "$(echo "$json_out" | jq -r '.data.operator_brief.attachment_intelligence_summary')" == "Attached art reads as full-color artwork with gradient transitions (about 24 colors, 1200x1200px). At 300 pieces, dtg looks like the cleaner recommendation." ]] || fail "operator brief should surface the attachment analysis summary"
[[ "$text_out" == *"Artwork analysis: Attached art reads as full-color artwork with gradient transitions (about 24 colors, 1200x1200px). At 300 pieces, dtg looks like the cleaner recommendation."* ]] || fail "text operator report should print artwork analysis"

pass "customer-quote-brief surfaces non-inline attachment intelligence in the operator report"

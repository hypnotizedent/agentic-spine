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
export MINT_INLINE_IMAGE_CONTEXT_FIXTURE_JSON='{"summary":"Inline photo appears to show a sage matching hoodie and sweatpants set with logo placement on the chest and upper leg.","visible_products":["hoodie","sweatpants"],"set_context":"matching_set","colors":["sage"],"decoration_method_guess":"screen_print_puff","decoration_confidence":"medium","customer_reference_resolution":"the customer is likely pointing at the sweatsuit set when saying these.","operator_relevance":["recommend comparable hoodie and sweatpants blanks before asking quote blockers"]}'
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
      MSG-NOROOK)
        cat <<'JSON'
{"id":"MSG-NOROOK","subject":"NoRook Era","conversationId":"CONV-NOROOK","receivedDateTime":"2026-03-17T11:39:00Z","from":{"emailAddress":{"address":"nrmleek@yahoo.com","name":"Maleek Voltaire"}},"body":{"contentType":"Text","content":"Hey you guys have material for these & the trucker hats the NR logo with 3 slashes?"}}
JSON
        ;;
      *)
        echo "unsupported microsoft.mail.get message_id: $message_id" >&2
        exit 1
        ;;
    esac
    ;;
  microsoft.mail.attachments.list)
    cat <<'JSON'
{"value":[{"id":"ATT-NOROOK-1","name":"Outlook-inline.jpg","contentType":"image/jpeg","size":32732,"isInline":true}]}
JSON
    ;;
  microsoft.mail.attachment.download)
    output_dir=""
    attachment_id=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --attachment-id) attachment_id="$2"; shift 2 ;;
        --output-dir) output_dir="$2"; shift 2 ;;
        --message-id|--mailbox) shift 2 ;;
        *) shift ;;
      esac
    done
    mkdir -p "$output_dir"
    file_path="$output_dir/${attachment_id}.jpg"
    python3 - "$file_path" <<'PY'
import base64
import sys
path = sys.argv[1]
png = base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO7Z0ioAAAAASUVORK5CYII=")
open(path, "wb").write(png)
PY
    printf '{"filePath":"%s","sha256":"fixture-inline"}\n' "$file_path"
    ;;
  communications.mail.search)
    cat <<'JSON'
{"data":{"microsoft":{"value":[]}}}
JSON
    ;;
  mint.customer.record.snapshot)
    cat <<'JSON'
{"data":{"fresh_slate":{"customer":{"record_id":"cust-norook","name":"Maleek","company":"NoRook Era","email":"nrmleek@yahoo.com"},"identity":{"display_name":"Maleek"}},"legacy_hold":{},"quote_intelligence":{"customer_context_match":{"matched":false,"match_mode":"none","selector":{},"summary":null},"customer_context":{}}}}
JSON
    ;;
  mint.customer.quote.intake)
    cat <<'JSON'
{"data":{"record_file":"/tmp/MCQI-NOROOK.json","message_anchor":{"mailbox":"team@mintprints.com","message_id":"MSG-NOROOK","conversation_id":"CONV-NOROOK","from":"nrmleek@yahoo.com","subject":"NoRook Era","received_at":"2026-03-17T11:39:00Z","normalized_latest_customer_text":"Hey you guys have material for these & the trucker hats the NR logo with 3 slashes?"},"artwork_readiness":{"classification":"mockup_reference","basis":["1 inline image attachment analyzed"],"inline_image_context":{"state":"captured","summary":"Inline photo appears to show a sage matching hoodie and sweatpants set with logo placement on the chest and upper leg.","visible_products":["hoodie","sweatpants"],"set_context":"matching_set","colors":["sage"],"decoration_method_guess":"screen_print_puff","decoration_confidence":"medium","customer_reference_resolution":"the customer is likely pointing at the sweatsuit set when saying these.","operator_relevance":["recommend comparable hoodie and sweatpants blanks before asking quote blockers"]}},"artwork_surface":{"classification":"mockup_reference","inline_image_context":{"state":"captured","summary":"Inline photo appears to show a sage matching hoodie and sweatpants set with logo placement on the chest and upper leg.","visible_products":["hoodie","sweatpants"],"set_context":"matching_set","colors":["sage"],"decoration_method_guess":"screen_print_puff","decoration_confidence":"medium","customer_reference_resolution":"the customer is likely pointing at the sweatsuit set when saying these.","operator_relevance":["recommend comparable hoodie and sweatpants blanks before asking quote blockers"]}},"invoked_modules":[{"module":"microsoft.mail.attachment.download","state":"captured"}],"customer_reply_guidance":{"blockers":["due date","final quantity confirmation"]},"supplier_surface":{},"estimate_surface":{},"pricing_surface":{}}}
JSON
    ;;
  mint.customer.seed.ensure)
    cat <<'JSON'
{"data":{"seed":{"id":"seed-norook-001","status":"new","source":"email"}}}
JSON
    ;;
  *)
    echo "unsupported capability: $capability" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$SPINE_ROOT/bin/ops"

json_out="$("$BRIEF" MSG-NOROOK --mailbox team@mintprints.com --json)"
text_out="$("$BRIEF" MSG-NOROOK --mailbox team@mintprints.com)"

[[ "$(echo "$json_out" | jq -r '.data.operator_report.module_truth.artwork_truth.inline_image_context.state')" == "captured" ]] || fail "operator report should carry captured inline image context"
[[ "$(echo "$json_out" | jq -r '.data.operator_report.module_truth.artwork_truth.inline_image_context.visible_products[0]')" == "hoodie" ]] || fail "visible products should surface in operator truth"
[[ "$(echo "$json_out" | jq -r '.data.operator_brief.inline_image_context_summary')" == "Inline photo appears to show a sage matching hoodie and sweatpants set with logo placement on the chest and upper leg." ]] || fail "operator brief should surface inline image summary"
[[ "$text_out" == *"Visual context: Inline photo appears to show a sage matching hoodie and sweatpants set with logo placement on the chest and upper leg."* ]] || fail "text operator report should print visual context"

pass "customer-quote-brief surfaces inline-image context in the operator report instead of only attachment names"

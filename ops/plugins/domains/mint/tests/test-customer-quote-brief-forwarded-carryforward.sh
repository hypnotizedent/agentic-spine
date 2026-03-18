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
{"id":"MSG-HC-FWD","subject":"FW: H&C","conversationId":"CONV-HC","from":{"emailAddress":{"address":"Info@mintprints.com","name":"Mint Prints Team"}},"bodyPreview":"From: HC Improvements <outlook_D69A7028C20FC1A0@outlook.com> on behalf of HC Improvements <admin@handcimprovements.com> Good morning Ronny, Please remember to print our telephone number on the top left chest, and do the same for the embroidery.","body":{"contentType":"HTML","content":"<html><body><div><b>From:</b> HC Improvements &lt;outlook_D69A7028C20FC1A0@outlook.com&gt; on behalf of HC Improvements &lt;admin@handcimprovements.com&gt;<br><b>Date:</b> Tuesday, March 10, 2026 at 8:45 AM<br><b>To:</b> Mint Prints Team &lt;Info@mintprints.com&gt;<br><b>Subject:</b> Re: H&amp;C<br><br></div><div>Good morning Ronny,</div><div><br></div><div>The printing will be for t-shirts. Please remember to print our telephone number on the top left chest, and do the same for the embroidery. Please provide a quote for the minimum required for embroidery and printing. I will bring the apparel.</div><div><br></div><div>Best regards,</div><div><br></div><div>Marvely González</div><div>Office &amp; Operations Manager</div><div>Marvely@HandCImprovements.com</div><hr><div>Here’s a link to the last order,</div><div><br></div><div>Please provide us with the details, will the shirts you are bringing receive all 4 locations?</div></body></html>"}}
JSON
    ;;
  microsoft.mail.attachments.list)
    cat <<'JSON'
{"value":[{"id":"ATT-INLINE","name":"Outlook-inline.jpg","contentType":"image/jpeg","size":32732,"isInline":true}]}
JSON
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
    if [[ "$email" == "marvely@handcimprovements.com" ]]; then
      cat <<'JSON'
{"data":{"quote_intelligence":{"customer_context_match":{"matched":false,"match_mode":"none","selector":{},"summary":null,"context":null},"customer_context":null},"legacy_hold":{"latest_order":{"invoice_number":"13471","nickname":"H&C improvment","legacy_order_row_id":"38052"},"latest_order_imprints":[]}}}
JSON
    else
      cat <<'JSON'
{"data":{"quote_intelligence":{"customer_context_match":{"matched":false,"match_mode":"none","selector":{},"summary":null,"context":null},"customer_context":null},"legacy_hold":{"latest_order":null,"latest_order_imprints":[]}}}
JSON
    fi
    ;;
  *)
    echo "unsupported capability: $capability" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$SPINE_ROOT/bin/ops"

json_out="$("$BRIEF" MSG-HC-FWD --mailbox team@mintprints.com --json)"
reply_preview="$(echo "$json_out" | jq -r '.data.reply_preview.body_text')"

[[ "$(echo "$json_out" | jq -r '.data.customer.email')" == "marvely@handcimprovements.com" ]] || fail "forwarded resolver should prefer the real customer email over the Outlook relay alias"
[[ "$(echo "$json_out" | jq -r '.data.operator_policy_match.matched')" == "false" ]] || fail "printed phone-number references should not trigger async phone-coordination policy"
[[ "$(echo "$json_out" | jq -r '.data.evidence_recommendation.matched')" == "true" ]] || fail "carry-forward embroidery text should trigger evidence-first reasoning even without a non-inline attachment"
[[ "$(echo "$json_out" | jq -r '.data.evidence_recommendation.recommended_location')" == "left chest" ]] || fail "carry-forward reasoning should preserve the left chest location"
[[ "$(echo "$json_out" | jq -r '.data.evidence_recommendation.recommended_width_inches')" == "4" ]] || fail "carry-forward reasoning should default to 4-inch left chest embroidery"
echo "$json_out" | jq -e '.data.operator_brief.missing | index("print-ready artwork (PNG or PDF)") | not' >/dev/null || fail "known carry-forward artwork should clear the missing-artwork blocker"
[[ "$reply_preview" == *'Based on your note to do the same for the embroidery'* ]] || fail "reply preview should confirm the inferred carry-forward assumption"
[[ "$reply_preview" == *'4" wide embroidery on the left chest'* ]] || fail "reply preview should recommend the left chest embroidery size"
[[ "$reply_preview" == *'same 4 print locations as the last order'* ]] || fail "reply preview should carry forward the existing print setup"

pass "customer-quote-brief resolves forwarded customer identity and confirms embroidery carry-forward assumptions from message context"

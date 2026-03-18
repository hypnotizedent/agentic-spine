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
{"id":"MSG-RAYLIN","subject":"Quote for the same polos as last time","conversationId":"CONV-RAYLIN","receivedDateTime":"2026-03-13T17:42:00Z","from":{"emailAddress":{"address":"raylin@example.com","name":"Raylin Brooks"}},"body":{"contentType":"Text","content":"Hey Ronny,\n\nCan you quote 36 navy polos, same as last time?\n\nThanks,\nRaylin Brooks\nraylin@example.com\n"}}
JSON
    ;;
  microsoft.mail.attachments.list)
    cat <<'JSON'
{"value":[]}
JSON
    ;;
  communications.mail.search)
    query=""
    mailbox=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --query) query="$2"; shift 2 ;;
        --top) shift 2 ;;
        --mailbox) mailbox="$2"; shift 2 ;;
        --json) shift ;;
        *) shift ;;
      esac
    done
    if [[ "$query" != "raylin@example.com" || "$mailbox" != "team@mintprints.com" ]]; then
      cat <<'JSON'
{"data":{"microsoft":{"value":[]}}}
JSON
      exit 0
    fi
    cat <<'JSON'
{"data":{"microsoft":{"value":[
  {"id":"MSG-RAYLIN","conversationId":"CONV-RAYLIN","subject":"Quote for the same polos as last time","receivedDateTime":"2026-03-13T17:42:00Z","from":{"emailAddress":{"address":"raylin@example.com","name":"Raylin Brooks"}}},
  {"id":"MSG-RAYLIN-OLD-1","conversationId":"CONV-RAYLIN-OLD","subject":"Re: Raylin Summer Staff","receivedDateTime":"2025-08-01T13:10:00Z","from":{"emailAddress":{"address":"raylin@example.com","name":"Raylin Brooks"}}},
  {"id":"MSG-RAYLIN-OLD-2","conversationId":"CONV-RAYLIN-OLDER","subject":"Raylin polos reorder","receivedDateTime":"2025-05-17T15:22:00Z","from":{"emailAddress":{"address":"raylin@example.com","name":"Raylin Brooks"}}}
]}}}
JSON
    ;;
  mint.customer.record.snapshot)
    cat <<'JSON'
{"data":{
  "fresh_slate":{
    "customer":{"record_id":"cust-raylin","company":"Raylin & Co","email":"raylin@example.com"},
    "identity":{"display_name":"Raylin","legal_name":"Raylin Brooks"}
  },
  "legacy_hold":{
    "latest_order":{"invoice_number":"13839","nickname":"Raylin Summer Staff","total_quantity":48},
    "latest_order_line_items":[
      {"style_number":"K500","style_description":"Port Authority Silk Touch Polo","color":"Black","total_quantity":48}
    ],
    "latest_order_imprints":[
      {"location":"Left Chest","decoration_type":"embroidery","description":"Raylin left chest logo"}
    ]
  },
  "artifact_visibility":{
    "state":"active_artifacts_present",
    "active_count":2,
    "latest":{"artifact_role":"print_ready","canonical_object_key":"artwork-intake/operator-drop/13839 Raylin Summer Staff/3. Print Ready/raylin-logo.ai"}
  },
  "artwork_intelligence_visibility":{
    "state":"analysis_present_reusable",
    "latest":{"analysis_id":"MAI-RAYLIN-1"}
  },
  "printavo_visibility":{
    "state":"bridge_present",
    "latest":{"external_order_number":"13839","printavo_state":"history_attached"}
  },
  "company_contact_graph":{
    "match_mode":"domain_exact",
    "summary":{"contact_names":["Raylin Brooks"]}
  },
  "quote_intelligence":{
    "customer_context_match":{"matched":false,"match_mode":"none","selector":{},"summary":null,"context":null},
    "customer_context":null
  }
}}
JSON
    ;;
  *)
    echo "unsupported capability: $capability" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$SPINE_ROOT/bin/ops"

json_out="$("$BRIEF" MSG-RAYLIN --mailbox team@mintprints.com --json)"
reply_preview="$(echo "$json_out" | jq -r '.data.reply_preview.body_text')"

[[ "$(echo "$json_out" | jq -r '.data.operator_brief.workflow_mode')" == "context_first" ]] || fail "workflow should be context_first"
[[ "$(echo "$json_out" | jq -r '.data.context_analysis.reuse_confidence')" == "high" ]] || fail "same-as-last-time quote should resolve high reuse confidence"
[[ "$(echo "$json_out" | jq -r '.data.operator_brief.prior_context[] | select(.kind=="mail_history") | .count')" == "2" ]] || fail "prior mailbox history should exclude the current message and preserve two prior hits"
[[ "$(echo "$json_out" | jq -r '.data.operator_brief.reused[] | select(.field=="style_code") | .value')" == "K500" ]] || fail "style code should be reused from prior order truth"
[[ "$(echo "$json_out" | jq -r '.data.operator_brief.reused[] | select(.field=="artwork_reference") | .basis')" == "artifact_runtime" ]] || fail "artwork should reuse governed artifact truth"
[[ "$(echo "$json_out" | jq -r '.data.operator_brief.changed[] | select(.field=="requested_color") | .current')" == "Navy" ]] || fail "color change should be detected from current request"
[[ "$(echo "$json_out" | jq -r '.data.operator_brief.changed[] | select(.field=="requested_total_quantity") | .current')" == "36" ]] || fail "quantity change should be detected from current request"
[[ "$(echo "$json_out" | jq -r '.data.operator_brief.missing | length')" == "1" ]] || fail "only one blocker should remain after context build"
[[ "$(echo "$json_out" | jq -r '.data.operator_brief.missing[0]')" == "due date" ]] || fail "due date should be the only remaining blocker"
echo "$json_out" | jq -e '.data.operator_brief.missing | index("print-ready artwork (PNG or PDF)") | not' >/dev/null || fail "prior governed artwork should clear the generic artwork blocker"
echo "$json_out" | jq -e '.data.operator_brief.missing | index("final quantity confirmation") | not' >/dev/null || fail "explicit quantity should clear the generic quantity blocker"
[[ "$reply_preview" == *'order #13839'* ]] || fail "reply preview should anchor to the prior order history"
[[ "$reply_preview" == *'reuse the existing artwork'* ]] || fail "reply preview should reuse governed artwork truth"
[[ "$reply_preview" == *'only thing I still need'* ]] || fail "reply preview should ask only for the single remaining blocker"
[[ "$reply_preview" == *'due date'* ]] || fail "reply preview should ask for due date"
[[ "$reply_preview" != *'print-ready artwork'* ]] || fail "reply preview should not regress to generic artwork request"
[[ "$reply_preview" != *'final piece count'* ]] || fail "reply preview should not regress to generic quantity request"

pass "customer-quote-brief builds full context first and asks only for the minimum remaining blocker"

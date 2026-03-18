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
{"id":"MSG-PTP","subject":"Small dtg or transfer quote","conversationId":"CONV-PTP","receivedDateTime":"2026-03-12T14:51:44Z","from":{"emailAddress":{"address":"jon@ptpuniversal.com","name":"PTP Universal"}},"body":{"contentType":"Text","content":"Hey Ronny,\n\nFriend of mine asked for 7-11 purple shirts\n\nEach sounds like would have a photo and separate quote from\nHer dad that sadly passed from pancreatic cancer- so I assume transfer or dtg ?\n\nWhat would approx quote be for this and I appreciate you!\n\nJonathan Lieberman\nPTP Universal, Inc.\n"}}
JSON
    ;;
  mint.customer.record.snapshot)
    cat <<'JSON'
{"data":{"quote_intelligence":{"policy_contract":"/policy.yaml","house_policy":{"minimum_pieces":24,"preferred_order_floor_usd":150},"terminology":{"preferred_artwork_phrase":"print-ready artwork","artwork_examples":["PNG","PDF"],"avoid_terms":["photo files"],"replacement_phrase":"print-ready artwork (PNG or PDF)"},"customer_context_match":{"matched":true,"match_mode":"email_exact","record_file":"/tmp/MCQ.json","selector":{"email":"jon@ptpuniversal.com","customer_name":"Jonathan Lieberman","company":"PTP Universal"},"summary":{"segments":["middleman printer","contract printer","broker printer"],"exception":"memorial | $25.00 each | goodwill exception"}},"customer_context":{"segments":[{"key":"middleman_printer","label":"middleman printer"},{"key":"contract_printer","label":"contract printer"},{"key":"broker_printer","label":"broker printer"}],"relationship":{"volume_expectation":"expected_volume","operator_note":"Expected volume partner; judge differently from standard retail one-offs."},"exception_rule":{"job_type":"memorial","default_posture":"discouraged","goodwill_exception_allowed":true,"pricing_override":{"mode":"flat_rate_each","unit_price_usd":25.0,"currency":"USD"},"operator_note":"We are willing to do this memorial run for Jon out of appreciation."}}}}}
JSON
    ;;
  *)
    echo "unsupported capability: $capability" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$SPINE_ROOT/bin/ops"

json_out="$("$BRIEF" MSG-PTP --mailbox team@mintprints.com --json)"
record_file="$(echo "$json_out" | jq -r '.data.record_file')"

[[ -f "$record_file" ]] || fail "quote brief record should exist"
[[ "$(echo "$json_out" | jq -r '.data.customer.name')" == "Jonathan Lieberman" ]] || fail "brief should resolve customer name"
[[ "$(echo "$json_out" | jq -r '.data.operator_report.disposition')" == "customer_actionable" ]] || fail "quote brief should surface the canonical disposition"
[[ "$(echo "$json_out" | jq -r '.data.operator_report.gate_status')" == "hold" ]] || fail "quote brief should stay hold until module-backed quote truth is available"
[[ "$(echo "$json_out" | jq -r '.data.operator_brief.job_type')" == "memorial" ]] || fail "brief should classify memorial job type"
[[ "$(echo "$json_out" | jq -r '.data.operator_brief.customer_segments[0]')" == "middleman printer" ]] || fail "brief should surface customer segments"
[[ "$(echo "$json_out" | jq -r '.data.operator_brief.house_policy.minimum_pieces')" == "24" ]] || fail "brief should surface minimum policy"
[[ "$(echo "$json_out" | jq -r '.data.operator_brief.exception_summary')" == 'Goodwill memorial exception at $25.00 each.' ]] || fail "brief should surface the Jon exception"
grep -F 'print-ready artwork (PNG or PDF)' "$record_file" >/dev/null || fail "brief should use house terminology"
[[ "$(echo "$json_out" | jq -r '.data.reply_preview.body_text')" == *'print-ready artwork (PNG or PDF)'* ]] || fail "reply preview should use governed artwork wording"
[[ "$(echo "$json_out" | jq -r '.data.reply_preview.body_text')" != *'photo files'* ]] || fail "reply preview should not fall back to photo files wording"
[[ "$(echo "$json_out" | jq -r '.data.reply_preview.suppressed')" == "true" ]] || fail "reply preview should be suppressed by default until the draft gate is explicitly opened"

pass "customer-quote-brief produces an operator-first report and suppresses the draft preview by default for the PTP memorial proving case"

#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
WRAPPER="$ROOT/../mint-modules/scripts/morpheus/inbox.sh"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

[[ -x "$WRAPPER" ]] || fail "missing Morpheus inbox wrapper"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export SPINE_ROOT="$tmp/spine"
export SPINE_STATE="$tmp/state"
export MORPHEUS_MINT_MAILBOX="team@mintprints.com"
mkdir -p "$SPINE_ROOT" "$SPINE_STATE"

cat >"$tmp/ops" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

capability="${3:-}"
shift 3 || true
if [[ "${1:-}" == "--" ]]; then
  shift
fi

printf '%s\n' "$capability" >>"${SPINE_STATE}/ops-call-log.txt"
echo "Receipt: /tmp/${capability}.receipt.md"

mode="${WORK_NEXT_TEST_MODE:-actionable}"

case "$capability" in
  mint.customer.inbox.first_email)
    case "$mode" in
      actionable)
        cat <<'JSON'
{"claim_status":"claimed","queue_claim":{"message_id":"MSG-ACT","thread_id":"C-ACT"},"selected_item":{"effective_message_id":"MSG-ACT","thread_id":"C-ACT"},"operator_report":{"disposition":"customer_actionable","gate_status":"go","confidence":"high","message_anchor":{"subject":"Need pricing for 48 polos"},"customer_identity":{"display_name":"Avery Buyer","company":"Avery Co","email":"avery@example.com"},"blockers":[],"recommended_next_action":"packetize_quote","draft_eligible":false}}
JSON
        ;;
      waiting)
        cat <<'JSON'
{"claim_status":"claimed","queue_claim":{"message_id":"MSG-WAIT","thread_id":"C-WAIT"},"selected_item":{"effective_message_id":"MSG-WAIT","thread_id":"C-WAIT"},"operator_report":{"disposition":"waiting_on_customer","gate_status":"go","confidence":"high","message_anchor":{"subject":"Need help choosing tees"},"customer_identity":{"display_name":"Wendy Wait","company":"Wait Co","email":"wendy@example.com"},"blockers":["final quantity"],"recommended_next_action":"wait_for_customer","draft_eligible":false}}
JSON
        ;;
      unsupported)
        cat <<'JSON'
{"claim_status":"claimed","queue_claim":{"message_id":"MSG-UNSUP","thread_id":"C-UNSUP"},"selected_item":{"effective_message_id":"MSG-UNSUP","thread_id":"C-UNSUP"},"operator_report":{"disposition":"unsupported_scope","gate_status":"go","confidence":"high","message_anchor":{"subject":"Print Request"},"customer_identity":{"display_name":"Marwan","company":"Marwan Co","email":"marwan@example.com"},"blockers":["apparel only"],"recommended_next_action":"decline_unsupported_scope","draft_eligible":false}}
JSON
        ;;
      *)
        echo "unexpected mode: $mode" >&2
        exit 1
        ;;
    esac
    ;;
  mint.customer.quote.intake)
    cat <<'JSON'
{"data":{"customer":{"name":"Avery Buyer","company":"Avery Co"},"qualification_status":"qualified_for_quote_lane","product_scope":{"classification":"in_scope"},"handoff":{"packet_id":"packet-1","packet_file":"","packet_state":"quote_packet_in_progress","next_step":"gather_pricing_inputs","source_state":"customer_intake_complete","estimate_state":"waiting_for_inputs","pricing_state":"waiting_for_inputs"},"packet_summary":{"quote_readiness_state":"needs_customer_input","build_ready":false,"send_ready":false,"blocking_gap_types":["quantity_missing"]},"external_context":{"printavo_visibility":{"state":"","latest":{}}},"record_file":"/tmp/quote-flow-record.json"}}
JSON
    ;;
  mint.customer.quote.brief)
    case "$mode" in
      waiting)
        cat <<'JSON'
{"data":{"operator_report":{"disposition":"waiting_on_customer","gate_status":"go","confidence":"high","message_anchor":{"subject":"Need help choosing tees"},"customer_identity":{"display_name":"Wendy Wait","company":"Wait Co","email":"wendy@example.com"},"module_truth":{"pricing_truth":{"price_lane":"","pricing_basis":[]}},"blockers":["final quantity"],"recommended_next_action":"wait_for_customer","draft_eligible":true},"reply_preview":{"suppressed":true,"body_text":""},"record_file":"/tmp/brief-wait.json"}}
JSON
        ;;
      unsupported)
        cat <<'JSON'
{"data":{"operator_report":{"disposition":"unsupported_scope","gate_status":"go","confidence":"high","message_anchor":{"subject":"Print Request"},"customer_identity":{"display_name":"Marwan","company":"Marwan Co","email":"marwan@example.com"},"module_truth":{"pricing_truth":{"price_lane":"","pricing_basis":[]}},"blockers":["apparel only"],"recommended_next_action":"decline_unsupported_scope","draft_eligible":true},"reply_preview":{"suppressed":true,"body_text":""},"record_file":"/tmp/brief-unsup.json"}}
JSON
        ;;
      *)
        echo "unexpected brief mode: $mode" >&2
        exit 1
        ;;
    esac
    ;;
  *)
    echo "unexpected capability: $capability" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$tmp/ops"
export OPS_BIN="$tmp/ops"

reset_call_log() {
  : >"$SPINE_STATE/ops-call-log.txt"
}

assert_called() {
  local capability="$1"
  grep -Fx -- "$capability" "$SPINE_STATE/ops-call-log.txt" >/dev/null || fail "missing capability call: $capability"
}

reset_call_log
export WORK_NEXT_TEST_MODE="actionable"
actionable_json="$("$WRAPPER" work-next --json)"
assert_called "mint.customer.inbox.first_email"
assert_called "mint.customer.quote.intake"
[[ "$(printf '%s' "$actionable_json" | jq -r '.decision_surface')" == "quote-flow" ]] || fail "work-next should route actionable mail into quote-flow"
[[ "$(printf '%s' "$actionable_json" | jq -r '.recommended_commands.report')" == "mintctl morpheus inbox quote-flow MSG-ACT" ]] || fail "work-next should publish the quote-flow report command for actionable mail"
[[ "$(printf '%s' "$actionable_json" | jq -r '.recommended_commands.next')" == "mintctl morpheus inbox reply MSG-ACT" ]] || fail "work-next should recommend the governed reply gate once quote-flow truth shows customer blockers"
pass "Morpheus work-next routes actionable mail into quote-flow and recommends a governed reply command when customer blockers remain"

reset_call_log
export WORK_NEXT_TEST_MODE="waiting"
waiting_json="$("$WRAPPER" work-next --json)"
assert_called "mint.customer.inbox.first_email"
assert_called "mint.customer.quote.brief"
[[ "$(printf '%s' "$waiting_json" | jq -r '.decision_surface')" == "quote-brief" ]] || fail "work-next should route waiting mail into quote-brief"
[[ "$(printf '%s' "$waiting_json" | jq -r '.recommended_commands.report')" == "mintctl morpheus inbox quote-brief MSG-WAIT" ]] || fail "work-next should publish the quote-brief report command for waiting mail"
[[ "$(printf '%s' "$waiting_json" | jq -r '.recommended_commands.next')" == "mintctl morpheus inbox reply MSG-WAIT" ]] || fail "work-next should recommend the governed reply draft for waiting mail"
pass "Morpheus work-next routes waiting mail into quote-brief and recommends a governed reply draft without wrapper-only overrides"

reset_call_log
export WORK_NEXT_TEST_MODE="unsupported"
unsupported_json="$("$WRAPPER" work-next --json)"
assert_called "mint.customer.inbox.first_email"
assert_called "mint.customer.quote.brief"
[[ "$(printf '%s' "$unsupported_json" | jq -r '.decision_surface')" == "quote-brief" ]] || fail "work-next should route unsupported mail into quote-brief"
[[ "$(printf '%s' "$unsupported_json" | jq -r '.recommended_commands.next')" == "mintctl morpheus inbox reply MSG-UNSUP" ]] || fail "work-next should recommend the governed unsupported-scope draft gate"
pass "Morpheus work-next keeps unsupported scope in the report-first lane and recommends the governed decline draft"

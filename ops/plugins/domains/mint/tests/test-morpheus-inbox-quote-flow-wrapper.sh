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

packet_file="$tmp/quote_packet_packet-1.yaml"

write_packet() {
  local state="$1"
  cat >"$packet_file" <<EOF
quote_packet_id: packet-1
state: $state
quote_readiness:
  state: ready_for_operator_review
  next_step: operator_review
payment_ref: {}
EOF
}

write_packet "quote_packet_in_progress"

cat >"$tmp/ops" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

capability="${3:-}"
printf '%s\n' "$capability" >>"${SPINE_STATE}/ops-call-log.txt"

case "$capability" in
  mint.customer.quote.intake)
    if [[ "${4:-}" != "--" ]]; then
      echo "expected passthrough separator" >&2
      exit 1
    fi
    mode="${QUOTE_FLOW_TEST_MODE:-build_ready}"
    if [[ "$mode" == "build_ready" ]]; then
      cat <<OUT
Receipt: /tmp/fake-intake.receipt.md
{"data":{"customer":{"name":"Acme Events","company":"Acme"},"qualification_status":"qualified_for_quote_lane","product_scope":{"classification":"in_scope"},"handoff":{"packet_id":"packet-1","packet_file":"$QUOTE_FLOW_PACKET_FILE","packet_state":"quote_packet_in_progress","next_step":"render_quote"},"packet_summary":{"quote_readiness_state":"ready_for_operator_review","build_ready":true,"send_ready":false,"blocking_gap_types":[]},"external_context":{"printavo_visibility":{"state":"","latest":{}}},"record_file":"/tmp/quote-flow-record.json"}}
OUT
    else
      cat <<OUT
Receipt: /tmp/fake-intake.receipt.md
{"data":{"customer":{"name":"Blocked Co","company":"Blocked"},"qualification_status":"qualified_for_quote_lane","product_scope":{"classification":"in_scope"},"handoff":{"packet_id":"packet-1","packet_file":"$QUOTE_FLOW_PACKET_FILE","packet_state":"quote_packet_in_progress","next_step":"gather_pricing_inputs"},"packet_summary":{"quote_readiness_state":"needs_customer_input","build_ready":false,"send_ready":false,"blocking_gap_types":["quantity_missing"]},"external_context":{"printavo_visibility":{"state":"quote_live","latest":{"printavo_summary":{"printavo_public_invoice_url":"https://mint-prints-4019cb.printavo.com/invoice/example"}}}},"record_file":"/tmp/quote-flow-record.json"}}
OUT
    fi
    ;;
  mint.quote.render)
    python3 - <<PY
from pathlib import Path
path = Path("${QUOTE_FLOW_PACKET_FILE}")
path.write_text("""quote_packet_id: packet-1
state: ready_for_review
quote_readiness:
  state: ready_for_operator_review
  next_step: operator_review
payment_ref: {}
""", encoding="utf-8")
PY
    cat <<OUT
Receipt: /tmp/fake-render.receipt.md
quote_packet_id: packet-1
state: quote_packet_in_progress -> ready_for_review
render_status: success
packet_file: $QUOTE_FLOW_PACKET_FILE
OUT
    ;;
  *)
    echo "unexpected capability: $capability" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$tmp/ops"

export OPS_BIN="$tmp/ops"
export QUOTE_FLOW_PACKET_FILE="$packet_file"

assert_called() {
  local capability="$1"
  grep -Fx -- "$capability" "$SPINE_STATE/ops-call-log.txt" >/dev/null || fail "missing capability call: $capability"
}

assert_not_called() {
  local capability="$1"
  if grep -Fx -- "$capability" "$SPINE_STATE/ops-call-log.txt" >/dev/null; then
    fail "unexpected capability call: $capability"
  fi
}

reset_call_log() {
  : >"$SPINE_STATE/ops-call-log.txt"
}

reset_call_log
export QUOTE_FLOW_TEST_MODE="build_ready"
write_packet "quote_packet_in_progress"
json_out="$("$WRAPPER" quote-flow MSG-1 --json)"
assert_called "mint.customer.quote.intake"
assert_called "mint.quote.render"
[[ "$(printf '%s' "$json_out" | jq -r '.packet_id')" == "packet-1" ]] || fail "quote-flow should report packet id"
[[ "$(printf '%s' "$json_out" | jq -r '.packet_state')" == "ready_for_review" ]] || fail "quote-flow should refresh packet state after render"
[[ "$(printf '%s' "$json_out" | jq -r '.module_truth.render_status')" == "success" ]] || fail "quote-flow should report render success"
[[ "$(printf '%s' "$json_out" | jq -r '.gates.promotion')" == "awaiting_operator_approval" ]] || fail "quote-flow should expose the operator approval gate"
[[ "$(printf '%s' "$json_out" | jq -r '.recommended_commands.approval')" == "mintctl morpheus inbox quote-approve packet-1 --approved-by MINT-OPERATOR-01" ]] || fail "quote-flow should suggest the governed approval command"
[[ "$(printf '%s' "$json_out" | jq -r '.gates.draft')" == "blocked_native_quote_review_url_missing" ]] || fail "quote-flow should expose the native quote-url blocker"
[[ "$(printf '%s' "$json_out" | jq -r '.blockers | index("operator_approval_required")')" != "null" ]] || fail "quote-flow should retain operator approval as a blocker until the packet is approved"
pass "Morpheus quote-flow runs intake plus render when the packet is build-ready and reports the real approval gate"

reset_call_log
export QUOTE_FLOW_TEST_MODE="blocked"
write_packet "quote_packet_in_progress"
blocked_json="$("$WRAPPER" quote-flow MSG-2 --json)"
assert_called "mint.customer.quote.intake"
assert_not_called "mint.quote.render"
[[ "$(printf '%s' "$blocked_json" | jq -r '.module_truth.render_status')" == "skipped_not_build_ready" ]] || fail "quote-flow should skip render when intake is not build-ready"
[[ "$(printf '%s' "$blocked_json" | jq -r '.gates.draft')" == "compat_only_printavo_quote_url" ]] || fail "quote-flow should surface compatibility-only quote urls distinctly"
[[ "$(printf '%s' "$blocked_json" | jq -r '.blockers | join(",")')" == *"quantity_missing"* ]] || fail "quote-flow should retain packet blockers from intake"
pass "Morpheus quote-flow stays in report-only mode when intake truth is not build-ready"

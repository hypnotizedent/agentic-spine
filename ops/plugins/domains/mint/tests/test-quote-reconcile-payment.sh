#!/usr/bin/env bash
# test-quote-reconcile-payment.sh - Validate governed payment reconciliation into canonical order/quote/packet state

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$(cd "$SCRIPT_DIR/../../../../.." && pwd)}"

source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init

QUOTE_PROMOTE="$SPINE_ROOT/ops/plugins/domains/mint/bin/quote-promote"
QUOTE_RECONCILE_PAYMENT="$SPINE_ROOT/ops/plugins/domains/mint/bin/quote-reconcile-payment"
FIXTURES_DIR="$SPINE_ROOT/ops/plugins/domains/mint/tests/fixtures/quote-promote"
TMP_ROOT="$(mktemp -d)"
PACKETS_DIR="$TMP_ROOT/quote-packets"
ORDERS_DIR="$TMP_ROOT/orders"
ORDER_REVISIONS_DIR="$TMP_ROOT/order-revisions"
QUOTES_DIR="$TMP_ROOT/quotes"
PRICING_SNAPSHOTS_DIR="$TMP_ROOT/pricing-snapshots"
ARTWORK_BINDINGS_DIR="$TMP_ROOT/artwork-bindings"
PACKET_INDEX="$TMP_ROOT/quote-packets-index.yaml"
ORDERS_INDEX="$TMP_ROOT/orders-index.yaml"
ORDER_REVISIONS_INDEX="$TMP_ROOT/order-revisions-index.yaml"
QUOTES_INDEX="$TMP_ROOT/quotes-index.yaml"
PRICING_SNAPSHOTS_INDEX="$TMP_ROOT/pricing-snapshots-index.yaml"
ARTWORK_BINDINGS_INDEX="$TMP_ROOT/artwork-bindings-index.yaml"
MOCK_PORT_FILE="$TMP_ROOT/payment-port.txt"
SCENARIO_FILE="$TMP_ROOT/payment-scenarios.json"
MOCK_LOG="$TMP_ROOT/payment-log.jsonl"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }
section() { echo ""; echo "==> $*"; }
cleanup() {
  if [[ -n "${MOCK_PID:-}" ]]; then
    kill "$MOCK_PID" >/dev/null 2>&1 || true
    wait "$MOCK_PID" 2>/dev/null || true
  fi
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

mkdir -p "$PACKETS_DIR"
cp "$FIXTURES_DIR/approved.packet.yaml" "$PACKETS_DIR/quote_packet_reconcile-paid-full.yaml"
cp "$FIXTURES_DIR/approved.packet.yaml" "$PACKETS_DIR/quote_packet_reconcile-processing.yaml"
cp "$FIXTURES_DIR/approved.packet.yaml" "$PACKETS_DIR/quote_packet_reconcile-deposit.yaml"
cp "$FIXTURES_DIR/approved.packet.yaml" "$PACKETS_DIR/quote_packet_reconcile-refunded.yaml"
yq -i '.quote_packet_id = "reconcile-paid-full"' "$PACKETS_DIR/quote_packet_reconcile-paid-full.yaml"
yq -i '.quote_packet_id = "reconcile-processing"' "$PACKETS_DIR/quote_packet_reconcile-processing.yaml"
yq -i '.quote_packet_id = "reconcile-deposit"' "$PACKETS_DIR/quote_packet_reconcile-deposit.yaml"
yq -i '.quote_packet_id = "reconcile-refunded"' "$PACKETS_DIR/quote_packet_reconcile-refunded.yaml"

run_promote() {
  MINT_QUOTE_PACKETS_DIR="$PACKETS_DIR" \
  MINT_QUOTE_PACKET_INDEX_FILE="$PACKET_INDEX" \
  MINT_ORDER_RUNTIME_DIR="$ORDERS_DIR" \
  MINT_ORDER_INDEX_FILE="$ORDERS_INDEX" \
  MINT_ORDER_REVISIONS_DIR="$ORDER_REVISIONS_DIR" \
  MINT_ORDER_REVISION_INDEX_FILE="$ORDER_REVISIONS_INDEX" \
  MINT_QUOTES_DIR="$QUOTES_DIR" \
  MINT_QUOTES_INDEX_FILE="$QUOTES_INDEX" \
  MINT_PRICING_SNAPSHOTS_DIR="$PRICING_SNAPSHOTS_DIR" \
  MINT_PRICING_SNAPSHOT_INDEX_FILE="$PRICING_SNAPSHOTS_INDEX" \
  MINT_ARTWORK_BINDINGS_DIR="$ARTWORK_BINDINGS_DIR" \
  MINT_ARTWORK_BINDINGS_INDEX_FILE="$ARTWORK_BINDINGS_INDEX" \
  "$QUOTE_PROMOTE" "$@"
}

run_reconcile() {
  MINT_QUOTE_PACKETS_DIR="$PACKETS_DIR" \
  MINT_QUOTE_PACKET_INDEX_FILE="$PACKET_INDEX" \
  MINT_ORDER_RUNTIME_DIR="$ORDERS_DIR" \
  MINT_ORDER_INDEX_FILE="$ORDERS_INDEX" \
  MINT_QUOTES_DIR="$QUOTES_DIR" \
  MINT_QUOTES_INDEX_FILE="$QUOTES_INDEX" \
  PAYMENT_BASE_URL="$1" \
  PAYMENT_API_KEY="test-payment-key" \
  "$QUOTE_RECONCILE_PAYMENT" "$2"
}

mark_sent_and_attach_payment_ref() {
  local packet_file="$1"
  local quote_file="$2"
  local quote_id="$3"
  local order_id="$4"
  local checkout_id="$5"
  local payment_type="$6"
  local payment_amount_cents="$7"

  yq -i '.state = "sent" | .sent_at = "2026-03-10T18:00:00Z"' "$packet_file"
  yq -i '.quote_state = "sent" | .sent_at = "2026-03-10T18:00:00Z"' "$quote_file"

  yq -i ".payment_ref = {
    \"payment_provider\": \"stripe\",
    \"payment_link_id\": \"$checkout_id\",
    \"checkout_session_id\": \"$checkout_id\",
    \"payment_link_url\": \"https://checkout.stripe.com/c/pay/$checkout_id\",
    \"payment_link_state\": \"generated\",
    \"payment_amount\": $((payment_amount_cents / 100)).$((payment_amount_cents % 100)),
    \"payment_amount_cents\": $payment_amount_cents,
    \"payment_currency\": \"USD\",
    \"payment_type\": \"$payment_type\",
    \"quote_id\": \"$quote_id\",
    \"order_id\": \"$order_id\",
    \"generated_at\": \"2026-03-10T17:00:00Z\"
  }" "$packet_file"
  yq -i ".payment_ref = {
    \"payment_provider\": \"stripe\",
    \"payment_link_id\": \"$checkout_id\",
    \"checkout_session_id\": \"$checkout_id\",
    \"payment_link_url\": \"https://checkout.stripe.com/c/pay/$checkout_id\",
    \"payment_link_state\": \"generated\",
    \"payment_amount\": $((payment_amount_cents / 100)).$((payment_amount_cents % 100)),
    \"payment_amount_cents\": $payment_amount_cents,
    \"payment_currency\": \"USD\",
    \"payment_type\": \"$payment_type\",
    \"quote_id\": \"$quote_id\",
    \"order_id\": \"$order_id\",
    \"generated_at\": \"2026-03-10T17:00:00Z\"
  }" "$quote_file"
}

start_mock_server() {
  SCENARIO_FILE="$SCENARIO_FILE" MOCK_PORT_FILE="$MOCK_PORT_FILE" MOCK_LOG="$MOCK_LOG" python3 - <<'PY' &
import json
import os
from http.server import BaseHTTPRequestHandler, HTTPServer

scenario_path = os.environ["SCENARIO_FILE"]
port_file = os.environ["MOCK_PORT_FILE"]
log_path = os.environ["MOCK_LOG"]

with open(scenario_path, "r", encoding="utf-8") as handle:
    scenarios = json.load(handle)

def find_scenario_by_session(session_id: str):
    for scenario in scenarios["scenarios"].values():
        if scenario["session_id"] == session_id:
            return scenario
    return None

class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        return

    def do_GET(self):
        with open(log_path, "a", encoding="utf-8") as handle:
            handle.write(json.dumps({"path": self.path, "headers": dict(self.headers)}) + "\n")

        if self.path.startswith("/api/v1/payments/checkout-session/"):
            session_id = self.path.rsplit("/", 1)[-1]
            scenario = find_scenario_by_session(session_id)
            if scenario is None:
                self.send_response(404)
                self.end_headers()
                return
            response = {
                "id": session_id,
                "status": scenario["provider_checkout_status"],
                "payment_status": scenario["provider_payment_status"],
                "amount_total": scenario["payment_amount_cents"],
                "currency": "usd",
                "customer_email": "hello@acme.example.com",
                "metadata": {
                    "order_id": scenario["order_id"],
                    "payment_type": scenario["payment_type"],
                },
            }
        elif self.path.startswith("/api/orders/") and self.path.endswith("/payments"):
            order_id = self.path.split("/")[3]
            scenario = scenarios["scenarios"].get(order_id)
            if scenario is None:
                self.send_response(404)
                self.end_headers()
                return
            response = {
                "order_id": order_id,
                "payments": [
                    {
                        "id": f"pay_{scenario['session_id']}",
                        "order_id": order_id,
                        "amount_cents": scenario["payment_amount_cents"],
                        "currency": "usd",
                        "method": "card",
                        "transaction_type": "charge",
                        "stripe_payment_intent_id": scenario["stripe_payment_intent_id"],
                        "stripe_checkout_session_id": scenario["session_id"],
                        "status": scenario["payment_record_status"],
                        "idempotency_key": None,
                        "metadata": {
                            "payment_type": scenario["payment_type"],
                        },
                        "created_at": "2026-03-10T17:00:00.000Z",
                        "updated_at": scenario["record_updated_at"],
                    }
                ],
                "total": 1,
            }
        else:
            self.send_response(404)
            self.end_headers()
            return

        encoded = json.dumps(response).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

server = HTTPServer(("127.0.0.1", 0), Handler)
with open(port_file, "w", encoding="utf-8") as handle:
    handle.write(str(server.server_port))
server.serve_forever()
PY
  MOCK_PID=$!
  for _ in $(seq 1 50); do
    [[ -s "$MOCK_PORT_FILE" ]] && return 0
    sleep 0.1
  done
  fail "mock payment server failed to start"
}

section "Promote canonical quote fixtures and prepare sent payment refs"
run_promote reconcile-paid-full --approved-by MINT-OPERATOR-01 >/dev/null
run_promote reconcile-processing --approved-by MINT-OPERATOR-01 >/dev/null
run_promote reconcile-deposit --approved-by MINT-OPERATOR-01 >/dev/null
run_promote reconcile-refunded --approved-by MINT-OPERATOR-01 >/dev/null

paid_packet="$PACKETS_DIR/quote_packet_reconcile-paid-full.yaml"
paid_quote_id="$(yq '.quote_id' "$paid_packet")"
paid_order_id="$(yq '.order_id' "$paid_packet")"
paid_quote_file="$QUOTES_DIR/quote_${paid_quote_id}.yaml"
mark_sent_and_attach_payment_ref "$paid_packet" "$paid_quote_file" "$paid_quote_id" "$paid_order_id" "cs_paid_full" "full" "121968"

processing_packet="$PACKETS_DIR/quote_packet_reconcile-processing.yaml"
processing_quote_id="$(yq '.quote_id' "$processing_packet")"
processing_order_id="$(yq '.order_id' "$processing_packet")"
processing_quote_file="$QUOTES_DIR/quote_${processing_quote_id}.yaml"
mark_sent_and_attach_payment_ref "$processing_packet" "$processing_quote_file" "$processing_quote_id" "$processing_order_id" "cs_processing" "full" "121968"

deposit_packet="$PACKETS_DIR/quote_packet_reconcile-deposit.yaml"
deposit_quote_id="$(yq '.quote_id' "$deposit_packet")"
deposit_order_id="$(yq '.order_id' "$deposit_packet")"
deposit_quote_file="$QUOTES_DIR/quote_${deposit_quote_id}.yaml"
mark_sent_and_attach_payment_ref "$deposit_packet" "$deposit_quote_file" "$deposit_quote_id" "$deposit_order_id" "cs_deposit" "deposit" "50000"

refunded_packet="$PACKETS_DIR/quote_packet_reconcile-refunded.yaml"
refunded_quote_id="$(yq '.quote_id' "$refunded_packet")"
refunded_order_id="$(yq '.order_id' "$refunded_packet")"
refunded_quote_file="$QUOTES_DIR/quote_${refunded_quote_id}.yaml"
refunded_order_file="$ORDERS_DIR/order_${refunded_order_id}.yaml"
mark_sent_and_attach_payment_ref "$refunded_packet" "$refunded_quote_file" "$refunded_quote_id" "$refunded_order_id" "cs_refunded" "full" "121968"
# Simulate that this order was already paid and transitioned to production (so we can test operator_review_required)
yq -i '.state = "paid" | .paid_at = "2026-03-10T18:10:00Z"' "$refunded_packet"
yq -i '.quote_state = "accepted"' "$refunded_quote_file"
yq -i '.payment_state = "paid" | .lifecycle_state = "production"' "$refunded_order_file"

cat >"$SCENARIO_FILE" <<JSON
{
  "scenarios": {
    "$paid_order_id": {
      "order_id": "$paid_order_id",
      "session_id": "cs_paid_full",
      "payment_type": "full",
      "payment_amount_cents": 121968,
      "provider_checkout_status": "complete",
      "provider_payment_status": "paid",
      "payment_record_status": "succeeded",
      "stripe_payment_intent_id": "pi_paid_full",
      "record_updated_at": "2026-03-10T18:05:00.000Z"
    },
    "$processing_order_id": {
      "order_id": "$processing_order_id",
      "session_id": "cs_processing",
      "payment_type": "full",
      "payment_amount_cents": 121968,
      "provider_checkout_status": "complete",
      "provider_payment_status": "paid",
      "payment_record_status": "processing",
      "stripe_payment_intent_id": "pi_processing",
      "record_updated_at": "2026-03-10T18:06:00.000Z"
    },
    "$deposit_order_id": {
      "order_id": "$deposit_order_id",
      "session_id": "cs_deposit",
      "payment_type": "deposit",
      "payment_amount_cents": 50000,
      "provider_checkout_status": "complete",
      "provider_payment_status": "paid",
      "payment_record_status": "succeeded",
      "stripe_payment_intent_id": "pi_deposit",
      "record_updated_at": "2026-03-10T18:07:00.000Z"
    },
    "$refunded_order_id": {
      "order_id": "$refunded_order_id",
      "session_id": "cs_refunded",
      "payment_type": "full",
      "payment_amount_cents": 121968,
      "provider_checkout_status": "complete",
      "provider_payment_status": "paid",
      "payment_record_status": "refunded",
      "stripe_payment_intent_id": "pi_refunded",
      "record_updated_at": "2026-03-10T18:20:00.000Z"
    }
  }
}
JSON

start_mock_server
payment_base="http://127.0.0.1:$(cat "$MOCK_PORT_FILE")"

section "Full payment projects paid state into order, quote, and packet"
paid_output="$(run_reconcile "$payment_base" "$paid_quote_id")"
[[ "$(yq '.state' "$paid_packet")" == "paid" ]] || fail "full payment must mark the packet paid"
[[ "$(yq '.paid_at' "$paid_packet")" == "2026-03-10T18:05:00.000Z" ]] || fail "full payment must stamp packet paid_at from payment record truth"
[[ "$(yq '.quote_state' "$paid_quote_file")" == "accepted" ]] || fail "full payment must accept the canonical quote"
[[ "$(yq '.payment_state' "$ORDERS_DIR/order_${paid_order_id}.yaml")" == "paid" ]] || fail "full payment must mark the order paid"
[[ "$(yq '.lifecycle_state' "$ORDERS_DIR/order_${paid_order_id}.yaml")" == "approved" ]] || fail "full payment must advance the order lifecycle to approved"
[[ "$(yq '.payment_summary.visibility_state' "$ORDERS_DIR/order_${paid_order_id}.yaml")" == "confirmed_in_records" ]] || fail "full payment must confirm payment visibility"
[[ "$(yq '.payment_summary.source_kind' "$ORDERS_DIR/order_${paid_order_id}.yaml")" == "payment_module" ]] || fail "full payment must record payment module provenance"
[[ "$(yq '.payment_ref.payment_link_state' "$paid_packet")" == "paid" ]] || fail "full payment must sync payment_ref to paid"
[[ "$(yq '.payment_ref.payment_record_status' "$paid_packet")" == "succeeded" ]] || fail "full payment must persist payment record status"
[[ "$(yq '.payment_ref.stripe_payment_intent_id' "$paid_packet")" == "pi_paid_full" ]] || fail "full payment must persist stripe payment intent id"
[[ "$(yq '.orders[] | select(.order_id == "'"$paid_order_id"'") | .payment_visibility_state' "$ORDERS_INDEX")" == "confirmed_in_records" ]] || fail "orders index must surface confirmed payment visibility after full payment"
grep -Fq "reconciliation_state: paid" <<<"$paid_output" || fail "reconcile output must report paid"
pass "full payment reconciliation projects canonical paid state"

section "Re-running paid reconciliation stays idempotent"
rerun_output="$(run_reconcile "$payment_base" "$paid_quote_id")"
grep -Fq "reconciliation_state: existing_paid" <<<"$rerun_output" || fail "rerun must report existing paid state"
pass "payment reconciliation is idempotent once the order is already paid"

section "Webhook-incomplete payment stays blocked from canonical paid state"
processing_output="$(run_reconcile "$payment_base" "$processing_quote_id")"
[[ "$(yq '.state' "$processing_packet")" == "sent" ]] || fail "processing payment must keep packet in sent state"
[[ "$(yq '.quote_state' "$processing_quote_file")" == "sent" ]] || fail "processing payment must keep quote in sent state"
[[ "$(yq '.payment_state' "$ORDERS_DIR/order_${processing_order_id}.yaml")" == "unpaid" ]] || fail "processing payment must keep order unpaid"
[[ "$(yq '.payment_summary.visibility_state' "$ORDERS_DIR/order_${processing_order_id}.yaml")" == "not_yet_visible" ]] || fail "processing payment must keep payment visibility unconfirmed"
[[ "$(yq '.payment_ref.payment_link_state' "$processing_packet")" == "processing" ]] || fail "processing payment must sync payment_ref to processing"
[[ "$(yq '.payment_ref.provider_payment_status' "$processing_packet")" == "paid" ]] || fail "processing payment must record provider paid state"
grep -Fq "reconciliation_state: pending_reconciliation" <<<"$processing_output" || fail "processing payment must report pending_reconciliation"
pass "payment reconciliation does not invent canonical paid state before webhook completion"

section "Deposit payment records partial payment without falsely closing the packet"
deposit_output="$(run_reconcile "$payment_base" "$deposit_quote_id")"
[[ "$(yq '.state' "$deposit_packet")" == "sent" ]] || fail "deposit payment must leave the packet in sent state"
[[ "$(yq '.paid_at' "$deposit_packet")" == "null" ]] || fail "deposit payment must not stamp packet paid_at"
[[ "$(yq '.quote_state' "$deposit_quote_file")" == "accepted" ]] || fail "deposit payment must accept the canonical quote"
[[ "$(yq '.payment_state' "$ORDERS_DIR/order_${deposit_order_id}.yaml")" == "partially_paid" ]] || fail "deposit payment must mark the order partially_paid"
[[ "$(yq '.lifecycle_state' "$ORDERS_DIR/order_${deposit_order_id}.yaml")" == "approved" ]] || fail "deposit payment must still advance lifecycle to approved"
[[ "$(yq '.payment_summary.visibility_state' "$ORDERS_DIR/order_${deposit_order_id}.yaml")" == "confirmed_in_records" ]] || fail "deposit payment must confirm visibility once recorded"
[[ "$(yq '.payment_summary.payment_state' "$ORDERS_DIR/order_${deposit_order_id}.yaml")" == "partially_paid" ]] || fail "deposit payment summary must surface partially_paid"
[[ "$(yq '.payment_ref.payment_link_state' "$deposit_packet")" == "paid" ]] || fail "deposit payment must mark the payment link itself paid"
grep -Fq "reconciliation_state: partially_paid" <<<"$deposit_output" || fail "deposit reconciliation must report partially_paid"
pass "deposit payment reconciliation preserves the packet/state distinction honestly"

section "Refund projection mirrors refund truth without automatic lifecycle rollback"
refund_output="$(run_reconcile "$payment_base" "$refunded_quote_id")"
[[ "$(yq '.payment_state' "$refunded_order_file")" == "refunded" ]] || fail "refund must project order.payment_state=refunded"
[[ "$(yq '.lifecycle_state' "$refunded_order_file")" == "production" ]] || fail "refund must preserve order.lifecycle_state (no automatic rollback)"
[[ "$(yq '.payment_summary.visibility_state' "$refunded_order_file")" == "confirmed_in_records" ]] || fail "refund must preserve confirmed payment visibility"
[[ "$(yq '.payment_summary.payment_state' "$refunded_order_file")" == "refunded" ]] || fail "refund payment summary must mirror refunded state"
[[ "$(yq '.quote_state' "$refunded_quote_file")" == "accepted" ]] || fail "refund must preserve quote.quote_state (no automatic rejection)"
[[ "$(yq '.state' "$refunded_packet")" == "paid" ]] || fail "refund must preserve quote_packet.state (no automatic rollback)"
[[ "$(yq '.payment_ref.operator_review_required' "$refunded_packet")" == "true" ]] || fail "refund on production order must require operator review"
[[ "$(yq '.payment_ref.operator_review_reason' "$refunded_packet")" == "refund detected on production order" ]] || fail "refund must include operator review reason"
[[ "$(yq '.payment_ref.payment_link_state' "$refunded_packet")" == "refunded" ]] || fail "refund must sync payment_ref.payment_link_state=refunded"
grep -Fq "reconciliation_state: refunded" <<<"$refund_output" || fail "refund reconciliation must report refunded"
pass "refund reconciliation projects read-only truth without automatic business rollback"

section "Summary"
echo "Quote payment reconciliation checks passed"

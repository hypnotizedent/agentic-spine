#!/usr/bin/env bash
# test-quote-generate-payment-link.sh - Validate governed payment-link generation from promoted quote truth

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$(cd "$SCRIPT_DIR/../../../../.." && pwd)}"

source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init

QUOTE_PROMOTE="$SPINE_ROOT/ops/plugins/domains/mint/bin/quote-promote"
QUOTE_PAYMENT_LINK="$SPINE_ROOT/ops/plugins/domains/mint/bin/quote-generate-payment-link"
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
MOCK_LOG="$TMP_ROOT/payment-requests.jsonl"
MOCK_PORT_FILE="$TMP_ROOT/payment-port.txt"

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
cp "$FIXTURES_DIR/approved.packet.yaml" "$PACKETS_DIR/quote_packet_promote-approved.yaml"

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

run_payment_link() {
  MINT_QUOTE_PACKETS_DIR="$PACKETS_DIR" \
  MINT_QUOTE_PACKET_INDEX_FILE="$PACKET_INDEX" \
  MINT_ORDER_RUNTIME_DIR="$ORDERS_DIR" \
  MINT_QUOTES_DIR="$QUOTES_DIR" \
  MINT_QUOTES_INDEX_FILE="$QUOTES_INDEX" \
  PAYMENT_BASE_URL="$1" \
  PAYMENT_API_KEY="test-payment-key" \
  "$QUOTE_PAYMENT_LINK" "$2"
}

start_mock_server() {
  MOCK_LOG="$MOCK_LOG" MOCK_PORT_FILE="$MOCK_PORT_FILE" python3 - <<'PY' &
import json
import os
from http.server import BaseHTTPRequestHandler, HTTPServer

log_path = os.environ["MOCK_LOG"]
port_file = os.environ["MOCK_PORT_FILE"]

class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        return

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length).decode("utf-8")
        payload = json.loads(raw or "{}")
        with open(log_path, "a", encoding="utf-8") as handle:
            handle.write(json.dumps({"path": self.path, "headers": dict(self.headers), "payload": payload}) + "\n")
        response = {
            "checkout_session_id": "cs_test_quote_payment_link",
            "checkout_url": "https://checkout.stripe.com/c/pay/cs_test_quote_payment_link",
            "order_id": payload.get("order_id"),
            "amount_cents": payload.get("amount_cents"),
            "currency": payload.get("currency", "usd"),
        }
        encoded = json.dumps(response).encode("utf-8")
        self.send_response(201)
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

section "Promote fixture packet into canonical quote truth"
run_promote promote-approved --approved-by MINT-OPERATOR-01 >/dev/null
approved_packet="$PACKETS_DIR/quote_packet_promote-approved.yaml"
quote_id="$(yq '.quote_id' "$approved_packet")"
order_id="$(yq '.order_id' "$approved_packet")"
quote_file="$QUOTES_DIR/quote_${quote_id}.yaml"
[[ -f "$quote_file" ]] || fail "promote must create canonical quote before payment-link generation"

section "Generate payment link from promoted quote"
start_mock_server
payment_base="http://127.0.0.1:$(cat "$MOCK_PORT_FILE")"
payment_output="$(run_payment_link "$payment_base" "$quote_id")"

[[ "$(yq '.payment_ref.payment_link_state' "$approved_packet")" == "generated" ]] || fail "packet payment_ref must be generated"
[[ "$(yq '.payment_ref.checkout_session_id' "$approved_packet")" == "cs_test_quote_payment_link" ]] || fail "packet must persist checkout session id"
[[ "$(yq '.payment_ref.quote_id' "$approved_packet")" == "$quote_id" ]] || fail "packet payment_ref must record quote_id"
[[ "$(yq '.payment_ref.order_id' "$approved_packet")" == "$order_id" ]] || fail "packet payment_ref must record order_id"
[[ "$(yq '.payment_ref.payment_amount_cents' "$approved_packet")" == "121968" ]] || fail "packet payment_ref must persist amount cents"
[[ "$(yq '.payment_ref.payment_type' "$approved_packet")" == "full" ]] || fail "payment type must default to full"
[[ "$(yq '.payment_ref.checkout_session_id' "$quote_file")" == "null" ]] && fail "quote payment_ref must be persisted"
[[ "$(yq '.payment_ref.payment_link_state' "$quote_file")" == "generated" ]] || fail "quote payment_ref must mirror generated state"
grep -Fq "payment_link_state: generated" <<<"$payment_output" || fail "runtime output must report generated payment link"
grep -Fq '"path": "/api/v1/payments/checkout-session"' "$MOCK_LOG" || fail "mock server must receive checkout-session request"
grep -Fq "\"order_id\": \"$order_id\"" "$MOCK_LOG" || fail "payment request must use canonical order_id"
grep -Fq "\"customer_email\": \"hello@acme.example.com\"" "$MOCK_LOG" || fail "payment request must include resolved customer email"
pass "mint.quote.generate_payment_link bridges canonical quote truth into Stripe checkout payload"

section "Re-running payment-link generation stays idempotent"
rerun_output="$(run_payment_link "$payment_base" "$quote_id")"
[[ "$(wc -l <"$MOCK_LOG" | tr -d ' ')" == "1" ]] || fail "idempotent rerun must not create a second checkout session"
grep -Fq "payment_link_state: existing" <<<"$rerun_output" || fail "rerun output must report existing payment link"
pass "mint.quote.generate_payment_link reuses the existing checkout session on rerun"

section "Payment-link generation does not send or mark the packet paid"
[[ "$(yq '.state' "$approved_packet")" == "approved_to_send" ]] || fail "payment-link generation must preserve approved_to_send state"
[[ "$(yq '.sent_at' "$approved_packet")" == "null" ]] || fail "payment-link generation must not stamp sent_at"
[[ "$(yq '.paid_at' "$approved_packet")" == "null" ]] || fail "payment-link generation must not stamp paid_at"
[[ "$(yq '.quote_state' "$quote_file")" == "draft" ]] || fail "payment-link generation must not mutate the canonical quote state"
pass "payment-link generation remains a separate step from governed send and payment reconciliation"

section "Payment-link generation blocks honestly when customer email is missing"
cp "$FIXTURES_DIR/approved.packet.yaml" "$PACKETS_DIR/quote_packet_payment-link-missing-email.yaml"
yq -i '.quote_packet_id = "payment-link-missing-email"' "$PACKETS_DIR/quote_packet_payment-link-missing-email.yaml"
run_promote payment-link-missing-email --approved-by MINT-OPERATOR-01 >/dev/null
blocked_packet="$PACKETS_DIR/quote_packet_payment-link-missing-email.yaml"
blocked_quote_id="$(yq '.quote_id' "$blocked_packet")"
blocked_quote_file="$QUOTES_DIR/quote_${blocked_quote_id}.yaml"
yq -i 'del(.customer_email)' "$blocked_quote_file"
yq -i 'del(.customer_ref.resolved_email)' "$blocked_packet"

set +e
blocked_output="$(run_payment_link "$payment_base" "$blocked_quote_id" 2>&1)"
blocked_rc=$?
set -e
[[ "$blocked_rc" -ne 0 ]] || fail "missing email should block payment-link generation"
grep -Fq "resolved customer email is required before payment link generation" <<<"$blocked_output" || fail "blocked payment link must explain the missing email"
[[ "$(yq '.payment_ref' "$blocked_packet")" == "null" ]] || fail "blocked payment-link generation must not stamp payment_ref onto the packet"
pass "mint.quote.generate_payment_link refuses promoted quotes that still lack resolved customer email"

section "Summary"
echo "Quote payment-link checks passed"

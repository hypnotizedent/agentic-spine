#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$(cd "$SCRIPT_DIR/../../../../.." && pwd)}"

source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init

QUOTE_PROMOTE="$SPINE_ROOT/ops/plugins/domains/mint/bin/quote-promote"
PRINTAVO_CAPTURE="$SPINE_ROOT/ops/plugins/domains/mint/bin/printavo-bridge-capture"
FIXTURES_DIR="$SPINE_ROOT/ops/plugins/domains/mint/tests/fixtures/quote-promote"
TMP_ROOT="$(mktemp -d)"
PACKETS_DIR="$TMP_ROOT/quote-packets"
ORDERS_DIR="$TMP_ROOT/orders"
ORDER_REVISIONS_DIR="$TMP_ROOT/order-revisions"
QUOTES_DIR="$TMP_ROOT/quotes"
PRICING_SNAPSHOTS_DIR="$TMP_ROOT/pricing-snapshots"
ARTWORK_BINDINGS_DIR="$TMP_ROOT/artwork-bindings"
PRINTAVO_BRIDGES_DIR="$TMP_ROOT/printavo-bridges"
PACKET_INDEX="$TMP_ROOT/quote-packets-index.yaml"
ORDERS_INDEX="$TMP_ROOT/orders-index.yaml"
ORDER_REVISIONS_INDEX="$TMP_ROOT/order-revisions-index.yaml"
QUOTES_INDEX="$TMP_ROOT/quotes-index.yaml"
PRICING_SNAPSHOTS_INDEX="$TMP_ROOT/pricing-snapshots-index.yaml"
ARTWORK_BINDINGS_INDEX="$TMP_ROOT/artwork-bindings-index.yaml"
PRINTAVO_BRIDGES_INDEX="$TMP_ROOT/printavo-bridges-index.yaml"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }
cleanup() { rm -rf "$TMP_ROOT"; }
trap cleanup EXIT

mkdir -p "$PACKETS_DIR"
cp "$FIXTURES_DIR/approved.packet.yaml" "$PACKETS_DIR/quote_packet_printavo-capture.yaml"
yq -i '.quote_packet_id = "printavo-capture"' "$PACKETS_DIR/quote_packet_printavo-capture.yaml"

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

run_capture() {
  MINT_ORDER_RUNTIME_DIR="$ORDERS_DIR" \
  MINT_ORDER_INDEX_FILE="$ORDERS_INDEX" \
  MINT_QUOTES_DIR="$QUOTES_DIR" \
  MINT_QUOTES_INDEX_FILE="$QUOTES_INDEX" \
  MINT_PRINTAVO_BRIDGES_DIR="$PRINTAVO_BRIDGES_DIR" \
  MINT_PRINTAVO_BRIDGES_INDEX_FILE="$PRINTAVO_BRIDGES_INDEX" \
  "$PRINTAVO_CAPTURE" "$@"
}

run_promote printavo-capture --approved-by MINT-OPERATOR-01 >/dev/null
packet_file="$PACKETS_DIR/quote_packet_printavo-capture.yaml"
order_id="$(yq '.order_id' "$packet_file")"
order_file="$ORDERS_DIR/order_${order_id}.yaml"

capture_json="$(run_capture --order-id "$order_id" --printavo-state drafted_in_printavo --printavo-customer-id 5276540 --printavo-visual-id 13799 --captured-by ronny --captured-at 2026-03-13T15:45:00Z --evidence-ref https://www.printavo.com/invoices/13799 --receipt /tmp/manual-printavo-capture.receipt.md --json)"
bridge_id="$(echo "$capture_json" | jq -r '.printavo_bridge_id')"
bridge_file="$PRINTAVO_BRIDGES_DIR/printavo_bridge_${bridge_id}.yaml"

[[ -f "$bridge_file" ]] || fail "printavo bridge record should exist"
[[ "$(echo "$capture_json" | jq -r '.capture_state')" == "recorded" ]] || fail "first bridge capture should record a new bridge record"
[[ "$(yq '.printavo_summary.printavo_state' "$order_file")" == "drafted_in_printavo" ]] || fail "order projection should reflect drafted_in_printavo"
[[ "$(yq '.printavo_summary.printavo_customer_id' "$order_file")" == "5276540" ]] || fail "order projection should keep printavo_customer_id"
[[ "$(yq '.orders[0].printavo_state' "$ORDERS_INDEX")" == "drafted_in_printavo" ]] || fail "orders index should surface printavo state"
[[ "$(yq '.orders[0].printavo_source_kind' "$ORDERS_INDEX")" == "manual_operator_update" ]] || fail "orders index should surface printavo source kind"
[[ "$(yq '.printavo_bridges | length' "$PRINTAVO_BRIDGES_INDEX")" == "1" ]] || fail "bridge index should record one bridge"
[[ "$(yq '.evidence_refs[0]' "$bridge_file")" == "https://www.printavo.com/invoices/13799" ]] || fail "bridge record should persist evidence refs"
[[ "$(yq '.receipts[0]' "$bridge_file")" == "/tmp/manual-printavo-capture.receipt.md" ]] || fail "bridge record should persist receipt refs"
pass "manual Printavo bridge capture creates immutable bridge evidence and projects order truth"

rerun_json="$(run_capture --order-id "$order_id" --printavo-state drafted_in_printavo --printavo-customer-id 5276540 --printavo-visual-id 13799 --captured-by ronny --captured-at 2026-03-13T15:45:00Z --receipt /tmp/manual-printavo-rerun.receipt.md --json)"
[[ "$(echo "$rerun_json" | jq -r '.capture_state')" == "existing" ]] || fail "identical bridge capture rerun should be idempotent"
[[ "$(yq '.printavo_bridges | length' "$PRINTAVO_BRIDGES_INDEX")" == "1" ]] || fail "idempotent bridge capture rerun must not duplicate bridge index entries"
[[ "$(yq '.receipts | length' "$bridge_file")" == "2" ]] || fail "idempotent rerun should merge new receipt refs onto the existing immutable bridge record"
pass "manual Printavo bridge capture is idempotent for identical updates"

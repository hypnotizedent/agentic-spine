#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$SCRIPT_DIR/../bin"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT
TEST_SPINE_ROOT="$TMPDIR/spine"
mkdir -p "$TEST_SPINE_ROOT/bin"

cat >"$TEST_SPINE_ROOT/bin/ops" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
log_file="${VOICE_STATUS_TEST_LOG:?}"
printf '%s\n' "$*" >>"$log_file"
[[ "${1:-}" == "cap" && "${2:-}" == "run" ]] || exit 2
capability="${3:-}"
shift 3
if [[ "${1:-}" == "--" ]]; then
  shift
fi
case "$capability" in
  mint.printavo.bridge.snapshot)
    if [[ " $* " == *" --order-id ORDER-123 "* ]]; then
      cat <<'JSON'
{"capability":"mint.printavo.bridge.snapshot","state":"in_production","latest":{"order_id":"ORDER-123","quote_id":"QUOTE-123","seed_id":"SEED-123","customer_id":"cust-123","customer_email":"john@example.com","customer_name":"John Smith","printavo_state":"in_production","printavo_summary":{"printavo_state":"in_production","printavo_visual_id":"13842"}}}
JSON
    else
      cat <<'JSON'
{"capability":"mint.printavo.bridge.snapshot","state":"no_record_found","latest":null,"matches":[]}
JSON
    fi
    ;;
  mint.customer.record.snapshot)
    cat <<'JSON'
{"capability":"mint.customer.record.snapshot","fresh_slate":{"customer":{"record_id":"cust-321","email":"jane@example.com","name":"Jane Doe"},"identity":{"display_name":"Jane Doe","email":"jane@example.com"}},"printavo_visibility":{"state":"quote_live","latest":{"order_id":"ORDER-321","quote_id":"QUOTE-321","seed_id":"SEED-321","customer_id":"cust-321","customer_email":"jane@example.com","customer_name":"Jane Doe","printavo_state":"quote_live","printavo_summary":{"printavo_state":"quote_live","printavo_visual_id":"14321"}}},"receipts":{"printavo_snapshot_receipt":"/tmp/printavo.receipt.md"}}
JSON
    ;;
  *)
    echo "unsupported capability: $capability" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$TEST_SPINE_ROOT/bin/ops"

export SPINE_ROOT="$TEST_SPINE_ROOT"
export VOICE_STATUS_TEST_LOG="$TMPDIR/cap.log"

echo "TEST: customer-order-status-lookup"

# Test direct order lookup through Printavo bridge snapshot
echo "  - order lookup"
RESULT=$("$BIN_DIR/customer-order-status-lookup" --order-id "ORDER-123" --json)
echo "$RESULT" | jq -e '.status == "ok"' >/dev/null || { echo "FAIL: Expected ok status"; exit 1; }
echo "$RESULT" | jq -e '.data.resolved == true' >/dev/null || { echo "FAIL: Expected resolved true"; exit 1; }
echo "$RESULT" | jq -e '.data.source == "mint.printavo.bridge.snapshot"' >/dev/null || { echo "FAIL: Expected Printavo source"; exit 1; }
echo "$RESULT" | jq -e '.data.order_id == "ORDER-123"' >/dev/null || { echo "FAIL: Expected order id"; exit 1; }
grep -q "cap run mint.printavo.bridge.snapshot -- --json --order-id ORDER-123" "$VOICE_STATUS_TEST_LOG" || { echo "FAIL: Expected governed Printavo capability call"; exit 1; }
echo "    ✓ Order lookup uses governed Printavo capability"

# Test customer/email lookup through customer snapshot
echo "  - email lookup"
RESULT=$("$BIN_DIR/customer-order-status-lookup" --email "jane@example.com" --json)
echo "$RESULT" | jq -e '.status == "ok"' >/dev/null || { echo "FAIL: Expected ok status"; exit 1; }
echo "$RESULT" | jq -e '.data.resolved == true' >/dev/null || { echo "FAIL: Expected resolved true"; exit 1; }
echo "$RESULT" | jq -e '.data.source == "mint.customer.record.snapshot"' >/dev/null || { echo "FAIL: Expected customer snapshot source"; exit 1; }
echo "$RESULT" | jq -e '.data.customer_name == "Jane Doe"' >/dev/null || { echo "FAIL: Expected customer name"; exit 1; }
grep -q "cap run mint.customer.record.snapshot -- --json --email jane@example.com" "$VOICE_STATUS_TEST_LOG" || { echo "FAIL: Expected governed customer snapshot capability call"; exit 1; }
echo "    ✓ Email lookup uses governed customer snapshot capability"

echo "PASS: customer-order-status-lookup"

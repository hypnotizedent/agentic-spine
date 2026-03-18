#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$SCRIPT_DIR/../bin"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT
export SPINE_STATE="$TMPDIR/state"

echo "TEST: customer-voice-callback-enqueue"

# Test dry-run
echo "  - dry-run with JSON envelope"
RESULT=$("$BIN_DIR/customer-voice-callback-enqueue" \
  --interaction-id "INT-TEST-001" \
  --caller-number "+15551234567" \
  --reason "quote_request" \
  --urgency "medium" \
  --preferred-followup-channel "email" \
  --summary "Test callback request" \
  --dry-run \
  --json)
echo "$RESULT" | jq -e '.status == "ok"' >/dev/null || { echo "FAIL: Expected ok status"; exit 1; }
echo "$RESULT" | jq -e '.data.dry_run == true' >/dev/null || { echo "FAIL: Expected dry_run true"; exit 1; }
echo "$RESULT" | jq -e '.data.created == false' >/dev/null || { echo "FAIL: Expected created false in dry-run"; exit 1; }
echo "    ✓ JSON envelope valid"

# Test actual enqueue
echo "  - live enqueue"
RESULT=$("$BIN_DIR/customer-voice-callback-enqueue" \
  --interaction-id "INT-TEST-002" \
  --caller-number "+15559876543" \
  --caller-name "Jane Doe" \
  --company "Acme Corp" \
  --reason "urgent_order_issue" \
  --urgency "high" \
  --preferred-followup-channel "phone" \
  --summary "Urgent production deadline issue" \
  --order-or-quote-ref "ORDER-12345" \
  --json)
echo "$RESULT" | jq -e '.status == "ok"' >/dev/null || { echo "FAIL: Expected ok status"; exit 1; }
CALLBACK_ID=$(echo "$RESULT" | jq -r '.data.callback_item_id')
ITEM_PATH="$(echo "$RESULT" | jq -r '.data.item_path')"
[[ -f "$ITEM_PATH" ]] || { echo "FAIL: Expected callback record file"; exit 1; }
echo "$RESULT" | jq -e '.data.created == true and .data.existing == false' >/dev/null || { echo "FAIL: Expected created true"; exit 1; }
echo "    ✓ Created callback: $CALLBACK_ID"

# Test idempotency
echo "  - idempotency check"
RESULT=$("$BIN_DIR/customer-voice-callback-enqueue" \
  --interaction-id "INT-TEST-002" \
  --caller-number "+15559876543" \
  --reason "duplicate_test" \
  --urgency "low" \
  --preferred-followup-channel "email" \
  --summary "This should be skipped" \
  --json)
echo "$RESULT" | jq -e '.status == "ok"' >/dev/null || { echo "FAIL: Expected ok status"; exit 1; }
echo "$RESULT" | jq -e '.data.existing == true and .data.created == false' >/dev/null || { echo "FAIL: Expected existing callback response"; exit 1; }
echo "    ✓ Idempotency verified"

echo "PASS: customer-voice-callback-enqueue"

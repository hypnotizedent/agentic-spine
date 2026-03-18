#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$SCRIPT_DIR/../bin"

echo "TEST: customer-frontdesk-facts-get"

# Test hours topic
echo "  - hours topic"
RESULT=$("$BIN_DIR/customer-frontdesk-facts-get" --topic hours --json)
echo "$RESULT" | jq -e '.status == "ok"' >/dev/null || { echo "FAIL: Expected ok status"; exit 1; }
echo "$RESULT" | jq -e '.data.topic == "hours"' >/dev/null || { echo "FAIL: Expected hours topic"; exit 1; }
echo "$RESULT" | jq -e '.data.facts.response | contains("team@mintprints.com")' >/dev/null || { echo "FAIL: Expected email lane guidance"; exit 1; }
echo "    ✓ Hours facts retrieved"

# Test address topic
echo "  - address topic"
RESULT=$("$BIN_DIR/customer-frontdesk-facts-get" --topic address --json)
echo "$RESULT" | jq -e '.status == "ok"' >/dev/null || { echo "FAIL: Expected ok status"; exit 1; }
echo "$RESULT" | jq -e '.data.facts.street_address_known == false' >/dev/null || { echo "FAIL: Expected street_address_known false"; exit 1; }
echo "    ✓ Address facts retrieved"

# Test email topic
echo "  - email topic"
RESULT=$("$BIN_DIR/customer-frontdesk-facts-get" --topic email --json)
echo "$RESULT" | jq -e '.status == "ok"' >/dev/null || { echo "FAIL: Expected ok status"; exit 1; }
echo "$RESULT" | jq -e '.data.facts.email == "team@mintprints.com"' >/dev/null || { echo "FAIL: Expected team mailbox"; exit 1; }
echo "    ✓ Email facts retrieved"

# Test all topic
echo "  - all topic"
RESULT=$("$BIN_DIR/customer-frontdesk-facts-get" --topic all --json)
echo "$RESULT" | jq -e '.status == "ok"' >/dev/null || { echo "FAIL: Expected ok status"; exit 1; }
echo "$RESULT" | jq -e '.data.facts.business_name' >/dev/null || { echo "FAIL: Expected business_name in all"; exit 1; }
echo "    ✓ All facts retrieved"

echo "PASS: customer-frontdesk-facts-get"

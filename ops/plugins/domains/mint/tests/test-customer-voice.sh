#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPINE_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"

source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init

BIN_CAPTURE="$SPINE_ROOT/ops/plugins/domains/mint/bin/mint-customer-voice-intake-capture"
BIN_CALLBACK="$SPINE_ROOT/ops/plugins/domains/mint/bin/mint-customer-voice-callback-enqueue"
BIN_FACTS="$SPINE_ROOT/ops/plugins/domains/mint/bin/mint-customer-frontdesk-facts-get"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

pass() {
  echo "PASS: $*"
}

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

runtime_root="$tmpdir/runtime"
state_root="$runtime_root/state"
mkdir -p "$state_root"

mock_preview="$tmpdir/mock-preview"
mock_execute="$tmpdir/mock-execute"

cat >"$mock_preview" <<EOF
#!/usr/bin/env bash
set -euo pipefail
recipient="team@mintprints.com"
subject=""
body=""
while [[ \$# -gt 0 ]]; do
  case "\$1" in
    --to) recipient="\$2"; shift 2 ;;
    --subject) subject="\$2"; shift 2 ;;
    --body) body="\$2"; shift 2 ;;
    --json) shift ;;
    *) shift ;;
  esac
done
python3 - "\$recipient" "\$subject" "\$body" <<'JSON'
import json
import sys

recipient, subject, body = sys.argv[1:4]
print(json.dumps({
    "capability": "communications.send.preview",
    "schema_version": "1.0",
    "status": "ok",
    "generated_at": "2026-03-19T00:00:00Z",
    "data": {
        "recipient": recipient,
        "subject": subject,
        "body": body,
        "send_allowed": True,
        "policy_block_reasons": [],
        "preview_id": "preview-test",
        "preview_receipt": "$tmpdir/preview-test.json",
    },
}))
JSON
EOF
chmod +x "$mock_preview"

cat >"$mock_execute" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cat <<JSON
{"capability":"communications.send.execute","schema_version":"1.0","status":"ok","generated_at":"2026-03-19T00:00:00Z","data":{"event_id":"comm-test"}}
JSON
EOF
chmod +x "$mock_execute"

payload="$tmpdir/call.json"
cat >"$payload" <<'JSON'
{
  "message": {
    "type": "end-of-call-report",
    "analysis": {
      "summary": "Caller wants a quote and asked for a callback."
    },
    "call": {
      "id": "call-test-001",
      "startedAt": "2026-03-19T12:00:00Z",
      "endedAt": "2026-03-19T12:05:00Z"
    },
    "phoneNumber": {
      "number": "+15619005432"
    },
    "customer": {
      "name": "Ron Works",
      "email": "ron@mint.com"
    },
    "artifact": {
      "messages": [
        {"role": "assistant", "content": "Mint Prints front desk, this is Morpheus. How can I help you today?"},
        {"role": "user", "content": "I need 50 shirts and want someone to call me back."},
        {
          "toolCalls": [
            {
              "function": {
                "name": "create_callback_request",
                "arguments": "{\"reason\":\"quote_request\",\"summary\":\"50 shirt quote request\",\"urgency\":\"high\",\"preferred_followup_channel\":\"phone\"}"
              }
            }
          ]
        }
      ]
    }
  }
}
JSON

capture_json="$(
  SPINE_ROOT="$SPINE_ROOT" \
  SPINE_RUNTIME_ROOT="$runtime_root" \
  SPINE_STATE="$state_root" \
  MINT_CUSTOMER_VOICE_SEND_PREVIEW_BIN="$mock_preview" \
  MINT_CUSTOMER_VOICE_SEND_EXECUTE_BIN="$mock_execute" \
  "$BIN_CAPTURE" --payload-file "$payload"
)"

interaction_id="$(printf '%s' "$capture_json" | jq -r '.data.interaction_id')"
callback_id="$(printf '%s' "$capture_json" | jq -r '.data.callback_item_id')"
[[ -n "$interaction_id" && "$interaction_id" != "null" ]] || fail "capture must return interaction_id"
[[ -n "$callback_id" && "$callback_id" != "null" ]] || fail "capture must return callback_item_id"

interaction_file="$(find "$state_root/mint/customer-interactions/records" -name interaction.json | head -n 1)"
callback_file="$(find "$state_root/mint/customer-voice-callbacks/records" -name callback.json | head -n 1)"
[[ -f "$interaction_file" ]] || fail "interaction record missing"
[[ -f "$callback_file" ]] || fail "callback record missing"
[[ "$(jq -r '.linked_callback_item_id' "$interaction_file")" == "$callback_id" ]] || fail "interaction must link callback"
[[ "$(jq -r '.provider_call_id' "$callback_file")" == "call-test-001" ]] || fail "callback must capture provider_call_id"
pass "capture persists interaction + callback"

facts_json="$("$BIN_FACTS" --question "what is your email?")"
[[ "$(printf '%s' "$facts_json" | jq -r '.data.answer')" == "The best email for the Mint team is team@mintprints.com." ]] || fail "facts answer mismatch"
pass "facts capability returns canonical mailbox"

facts_order_json="$("$BIN_FACTS" --question "can you check my order status?")"
[[ "$(printf '%s' "$facts_order_json" | jq -r '.data.answer')" == "I can take your order details now and have the Mint team follow up by email with a status update." ]] || fail "order status fallback mismatch"
pass "facts capability degrades order status to governed follow-up"

callback_json="$(
  SPINE_ROOT="$SPINE_ROOT" \
  SPINE_RUNTIME_ROOT="$runtime_root" \
  SPINE_STATE="$state_root" \
  "$BIN_CALLBACK" \
    --provider-call-id call-tool-001 \
    --caller-number +15615551234 \
    --caller-name "Tool Caller" \
    --reason "general_question" \
    --summary "Need a callback" \
    --urgency medium \
    --preferred-followup-channel email
)"
[[ "$(printf '%s' "$callback_json" | jq -r '.data.result_text')" == "I captured that callback request and the Mint team will follow up." ]] || fail "callback result text mismatch"
pass "callback capability returns operator-safe text"

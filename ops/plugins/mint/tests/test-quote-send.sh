#!/usr/bin/env bash
# test-quote-send.sh - Validate governed Mint quote send through communications preview/execute

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$(cd "$SCRIPT_DIR/../../../.." && pwd)}"

source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init

QUOTE_PROMOTE="$SPINE_ROOT/ops/plugins/mint/bin/quote-promote"
QUOTE_SEND="$SPINE_ROOT/ops/plugins/mint/bin/quote-send"
SEND_PREVIEW="$SPINE_ROOT/ops/plugins/communications/bin/communications-send-preview"
FIXTURES_DIR="$SPINE_ROOT/ops/plugins/mint/tests/fixtures/quote-promote"
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
SPINE_OUTBOX="$TMP_ROOT/outbox"
PROVIDERS_CONTRACT="$TMP_ROOT/providers.yaml"
POLICY_CONTRACT="$TMP_ROOT/policy.yaml"
TEMPLATES_CONTRACT="$TMP_ROOT/templates.yaml"
DELIVERY_CONTRACT="$TMP_ROOT/delivery.yaml"
MOCK_EXECUTE="$TMP_ROOT/mock-communications-send-execute"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }
section() { echo ""; echo "==> $*"; }
cleanup() { rm -rf "$TMP_ROOT"; }
trap cleanup EXIT

mkdir -p "$PACKETS_DIR" "$SPINE_OUTBOX"
cp "$FIXTURES_DIR/approved.packet.yaml" "$PACKETS_DIR/quote_packet_send-ready.yaml"
yq -i '.quote_packet_id = "send-ready"' "$PACKETS_DIR/quote_packet_send-ready.yaml"

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

write_contracts() {
  cat >"$PROVIDERS_CONTRACT" <<'YAML'
version: 1
transactional:
  mode: live
  cutover_phase: phase1-resend-live
  default_sender_email: "noreply@mintprints.com"
  default_sender_name: "Mint Prints"
  default_sms_from: "+15619335513"
  phase_matrix:
    phase1-resend-live:
      resend_execution_mode: live
      twilio_execution_mode: simulation-only
providers:
  resend:
    provider_type: transactional-email
    channels: [email]
    status: active
    execution_mode: live
  microsoft:
    provider_type: mailbox-ops
    channels: [email]
    status: active
    execution_mode: manual-only
routing:
  message_types:
    payment_needed:
      email_provider: resend
YAML

  cat >"$POLICY_CONTRACT" <<'YAML'
version: 1
consent:
  enforce_opt_in_by_default: true
  channels:
    email:
      require_opt_in: true
      opt_in_field: email_opt_in
delivery_windows:
  quiet_hours:
    enabled: false
    timezone_default: "America/New_York"
    start_local: "21:00"
    end_local: "08:00"
    sms_block_during_quiet_hours: true
YAML

  cat >"$TEMPLATES_CONTRACT" <<'YAML'
version: 1
templates:
  - id: payment-needed-email
    message_type: payment_needed
    channel: email
    subject: "Payment needed for order {{order_number}}"
    body_text: |
      Hi {{customer_name}},

      Your order {{order_number}} has a balance due of {{balance_amount}}.
      Pay now: {{payment_link}}
    required_variables:
      - customer_name
      - order_number
      - balance_amount
      - payment_link
YAML

  cat >"$DELIVERY_CONTRACT" <<'YAML'
version: 1
artifacts:
  preview_receipts_dir: "$SPINE_OUTBOX/communications/previews"
  latest_record_file: "$SPINE_OUTBOX/communications/communications-transaction-last.yaml"
  append_log_file: "$SPINE_OUTBOX/communications/communications-delivery-log.jsonl"
execution_policy:
  require_preview_receipt_for_execute: true
  preview_max_age_minutes: 30
  revalidate_on_execute: true
YAML
}

write_mock_execute() {
  cat >"$MOCK_EXECUTE" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

preview_receipt=""
json=0
execute=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --preview-receipt) preview_receipt="$2"; shift 2 ;;
    --preview-id) shift 2 ;;
    --execute) execute=1; shift ;;
    --json) json=1; shift ;;
    *) shift ;;
  esac
done

[[ "$execute" -eq 1 ]] || { echo "ERROR: expected --execute" >&2; exit 1; }
[[ -f "$preview_receipt" ]] || { echo "ERROR: missing preview receipt" >&2; exit 1; }

record_path="$(dirname "$preview_receipt")/mock-send-record.yaml"
log_path="$(dirname "$preview_receipt")/mock-send-log.jsonl"
cat >"$record_path" <<YAML
event_id: "comm-mock-send"
provider: "resend"
status: "sent"
provider_message_id: "re_mock_123"
YAML
printf '%s\n' '{"event_id":"comm-mock-send","status":"sent","provider":"resend"}' >"$log_path"

jq -n \
  --arg capability "communications.send.execute" \
  --arg schema_version "1.0" \
  --arg status "sent" \
  --arg generated_at "2026-03-10T17:00:00Z" \
  --arg preview_receipt "$preview_receipt" \
  --arg record "$record_path" \
  --arg log "$log_path" \
  '{
    capability: $capability,
    schema_version: $schema_version,
    status: $status,
    generated_at: $generated_at,
    data: {
      event_id: "comm-mock-send",
      preview_id: "preview-mock-send",
      preview_receipt: $preview_receipt,
      channel: "email",
      message_type: "payment_needed",
      provider: "resend",
      recipient: "hello@acme.example.com",
      subject: "Payment needed for order mock",
      body: "mock",
      transactional_mode: "live",
      cutover_phase: "phase1-resend-live",
      provider_execution_mode: "live",
      provider_message_id: "re_mock_123",
      record: $record,
      log: $log
    }
  }'
SH
  chmod +x "$MOCK_EXECUTE"
}

run_send() {
  SPINE_OUTBOX="$SPINE_OUTBOX" \
  COMMUNICATIONS_PROVIDERS_CONTRACT="$PROVIDERS_CONTRACT" \
  COMMUNICATIONS_POLICY_CONTRACT="$POLICY_CONTRACT" \
  COMMUNICATIONS_TEMPLATES_CONTRACT="$TEMPLATES_CONTRACT" \
  COMMUNICATIONS_DELIVERY_CONTRACT="$DELIVERY_CONTRACT" \
  MINT_QUOTE_SEND_PREVIEW_BIN="$SEND_PREVIEW" \
  MINT_QUOTE_SEND_EXECUTE_BIN="$MOCK_EXECUTE" \
  MINT_QUOTE_PACKETS_DIR="$PACKETS_DIR" \
  MINT_QUOTE_PACKET_INDEX_FILE="$PACKET_INDEX" \
  MINT_QUOTES_DIR="$QUOTES_DIR" \
  MINT_QUOTES_INDEX_FILE="$QUOTES_INDEX" \
  "$QUOTE_SEND" "$@"
}

attach_payment_ref() {
  local packet_file="$1"
  local quote_file="$2"
  local quote_id="$3"
  local order_id="$4"
  local checkout_id="$5"

  yq -i ".payment_ref = {
    \"payment_provider\": \"stripe\",
    \"payment_link_id\": \"$checkout_id\",
    \"checkout_session_id\": \"$checkout_id\",
    \"payment_link_url\": \"https://checkout.stripe.com/c/pay/$checkout_id\",
    \"payment_link_state\": \"generated\",
    \"payment_amount\": 1219.68,
    \"payment_amount_cents\": 121968,
    \"payment_currency\": \"USD\",
    \"payment_type\": \"full\",
    \"quote_id\": \"$quote_id\",
    \"order_id\": \"$order_id\",
    \"generated_at\": \"2026-03-10T16:00:00Z\"
  }" "$packet_file"

  yq -i ".payment_ref = {
    \"payment_provider\": \"stripe\",
    \"payment_link_id\": \"$checkout_id\",
    \"checkout_session_id\": \"$checkout_id\",
    \"payment_link_url\": \"https://checkout.stripe.com/c/pay/$checkout_id\",
    \"payment_link_state\": \"generated\",
    \"payment_amount\": 1219.68,
    \"payment_amount_cents\": 121968,
    \"payment_currency\": \"USD\",
    \"payment_type\": \"full\",
    \"quote_id\": \"$quote_id\",
    \"order_id\": \"$order_id\",
    \"generated_at\": \"2026-03-10T16:00:00Z\"
  }" "$quote_file"
}

section "Promote packet and attach generated payment link truth"
write_contracts
write_mock_execute
run_promote send-ready --approved-by MINT-OPERATOR-01 >/dev/null
ready_packet="$PACKETS_DIR/quote_packet_send-ready.yaml"
quote_id="$(yq '.quote_id' "$ready_packet")"
order_id="$(yq '.order_id' "$ready_packet")"
quote_file="$QUOTES_DIR/quote_${quote_id}.yaml"
attach_payment_ref "$ready_packet" "$quote_file" "$quote_id" "$order_id" "cs_send_ready"

section "Send succeeds through governed communications bridge"
send_output="$(run_send send-ready --consent-state opted-in)"
[[ "$(yq '.state' "$ready_packet")" == "sent" ]] || fail "quote-send must transition packet to sent"
[[ "$(yq '.sent_at' "$ready_packet")" != "null" ]] || fail "quote-send must stamp packet sent_at"
[[ "$(yq '.quote_state' "$quote_file")" == "sent" ]] || fail "quote-send must transition canonical quote_state to sent"
[[ "$(yq '.sent_at' "$quote_file")" != "null" ]] || fail "quote-send must stamp quote sent_at"
grep -Fq "Pay now: https://checkout.stripe.com/c/pay/cs_send_ready" "$ready_packet" || fail "customer_message_draft must be updated to the final payment-needed body"
[[ "$(yq '.receipts | map(select(.capability_name == "communications.send.preview")) | length' "$ready_packet")" == "1" ]] || fail "packet must capture communications preview receipt"
[[ "$(yq '.receipts | map(select(.capability_name == "communications.send.execute")) | length' "$ready_packet")" == "1" ]] || fail "packet must capture communications execute receipt"
grep -Fq "send_status: success" <<<"$send_output" || fail "quote-send output must report success"
grep -Fq "provider: resend" <<<"$send_output" || fail "quote-send output must report resend provider"
pass "quote-send bridges packet truth into governed communications send and marks the quote sent"

section "Re-running send stays idempotent"
rerun_output="$(run_send send-ready --consent-state opted-in)"
grep -Fq "send_status: existing" <<<"$rerun_output" || fail "rerun must report existing send state"
[[ "$(yq '.receipts | map(select(.capability_name == "communications.send.execute")) | length' "$ready_packet")" == "1" ]] || fail "rerun must not duplicate communications execute receipts"
pass "quote-send is idempotent once the packet is already sent"

section "Consent is a real gate"
cp "$FIXTURES_DIR/approved.packet.yaml" "$PACKETS_DIR/quote_packet_send-no-consent.yaml"
yq -i '.quote_packet_id = "send-no-consent"' "$PACKETS_DIR/quote_packet_send-no-consent.yaml"
run_promote send-no-consent --approved-by MINT-OPERATOR-01 >/dev/null
no_consent_packet="$PACKETS_DIR/quote_packet_send-no-consent.yaml"
no_consent_quote_id="$(yq '.quote_id' "$no_consent_packet")"
no_consent_order_id="$(yq '.order_id' "$no_consent_packet")"
no_consent_quote_file="$QUOTES_DIR/quote_${no_consent_quote_id}.yaml"
attach_payment_ref "$no_consent_packet" "$no_consent_quote_file" "$no_consent_quote_id" "$no_consent_order_id" "cs_send_consent"

set +e
blocked_output="$(run_send send-no-consent 2>&1)"
blocked_rc=$?
set -e
[[ "$blocked_rc" -ne 0 ]] || fail "quote-send must block when consent is unknown"
grep -Fq "consent_not_opted_in" <<<"$blocked_output" || fail "blocked send must explain the consent gate"
[[ "$(yq '.state' "$no_consent_packet")" == "approved_to_send" ]] || fail "blocked send must not mutate packet state"
pass "quote-send treats consent as a real gate"

section "Mint send refuses non-Resend email routing"
yq -i '.routing.message_types.payment_needed.email_provider = "microsoft"' "$PROVIDERS_CONTRACT"
cp "$FIXTURES_DIR/approved.packet.yaml" "$PACKETS_DIR/quote_packet_send-microsoft-route.yaml"
yq -i '.quote_packet_id = "send-microsoft-route"' "$PACKETS_DIR/quote_packet_send-microsoft-route.yaml"
run_promote send-microsoft-route --approved-by MINT-OPERATOR-01 >/dev/null
ms_packet="$PACKETS_DIR/quote_packet_send-microsoft-route.yaml"
ms_quote_id="$(yq '.quote_id' "$ms_packet")"
ms_order_id="$(yq '.order_id' "$ms_packet")"
ms_quote_file="$QUOTES_DIR/quote_${ms_quote_id}.yaml"
attach_payment_ref "$ms_packet" "$ms_quote_file" "$ms_quote_id" "$ms_order_id" "cs_send_microsoft"

set +e
route_block_output="$(run_send send-microsoft-route --consent-state opted-in 2>&1)"
route_block_rc=$?
set -e
[[ "$route_block_rc" -ne 0 ]] || fail "quote-send must reject non-resend routing"
grep -Fq "canonical Mint customer send must route through resend" <<<"$route_block_output" || fail "route block must explain the resend boundary"
pass "quote-send refuses Microsoft as the automated transactional route"

section "Summary"
echo "Quote send checks passed"

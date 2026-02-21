#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)}"
PROVIDER_STATUS="$ROOT/ops/plugins/communications/bin/communications-provider-status"
POLICY_STATUS="$ROOT/ops/plugins/communications/bin/communications-policy-status"
TEMPLATES_LIST="$ROOT/ops/plugins/communications/bin/communications-templates-list"
SEND_PREVIEW="$ROOT/ops/plugins/communications/bin/communications-send-preview"
SEND_EXECUTE="$ROOT/ops/plugins/communications/bin/communications-send-execute"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

command -v yq >/dev/null 2>&1 || fail "yq required"
command -v jq >/dev/null 2>&1 || fail "jq required"
command -v python3 >/dev/null 2>&1 || fail "python3 required"
[[ -x "$PROVIDER_STATUS" ]] || fail "missing communications-provider-status"
[[ -x "$POLICY_STATUS" ]] || fail "missing communications-policy-status"
[[ -x "$TEMPLATES_LIST" ]] || fail "missing communications-templates-list"
[[ -x "$SEND_PREVIEW" ]] || fail "missing communications-send-preview"
[[ -x "$SEND_EXECUTE" ]] || fail "missing communications-send-execute"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/outbox"

providers="$tmp/providers.yaml"
policy="$tmp/policy.yaml"
templates="$tmp/templates.yaml"
delivery="$tmp/delivery.yaml"

cat >"$providers" <<'YAML'
version: 1
transactional:
  mode: simulation-only
  default_sender_email: "noreply@example.com"
  default_sender_name: "Mint Prints"
  default_sms_from: "+15619335513"
providers:
  resend:
    provider_type: transactional-email
    channels: [email]
    status: active
    execution_mode: simulation-only
    required_env: [RESEND_API_KEY, FROM_EMAIL]
  twilio:
    provider_type: transactional-sms
    channels: [sms]
    status: active
    execution_mode: simulation-only
    required_env: [TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_PHONE_NUMBER]
routing:
  message_types:
    payment_needed:
      email_provider: resend
      sms_provider: twilio
YAML

cat >"$policy" <<'YAML'
version: 1
consent:
  enforce_opt_in_by_default: true
  channels:
    email:
      require_opt_in: true
      opt_in_field: email_opt_in
    sms:
      require_opt_in: true
      opt_in_field: sms_opt_in
      require_stop_footer: true
      stop_footer_text: "Reply STOP to opt out."
delivery_windows:
  quiet_hours:
    enabled: false
    timezone_default: "America/New_York"
    start_local: "21:00"
    end_local: "08:00"
    sms_block_during_quiet_hours: true
compliance:
  sms_policy: transactional-only
  marketing_sms_allowed: false
YAML

cat >"$templates" <<'YAML'
version: 1
templates:
  - id: payment-needed-sms
    message_type: payment_needed
    channel: sms
    subject: ""
    body_text: "Hi {{customer_name}}! Balance due {{balance_amount}} for order {{order_number}}. Pay: {{payment_link}}"
    required_variables:
      - customer_name
      - order_number
      - balance_amount
      - payment_link
YAML

cat >"$delivery" <<'YAML'
version: 1
artifacts:
  latest_record_file: "$SPINE_OUTBOX/communications/communications-transaction-last.yaml"
  append_log_file: "$SPINE_OUTBOX/communications/communications-delivery-log.jsonl"
YAML

export COMMUNICATIONS_PROVIDERS_CONTRACT="$providers"
export COMMUNICATIONS_POLICY_CONTRACT="$policy"
export COMMUNICATIONS_TEMPLATES_CONTRACT="$templates"
export COMMUNICATIONS_DELIVERY_CONTRACT="$delivery"
export SPINE_OUTBOX="$tmp/outbox"

provider_out="$("$PROVIDER_STATUS" --json)"
echo "$provider_out" | jq -e '.data.providers[] | select(.id == "twilio")' >/dev/null || fail "provider status missing twilio"
pass "provider status"

policy_out="$("$POLICY_STATUS" --json)"
echo "$policy_out" | jq -e '.data.policy.consent.channels.sms.require_stop_footer == true' >/dev/null || fail "policy status missing sms footer requirement"
pass "policy status"

templates_out="$("$TEMPLATES_LIST" --message-type payment_needed --channel sms --json)"
echo "$templates_out" | jq -e '.data.count == 1' >/dev/null || fail "templates list filter failed"
pass "templates list"

vars='{"customer_name":"Test","order_number":"30020","balance_amount":"150.00","payment_link":"https://example.com/pay"}'
preview_out="$("$SEND_PREVIEW" --channel sms --message-type payment_needed --to +15551234567 --consent-state opted-in --vars-json "$vars" --json)"
echo "$preview_out" | jq -e '.data.provider == "twilio"' >/dev/null || fail "preview should route to twilio"
echo "$preview_out" | jq -e '.data.body | contains("Reply STOP to opt out.")' >/dev/null || fail "preview should append stop footer"
preview_id="$(echo "$preview_out" | jq -r '.data.preview_id // ""')"
preview_receipt="$(echo "$preview_out" | jq -r '.data.preview_receipt // ""')"
[[ -n "$preview_id" ]] || fail "preview should return preview_id"
[[ -n "$preview_receipt" && -f "$preview_receipt" ]] || fail "preview should write receipt artifact"
pass "send preview"

dry_out="$("$SEND_EXECUTE" --channel sms --message-type payment_needed --to +15551234567 --consent-state opted-in --vars-json "$vars" --json)"
echo "$dry_out" | jq -e '.status == "dry-run"' >/dev/null || fail "send execute dry-run status mismatch"
pass "send execute dry-run"

if "$SEND_EXECUTE" --channel sms --message-type payment_needed --to +15551234567 --consent-state opted-in --vars-json "$vars" --execute >/dev/null 2>&1; then
  fail "send execute should require preview linkage"
fi
pass "send execute requires preview linkage"

exec_out="$("$SEND_EXECUTE" --preview-id "$preview_id" --execute --json)"
echo "$exec_out" | jq -e '.status == "simulated"' >/dev/null || fail "send execute simulation status mismatch"
echo "$exec_out" | jq -e --arg preview_id "$preview_id" '.data.preview_id == $preview_id' >/dev/null || fail "execute should link preview id"
record_path="$(echo "$exec_out" | jq -r '.data.record')"
log_path="$(echo "$exec_out" | jq -r '.data.log')"
[[ -f "$record_path" ]] || fail "transaction record missing"
[[ -f "$log_path" ]] || fail "transaction log missing"
jq -cs 'length > 0' "$log_path" >/dev/null || fail "transaction log should contain at least one record"
pass "send execute simulation"

echo "communications transactional tests"

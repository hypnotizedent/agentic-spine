#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
PROVIDER_STATUS="$ROOT/ops/plugins/domains/communications/bin/communications-provider-status"
TEMPLATES_LIST="$ROOT/ops/plugins/domains/communications/bin/communications-templates-list"
SEND_PREVIEW="$ROOT/ops/plugins/domains/communications/bin/communications-send-preview"
SEND_EXECUTE="$ROOT/ops/plugins/domains/communications/bin/communications-send-execute"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

command -v yq >/dev/null 2>&1 || fail "yq required"
command -v jq >/dev/null 2>&1 || fail "jq required"
[[ -x "$PROVIDER_STATUS" ]] || fail "missing communications-provider-status"
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
  mode: live
  cutover_phase: phase1-resend-live
  default_sender_email: "noreply@example.com"
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
    required_env: [RESEND_API_KEY, FROM_EMAIL]
  twilio:
    provider_type: transactional-sms
    channels: [sms]
    status: active
    execution_mode: simulation-only
    required_env: [TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_PHONE_NUMBER]
  vapi:
    provider_type: voice-agent-orchestration
    channels: [voice]
    status: active
    execution_mode: live
    required_env: [VAPI_API_KEY, VAPI_WEBHOOK_SECRET]
routing:
  message_types:
    callback_received:
      sms_provider: twilio
YAML

cat >"$policy" <<'YAML'
version: 1
consent:
  enforce_opt_in_by_default: true
  channels:
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
  - id: callback-received-sms
    message_type: callback_received
    channel: sms
    subject: ""
    body_text: "{{customer_salutation}} We got your request and Mint Prints will follow up soon."
    required_variables:
      - customer_salutation
YAML

cat >"$delivery" <<'YAML'
version: 1
execution_policy:
  require_preview_receipt_for_execute: true
  preview_max_age_minutes: 30
  revalidate_on_execute: true
artifacts:
  preview_receipts_dir: "$SPINE_OUTBOX/communications/previews"
  latest_record_file: "$SPINE_OUTBOX/communications/communications-transaction-last.yaml"
  append_log_file: "$SPINE_OUTBOX/communications/communications-delivery-log.jsonl"
YAML

export COMMUNICATIONS_PROVIDERS_CONTRACT="$providers"
export COMMUNICATIONS_POLICY_CONTRACT="$policy"
export COMMUNICATIONS_TEMPLATES_CONTRACT="$templates"
export COMMUNICATIONS_DELIVERY_CONTRACT="$delivery"
export SPINE_OUTBOX="$tmp/outbox"

provider_out="$("$PROVIDER_STATUS" --json)"
echo "$provider_out" | jq -e '.data.providers[] | select(.id == "vapi" and .provider_type == "voice-agent-orchestration")' >/dev/null || fail "provider status missing vapi voice provider"
echo "$provider_out" | jq -e '.data.providers[] | select(.id == "twilio") | .execution_mode == "simulation-only"' >/dev/null || fail "twilio should remain simulation-only in phase1"
pass "provider status surfaces voice frontdesk providers"

template_out="$("$TEMPLATES_LIST" --message-type callback_received --channel sms --json)"
echo "$template_out" | jq -e '.data.count == 1' >/dev/null || fail "callback_received template missing"
pass "callback_received template listed"

vars='{"customer_salutation":"Hi,"}'
preview_out="$("$SEND_PREVIEW" --channel sms --message-type callback_received --to +15551234567 --consent-state opted-in --vars-json "$vars" --json)"
echo "$preview_out" | jq -e '.data.provider == "twilio"' >/dev/null || fail "preview should route to twilio"
echo "$preview_out" | jq -e '.data.body | contains("Mint Prints will follow up soon.")' >/dev/null || fail "preview body mismatch"
preview_id="$(echo "$preview_out" | jq -r '.data.preview_id // ""')"
[[ -n "$preview_id" ]] || fail "preview should return preview_id"
pass "callback ack preview"

exec_out="$("$SEND_EXECUTE" --preview-id "$preview_id" --execute --json)"
echo "$exec_out" | jq -e '.status == "simulated"' >/dev/null || fail "voice callback ack execute should be simulated in phase1"
echo "$exec_out" | jq -e '.data.message_type == "callback_received"' >/dev/null || fail "execute should preserve callback_received type"
pass "callback ack execute simulation"

echo "communications voice frontdesk tests"

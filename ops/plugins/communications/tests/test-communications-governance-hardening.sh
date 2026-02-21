#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)}"
PREVIEW_BIN="$ROOT/ops/plugins/communications/bin/communications-send-preview"
EXECUTE_BIN="$ROOT/ops/plugins/communications/bin/communications-send-execute"
ANOMALY_STATUS_BIN="$ROOT/ops/plugins/communications/bin/communications-delivery-anomaly-status"
ANOMALY_DISPATCH_BIN="$ROOT/ops/plugins/communications/bin/communications-delivery-anomaly-dispatch"
GATE_D147="$ROOT/surfaces/verify/d147-communications-canonical-routing-lock.sh"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

command -v yq >/dev/null 2>&1 || fail "yq required"
command -v jq >/dev/null 2>&1 || fail "jq required"
command -v python3 >/dev/null 2>&1 || fail "python3 required"
[[ -x "$PREVIEW_BIN" ]] || fail "missing preview bin"
[[ -x "$EXECUTE_BIN" ]] || fail "missing execute bin"
[[ -x "$ANOMALY_STATUS_BIN" ]] || fail "missing anomaly status bin"
[[ -x "$ANOMALY_DISPATCH_BIN" ]] || fail "missing anomaly dispatch bin"
[[ -x "$GATE_D147" ]] || fail "missing D147 gate script"

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
    phase0-simulation:
      resend_execution_mode: simulation-only
      twilio_execution_mode: simulation-only
    phase1-resend-live:
      resend_execution_mode: live
      twilio_execution_mode: simulation-only
    phase2-full-live:
      resend_execution_mode: live
      twilio_execution_mode: live
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
  - id: payment-needed-email
    message_type: payment_needed
    channel: email
    subject: "Payment needed for order {{order_number}}"
    body_text: "Hi {{customer_name}}, balance {{balance_amount}} is due."
    required_variables:
      - customer_name
      - order_number
      - balance_amount
  - id: payment-needed-sms
    message_type: payment_needed
    channel: sms
    subject: ""
    body_text: "Hi {{customer_name}}! Balance due {{balance_amount}} for order {{order_number}}."
    required_variables:
      - customer_name
      - order_number
      - balance_amount
YAML

cat >"$delivery" <<'YAML'
version: 1
artifacts:
  preview_receipts_dir: "$SPINE_OUTBOX/communications/previews"
  latest_record_file: "$SPINE_OUTBOX/communications/communications-transaction-last.yaml"
  append_log_file: "$SPINE_OUTBOX/communications/communications-delivery-log.jsonl"
  anomaly_alert_dir: "$SPINE_OUTBOX/communications/alerts"
  anomaly_cooldown_dir: "$SPINE_OUTBOX/communications/alerts/.cooldown"
execution_policy:
  require_preview_receipt_for_execute: true
  preview_max_age_minutes: 30
  revalidate_on_execute: true
anomaly_alerting:
  enabled: true
  evaluation_window_records: 100
  min_records_to_alert: 1
  cooldown_seconds: 30
  channels: [bridge-push]
  thresholds:
    failure_rate_warn: 0.20
    failure_rate_incident: 0.40
    policy_block_rate_warn: 0.20
    policy_block_rate_incident: 0.40
    provider_timeout_count_warn: 1
    provider_timeout_count_incident: 2
YAML

export COMMUNICATIONS_PROVIDERS_CONTRACT="$providers"
export COMMUNICATIONS_POLICY_CONTRACT="$policy"
export COMMUNICATIONS_TEMPLATES_CONTRACT="$templates"
export COMMUNICATIONS_DELIVERY_CONTRACT="$delivery"
export SPINE_OUTBOX="$tmp/outbox"

vars='{"customer_name":"Test","order_number":"30020","balance_amount":"150.00"}'

# Phase matrix: resend should be live in phase1, twilio remains simulation-only.
email_preview="$($PREVIEW_BIN --channel email --message-type payment_needed --to test@example.com --consent-state opted-in --vars-json "$vars" --json)"
echo "$email_preview" | jq -e '.data.cutover_phase == "phase1-resend-live"' >/dev/null || fail "cutover phase missing"
echo "$email_preview" | jq -e '.data.provider == "resend" and .data.provider_execution_mode == "live"' >/dev/null || fail "resend should be live in phase1"
pass "phase matrix resend live"

sms_preview="$($PREVIEW_BIN --channel sms --message-type payment_needed --to +15551234567 --consent-state opted-in --vars-json "$vars" --json)"
echo "$sms_preview" | jq -e '.data.provider == "twilio" and .data.provider_execution_mode == "simulation-only"' >/dev/null || fail "twilio should remain simulation-only in phase1"
pass "phase matrix twilio simulated"

# Switch transactional mode to simulation-only to exercise execute without external API keys.
yq e -i '.transactional.mode = "simulation-only"' "$providers"

sms_preview_sim="$($PREVIEW_BIN --channel sms --message-type payment_needed --to +15551234567 --consent-state opted-in --vars-json "$vars" --json)"
preview_id="$(echo "$sms_preview_sim" | jq -r '.data.preview_id')"

if "$EXECUTE_BIN" --channel sms --message-type payment_needed --to +15551234567 --consent-state opted-in --vars-json "$vars" --execute >/dev/null 2>&1; then
  fail "execute should require preview linkage"
fi
pass "execute requires preview linkage"

exec_ok="$($EXECUTE_BIN --preview-id "$preview_id" --execute --json)"
echo "$exec_ok" | jq -e '.status == "simulated"' >/dev/null || fail "linked execute should simulate"
pass "linked execute simulation"

blocked_preview="$($PREVIEW_BIN --channel sms --message-type payment_needed --to +15551234567 --consent-state opted-out --vars-json "$vars" --json)"
blocked_preview_id="$(echo "$blocked_preview" | jq -r '.data.preview_id')"
if "$EXECUTE_BIN" --preview-id "$blocked_preview_id" --execute --json >/dev/null 2>&1; then
  fail "policy-blocked execute should fail"
fi
pass "policy-blocked execute failure"

anomaly_status="$($ANOMALY_STATUS_BIN --json)"
echo "$anomaly_status" | jq -e '.status == "incident" or .status == "warn"' >/dev/null || fail "anomaly status should detect elevated failure/policy-block rate"
pass "anomaly status"

anomaly_dispatch="$($ANOMALY_DISPATCH_BIN --dry-run --json)"
echo "$anomaly_dispatch" | jq -e '.created >= 1' >/dev/null || fail "anomaly dispatch should create alert artifact in dry-run"
pass "anomaly dispatch"

# Guard gate should pass in current canonical tree.
"$GATE_D147" >/dev/null || fail "D147 gate should pass in canonical tree"
pass "D147 gate"

echo "communications governance hardening tests"

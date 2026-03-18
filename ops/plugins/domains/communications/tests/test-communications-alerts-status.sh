#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
QUEUE_STATUS_BIN="$ROOT/ops/plugins/domains/communications/bin/communications-alerts-queue-status"
QUEUE_SLO_BIN="$ROOT/ops/plugins/domains/communications/bin/communications-alerts-queue-slo-status"
RUNTIME_STATUS_BIN="$ROOT/ops/plugins/domains/communications/bin/communications-alerts-runtime-status"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || fail "jq required"
[[ -x "$QUEUE_STATUS_BIN" ]] || fail "queue status script missing"
[[ -x "$QUEUE_SLO_BIN" ]] || fail "queue slo script missing"
[[ -x "$RUNTIME_STATUS_BIN" ]] || fail "runtime status script missing"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

outbox="$tmp/outbox"
intent_dir="$outbox/alerts/email-intents"
dead_dir="$outbox/alerts/email-intents-dead-letter"
esc_dir="$outbox/alerts/communications/escalations"
mkdir -p "$intent_dir" "$dead_dir" "$esc_dir"

contract="$tmp/communications.alerts.queue.contract.yaml"
cat >"$contract" <<'YAML'
retry_policy:
  enabled: true
  dead_letter_dir: "$SPINE_OUTBOX/alerts/email-intents-dead-letter"
dispatcher:
  enabled: false
slo:
  warn_age_seconds: 60
  incident_age_seconds: 120
  max_pending_warn: 2
  max_pending_incident: 10
  dead_letter_warn: 1
  dead_letter_incident: 5
recommended_actions:
  flush_command: "./bin/ops cap run communications.alerts.queue.flush --execute"
  dispatcher_start_command: "echo yes | ./bin/ops cap run communications.alerts.dispatcher.start"
  replay_dead_letter_command: "./bin/ops cap run communications.alerts.dead-letter.replay --execute"
YAML

cat >"$intent_dir/email-intent-a.yaml" <<'YAML'
intent_id: email-intent-a
created_at: "2026-03-16T00:00:00Z"
domain_id: communications
severity: warn
suggested_recipient: alerts@example.com
flush_status: pending
attempts: 0
YAML

cat >"$intent_dir/email-intent-b.yaml" <<'YAML'
intent_id: email-intent-b
created_at: "2026-03-16T00:30:00Z"
domain_id: communications
severity: incident
suggested_recipient: alerts@example.com
flush_status: failed
attempts: 2
last_error: retry me
YAML

cat >"$intent_dir/email-intent-c.yaml" <<'YAML'
intent_id: email-intent-c
created_at: "2099-03-16T00:45:00Z"
domain_id: communications
severity: warn
suggested_recipient: alerts@example.com
flush_status: retry_scheduled
attempts: 1
next_retry_at: "2099-03-16T01:45:00Z"
YAML

cat >"$intent_dir/email-intent-d.yaml" <<'YAML'
intent_id: email-intent-d
created_at: "2026-03-16T00:50:00Z"
domain_id: communications
severity: warn
suggested_recipient: alerts@example.com
flush_status: sent
attempts: 1
YAML

cat >"$dead_dir/email-intent-dead.yaml" <<'YAML'
intent_id: email-intent-dead
status: dead-letter
YAML

cat >"$esc_dir/ESCALATION-20260316-queue.yaml" <<'YAML'
status: open
created_at: "2026-03-16T01:00:00Z"
fingerprint: esc-fp-001
YAML

common_env=(
  "SPINE_OUTBOX=$outbox"
  "COMMUNICATIONS_ALERTS_QUEUE_CONTRACT=$contract"
)

queue_json="$(env "${common_env[@]}" "$QUEUE_STATUS_BIN" --limit 2 --json)"
echo "$queue_json" | jq -e '.data.pending_count == 3' >/dev/null || fail "queue pending count"
echo "$queue_json" | jq -e '.data.pending_ready_count == 2' >/dev/null || fail "queue ready count"
echo "$queue_json" | jq -e '.data.retry_scheduled_count == 1' >/dev/null || fail "queue retry scheduled count"
echo "$queue_json" | jq -e '.data.sent_count == 1' >/dev/null || fail "queue sent count"
echo "$queue_json" | jq -e '.data.failed_count == 1' >/dev/null || fail "queue failed count"
echo "$queue_json" | jq -e '.data.dead_letter_count == 1' >/dev/null || fail "queue dead letter count"
echo "$queue_json" | jq -e '.data.top_pending | length == 2' >/dev/null || fail "queue limit respected"
pass "communications queue status aggregates queue files in one pass"

slo_json="$(env "${common_env[@]}" "$QUEUE_SLO_BIN" --json)"
echo "$slo_json" | jq -e '.status == "incident"' >/dev/null || fail "queue slo incident expected"
echo "$slo_json" | jq -e '.data.oldest_pending_age_seconds >= .data.thresholds.incident_age_seconds' >/dev/null || fail "queue slo age threshold should trigger incident"
echo "$slo_json" | jq -e '.data.escalation_recommended == true' >/dev/null || fail "queue slo escalation recommendation"
pass "communications queue slo status derives thresholds from queue summary"

runtime_json="$(env "${common_env[@]}" "$RUNTIME_STATUS_BIN" --json)"
echo "$runtime_json" | jq -e '.status == "incident"' >/dev/null || fail "runtime status should inherit incident"
echo "$runtime_json" | jq -e '.data.queue_pending_count == 3' >/dev/null || fail "runtime queue pending count"
echo "$runtime_json" | jq -e '.data.pending_escalation_task_count == 1' >/dev/null || fail "runtime escalation count"
echo "$runtime_json" | jq -e '.data.last_escalation_fingerprint == "esc-fp-001"' >/dev/null || fail "runtime latest escalation fingerprint"
echo "$runtime_json" | jq -e '.data.oneliner | contains("CommsQueue: incident")' >/dev/null || fail "runtime oneliner"
pass "communications runtime status reuses fast queue summary without double scanning"

echo "communications alerts status tests"

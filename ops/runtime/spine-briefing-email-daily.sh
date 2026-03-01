#!/usr/bin/env bash
set -euo pipefail

# Scheduled runner: generate briefing and route to transactional email pipeline
# LaunchAgent: com.ronny.spine-briefing-email-daily
# Gap: GAP-OP-742

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CAP_RUNNER="${SPINE_ROOT}/bin/ops"
STACK_CONTRACT="${SPINE_ROOT}/ops/bindings/communications.stack.contract.yaml"
source "${SPINE_ROOT}/ops/runtime/lib/job-wrapper.sh"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "[spine-briefing-email-daily] missing dependency: $1" >&2
    exit 1
  }
}

require_cmd yq
require_cmd jq

echo "[spine-briefing-email-daily] start $(date -u +%Y-%m-%dT%H:%M:%SZ)"

recipient="$(yq -r '.pilot.send_test.default_recipient // ""' "$STACK_CONTRACT")"
if [[ -z "$recipient" || "$recipient" == "null" ]]; then
  echo "[spine-briefing-email-daily] STOP: missing pilot.send_test.default_recipient" >&2
  exit 1
fi

briefing_json="$("${SPINE_ROOT}/ops/plugins/briefing/bin/spine-briefing" --json)"
overall="$(echo "$briefing_json" | jq -r '.overall_status // "unknown"')"
generated="$(echo "$briefing_json" | jq -r '.generated_at_utc // ""')"
sections="$(
  echo "$briefing_json" | jq -r '.sections[]? | "- " + (.section // "unknown") + ": [" + (.status // "unknown") + "] " + (.summary // "")'
)"

subject="Spine Daily Briefing $(date +%Y-%m-%d) (${overall})"
body=$'Spine daily briefing generated.\n'
body+=$'Generated (UTC): '"$generated"$'\n'
body+=$'Overall status: '"$overall"$'\n\n'
body+=$'Section summary:\n'
body+="${sections}"$'\n\n'
body+=$'Artifact: '"${SPINE_ROOT}/mailroom/outbox/briefing/briefing-latest.md"

vars_json="$(jq -cn --arg subject "$subject" --arg body_text "$body" '{subject:$subject, body_text:$body_text}')"

preview_json="$(
  "${SPINE_ROOT}/ops/plugins/communications/bin/communications-send-preview" \
    --channel email \
    --message-type custom \
    --to "$recipient" \
    --vars-json "$vars_json" \
    --consent-state opted-in \
    --json
)"

preview_id="$(echo "$preview_json" | jq -r '.data.preview_id // ""')"
if [[ -z "$preview_id" || "$preview_id" == "null" ]]; then
  echo "[spine-briefing-email-daily] STOP: preview did not return preview_id" >&2
  exit 1
fi

spine_job_run "spine-briefing-email-daily:secrets.binding" \
  "$CAP_RUNNER" cap run secrets.binding
spine_job_run "spine-briefing-email-daily:secrets.auth.status" \
  "$CAP_RUNNER" cap run secrets.auth.status
echo "yes" | "$CAP_RUNNER" cap run communications.send.execute --preview-id "$preview_id" --execute --json

echo "[spine-briefing-email-daily] done $(date -u +%Y-%m-%dT%H:%M:%SZ)"

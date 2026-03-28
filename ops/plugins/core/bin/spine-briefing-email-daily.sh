#!/usr/bin/env bash
set -euo pipefail

# Scheduled runner: generate briefing and route to transactional email pipeline
# LaunchAgent: com.ronny.spine-briefing-email-daily
# Gap: GAP-OP-742

SPINE_ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../" && pwd)}"
CAP_RUNNER="${CAP_RUNNER:-${SPINE_ROOT}/bin/ops}"
STACK_CONTRACT="${STACK_CONTRACT:-${SPINE_ROOT}/ops/bindings/domains/communications/communications.stack.contract.yaml}"
COMMUNICATIONS_BINDINGS_ROOT="${COMMUNICATIONS_BINDINGS_ROOT:-${SPINE_ROOT}/ops/bindings/domains/communications}"
SPINE_BRIEFING_BIN="${SPINE_BRIEFING_BIN:-${SPINE_ROOT}/ops/plugins/core/briefing/bin/spine-briefing}"
COMMUNICATIONS_SEND_PREVIEW_BIN="${COMMUNICATIONS_SEND_PREVIEW_BIN:-${SPINE_ROOT}/ops/plugins/domains/communications/bin/communications-send-preview}"
SESSION_ENTRY_PACKET_BIN="${SESSION_ENTRY_PACKET_BIN:-${SPINE_ROOT}/ops/plugins/core/session/bin/session-entry-packet}"
source "${SPINE_ROOT}/ops/lib/runtime-paths.sh"
spine_runtime_resolve_paths
source "${SPINE_ROOT}/ops/lib/job-wrapper.sh"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "[spine-briefing-email-daily] missing dependency: $1" >&2
    exit 1
  }
}

require_exec() {
  [[ -x "$1" ]] || {
    echo "[spine-briefing-email-daily] missing executable: $1" >&2
    exit 1
  }
}

require_file() {
  [[ -f "$1" ]] || {
    echo "[spine-briefing-email-daily] missing file: $1" >&2
    exit 1
  }
}

export_communications_contract_paths() {
  export COMMUNICATIONS_PROVIDERS_CONTRACT="${COMMUNICATIONS_PROVIDERS_CONTRACT:-${COMMUNICATIONS_BINDINGS_ROOT}/communications.providers.contract.yaml}"
  export COMMUNICATIONS_POLICY_CONTRACT="${COMMUNICATIONS_POLICY_CONTRACT:-${COMMUNICATIONS_BINDINGS_ROOT}/communications.policy.contract.yaml}"
  export COMMUNICATIONS_TEMPLATES_CONTRACT="${COMMUNICATIONS_TEMPLATES_CONTRACT:-${COMMUNICATIONS_BINDINGS_ROOT}/communications.templates.catalog.yaml}"
  export COMMUNICATIONS_DELIVERY_CONTRACT="${COMMUNICATIONS_DELIVERY_CONTRACT:-${COMMUNICATIONS_BINDINGS_ROOT}/communications.delivery.contract.yaml}"
}

ensure_scheduled_attach_context() {
  local entry_exports

  if [[ -n "${SPINE_ENTRY_PACKET_PATH:-}" && -n "${SPINE_ENTRY_PACKET_HASH:-}" ]]; then
    return 0
  fi

  if [[ "${SPINE_AUTONOMOUS_EXECUTION_CONTEXT:-}" != "launchd_scheduler" ]]; then
    return 0
  fi

  require_exec "$SESSION_ENTRY_PACKET_BIN"
  entry_exports="$(
    "$SESSION_ENTRY_PACKET_BIN" \
      --role worker \
      --lane scheduled \
      --execution-mode operational \
      --transport mailroom \
      --objective "Deliver the governed pilot Spine daily briefing email." \
      --done-check "Preview and execute receipts exist for the scheduled briefing email run." \
      --first-command "$0" \
      --emit-exports
  )"
  eval "$entry_exports"
}

require_cmd yq
require_cmd jq
require_exec "$SPINE_BRIEFING_BIN"
require_exec "$COMMUNICATIONS_SEND_PREVIEW_BIN"
require_file "$STACK_CONTRACT"
export_communications_contract_paths

echo "[spine-briefing-email-daily] start $(date -u +%Y-%m-%dT%H:%M:%SZ)"

recipient="$(yq -r '.pilot.send_test.default_recipient // ""' "$STACK_CONTRACT")"
if [[ -z "$recipient" || "$recipient" == "null" ]]; then
  echo "[spine-briefing-email-daily] STOP: missing pilot.send_test.default_recipient" >&2
  exit 1
fi

briefing_json="$("$SPINE_BRIEFING_BIN" --json)"
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
body+=$'Artifact: '"${SPINE_OUTBOX}/briefing/briefing-latest.md"

vars_json="$(jq -cn --arg subject "$subject" --arg body_text "$body" '{subject:$subject, body_text:$body_text}')"

preview_json="$(
  "$COMMUNICATIONS_SEND_PREVIEW_BIN" \
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

ensure_scheduled_attach_context

spine_job_run "spine-briefing-email-daily:secrets.binding" \
  "$CAP_RUNNER" cap run secrets.binding
spine_job_run "spine-briefing-email-daily:secrets.auth.status" \
  "$CAP_RUNNER" cap run secrets.auth.status
echo "yes" | "$CAP_RUNNER" cap run communications.send.execute --preview-id "$preview_id" --execute --json

echo "[spine-briefing-email-daily] done $(date -u +%Y-%m-%dT%H:%M:%SZ)"

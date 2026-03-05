#!/usr/bin/env bash
set -euo pipefail

# Structured JSONL telemetry helper.
# Envelope:
# {timestamp_utc, event_type, domain, gate_id, status, message, run_key, source, meta}

spine_log_event() {
  local event_type="event"
  local domain="none"
  local gate_id=""
  local status="info"
  local message=""
  local run_key=""
  local source_id=""
  local meta_json="{}"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --event-type) shift; event_type="${1:-event}" ;;
      --domain) shift; domain="${1:-none}" ;;
      --gate-id) shift; gate_id="${1:-}" ;;
      --status) shift; status="${1:-info}" ;;
      --message) shift; message="${1:-}" ;;
      --run-key) shift; run_key="${1:-}" ;;
      --source) shift; source_id="${1:-}" ;;
      --meta-json)
        shift
        meta_json="${1:-}"
        [[ -n "$meta_json" ]] || meta_json='{}'
        ;;
      *) ;;
    esac
    shift || true
  done

  local root="${SPINE_ROOT:-${SPINE_REPO:-$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || pwd)}}"
  local default_logs="${SPINE_LOGS:-$root/mailroom/logs}"
  local log_file="${SPINE_STRUCTURED_LOG:-$default_logs/spine-events.jsonl}"
  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  [[ -n "$source_id" ]] || source_id="${0##*/}"
  mkdir -p "$(dirname "$log_file")"

  if command -v jq >/dev/null 2>&1; then
    local meta_payload="$meta_json"
    if ! printf '%s' "$meta_payload" | jq -e '.' >/dev/null 2>&1; then
      meta_payload="$(jq -cn --arg raw "$meta_json" '{parse_error:true,raw:$raw}')"
    fi
    jq -cn \
      --arg timestamp_utc "$ts" \
      --arg event_type "$event_type" \
      --arg domain "$domain" \
      --arg gate_id "$gate_id" \
      --arg status "$status" \
      --arg message "$message" \
      --arg run_key "$run_key" \
      --arg source "$source_id" \
      --argjson meta "$meta_payload" \
      '{timestamp_utc:$timestamp_utc,event_type:$event_type,domain:$domain,gate_id:$gate_id,status:$status,message:$message,run_key:$run_key,source:$source,meta:$meta}' >> "$log_file"
  else
    printf '{"timestamp_utc":"%s","event_type":"%s","domain":"%s","gate_id":"%s","status":"%s","message":"%s","run_key":"%s","source":"%s","meta":{}}\n' \
      "$ts" "$event_type" "$domain" "$gate_id" "$status" "$message" "$run_key" "$source_id" >> "$log_file"
  fi
}

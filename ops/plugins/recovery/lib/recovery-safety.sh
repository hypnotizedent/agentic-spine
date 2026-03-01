#!/usr/bin/env bash

# Shared safety/state helpers for recovery plugin scripts.

RECOVERY_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RECOVERY_ROOT="${SPINE_ROOT:-$(cd "$RECOVERY_LIB_DIR/../../../.." && pwd)}"
RECOVERY_STATE_ROOT="${RECOVERY_STATE_ROOT:-$RECOVERY_ROOT/ops/plugins/recovery/state}"
RECOVERY_COOLDOWN_DIR="${RECOVERY_COOLDOWN_DIR:-$RECOVERY_STATE_ROOT/cooldown}"
RECOVERY_ATTEMPTS_DIR="${RECOVERY_ATTEMPTS_DIR:-$RECOVERY_STATE_ROOT/attempts}"
RECOVERY_AUDIT_LOG="${RECOVERY_AUDIT_LOG:-$RECOVERY_ROOT/mailroom/logs/recovery-dispatch.ndjson}"

recovery_now_epoch() {
  date +%s
}

recovery_now_utc() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

recovery_sanitize_id() {
  local raw="$1"
  printf '%s' "$raw" | tr -cs 'A-Za-z0-9._-' '_'
}

recovery_init_state() {
  mkdir -p "$RECOVERY_COOLDOWN_DIR" "$RECOVERY_ATTEMPTS_DIR" "$(dirname "$RECOVERY_AUDIT_LOG")"
  touch "$RECOVERY_AUDIT_LOG"
}

recovery_cooldown_file() {
  local sid
  sid="$(recovery_sanitize_id "$1")"
  printf '%s/%s' "$RECOVERY_COOLDOWN_DIR" "$sid"
}

recovery_attempt_file() {
  local sid
  sid="$(recovery_sanitize_id "$1")"
  printf '%s/%s' "$RECOVERY_ATTEMPTS_DIR" "$sid"
}

recovery_get_attempt() {
  local file
  file="$(recovery_attempt_file "$1")"
  if [[ -f "$file" ]]; then
    cat "$file" 2>/dev/null || echo 0
  else
    echo 0
  fi
}

recovery_increment_attempt() {
  local action_id="$1"
  local file current next
  file="$(recovery_attempt_file "$action_id")"
  current="$(recovery_get_attempt "$action_id")"
  [[ "$current" =~ ^[0-9]+$ ]] || current=0
  next=$((current + 1))
  printf '%s\n' "$next" > "$file"
  echo "$next"
}

recovery_touch_cooldown() {
  local file
  file="$(recovery_cooldown_file "$1")"
  recovery_now_epoch > "$file"
}

# Returns 0 when recovery should be suppressed by cooldown, 1 otherwise.
recovery_check_cooldown() {
  local action_id="$1"
  local cooldown_seconds="$2"
  local file now last
  file="$(recovery_cooldown_file "$action_id")"

  [[ "$cooldown_seconds" =~ ^[0-9]+$ ]] || cooldown_seconds=0
  if (( cooldown_seconds <= 0 )); then
    return 1
  fi

  if [[ ! -f "$file" ]]; then
    return 1
  fi

  last="$(cat "$file" 2>/dev/null || echo 0)"
  [[ "$last" =~ ^[0-9]+$ ]] || last=0
  now="$(recovery_now_epoch)"

  if (( now - last < cooldown_seconds )); then
    return 0
  fi

  return 1
}

# Returns 0 when attempts are exhausted, 1 otherwise.
recovery_check_exhausted() {
  local action_id="$1"
  local max_attempts="$2"
  local current
  [[ "$max_attempts" =~ ^[0-9]+$ ]] || max_attempts=0
  if (( max_attempts <= 0 )); then
    return 1
  fi

  current="$(recovery_get_attempt "$action_id")"
  [[ "$current" =~ ^[0-9]+$ ]] || current=0
  if (( current >= max_attempts )); then
    return 0
  fi

  return 1
}

recovery_clear_state() {
  local action_id="$1"
  rm -f "$(recovery_attempt_file "$action_id")" "$(recovery_cooldown_file "$action_id")"
}

recovery_log_attempt() {
  local gate_id="$1"
  local failure_class="$2"
  local action_id="$3"
  local attempt="$4"
  local result="$5"
  local escalated="$6"
  local message="$7"
  local suppressed="$8"

  if command -v jq >/dev/null 2>&1; then
    jq -cn \
      --arg ts "$(recovery_now_utc)" \
      --arg gate_id "$gate_id" \
      --arg failure_class "$failure_class" \
      --arg action_id "$action_id" \
      --argjson attempt "${attempt:-0}" \
      --arg result "$result" \
      --argjson escalated "$( [[ "$escalated" == "true" ]] && echo true || echo false )" \
      --argjson suppressed "$( [[ "$suppressed" == "true" ]] && echo true || echo false )" \
      --arg message "$message" \
      '{timestamp_utc:$ts,gate_id:$gate_id,failure_class:$failure_class,action_id:$action_id,attempt:$attempt,result:$result,escalated:$escalated,suppressed:$suppressed,message:$message}' \
      >> "$RECOVERY_AUDIT_LOG"
  else
    printf '%s gate_id=%s failure_class=%s action_id=%s attempt=%s result=%s escalated=%s suppressed=%s msg=%s\n' \
      "$(recovery_now_utc)" "$gate_id" "$failure_class" "$action_id" "$attempt" "$result" "$escalated" "$suppressed" "$message" \
      >> "$RECOVERY_AUDIT_LOG"
  fi
}

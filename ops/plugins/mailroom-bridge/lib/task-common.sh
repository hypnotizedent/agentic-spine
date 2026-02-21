#!/usr/bin/env bash
set -euo pipefail

MAILROOM_TASK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
source "$MAILROOM_TASK_ROOT/ops/lib/runtime-paths.sh"
spine_runtime_resolve_paths

MAILROOM_TASK_STATE_ROOT="$SPINE_STATE/agent-tasks"
MAILROOM_TASK_QUEUED="$MAILROOM_TASK_STATE_ROOT/queued"
MAILROOM_TASK_RUNNING="$MAILROOM_TASK_STATE_ROOT/running"
MAILROOM_TASK_DONE="$MAILROOM_TASK_STATE_ROOT/done"
MAILROOM_TASK_FAILED="$MAILROOM_TASK_STATE_ROOT/failed"

mailroom_task_now() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

mailroom_task_require() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "FAIL: missing dependency: $1" >&2
    exit 2
  }
}

mailroom_task_init_dirs() {
  mkdir -p "$MAILROOM_TASK_QUEUED" "$MAILROOM_TASK_RUNNING" "$MAILROOM_TASK_DONE" "$MAILROOM_TASK_FAILED"
}

mailroom_task_generate_id() {
  local ts rand
  ts="$(date -u +%Y%m%dT%H%M%SZ)"
  rand="$(printf '%04x' "$((RANDOM % 65536))")"
  printf 'TASK-%s-%s\n' "$ts" "$rand"
}

mailroom_task_csv_to_json_array() {
  local raw="${1:-}"
  if [[ -z "$raw" ]]; then
    echo '[]'
    return 0
  fi
  printf '%s' "$raw" \
    | tr ',' '\n' \
    | sed 's/^ *//; s/ *$//' \
    | sed '/^$/d' \
    | jq -Rsc 'split("\n") | map(select(length > 0))'
}

mailroom_task_emit_json() {
  local capability="$1"
  local status="$2"
  local data_json="${3:-}"
  [[ -n "$data_json" ]] || data_json='{}'
  jq -n \
    --arg capability "$capability" \
    --arg schema_version "1.0" \
    --arg status "$status" \
    --arg generated_at "$(mailroom_task_now)" \
    --argjson data "$data_json" \
    '{capability:$capability,schema_version:$schema_version,status:$status,generated_at:$generated_at,data:$data}'
}

mailroom_task_existing_file() {
  local task_id="$1"
  local candidate
  for candidate in \
    "$MAILROOM_TASK_QUEUED/$task_id.yaml" \
    "$MAILROOM_TASK_RUNNING/$task_id.yaml" \
    "$MAILROOM_TASK_DONE/$task_id.yaml" \
    "$MAILROOM_TASK_FAILED/$task_id.yaml"; do
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

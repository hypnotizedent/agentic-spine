#!/usr/bin/env bash
set -euo pipefail

# Scheduled runner: consume verify gate-bug review queue and emit digest.
# LaunchAgent: com.ronny.verify-gate-review-consumer-daily

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
QUEUE_FILE="${VERIFY_GATE_REVIEW_QUEUE_FILE:-$SPINE_ROOT/mailroom/outbox/alerts/verify-gate-review-queue.ndjson}"
ARCHIVE_FILE="${VERIFY_GATE_REVIEW_ARCHIVE_FILE:-$SPINE_ROOT/mailroom/outbox/alerts/verify-gate-review-queue.archive.ndjson}"
source "${SPINE_ROOT}/ops/runtime/lib/job-wrapper.sh"

consume_gate_review_queue() {
  local tmp_valid total_count valid_count invalid_count
  local unique_gates oldest newest top_counts

  mkdir -p "$(dirname "$QUEUE_FILE")"
  mkdir -p "$(dirname "$ARCHIVE_FILE")"

  if [[ ! -f "$QUEUE_FILE" || ! -s "$QUEUE_FILE" ]]; then
    echo "[verify-gate-review-consumer-daily] queue empty"
    return 0
  fi

  tmp_valid="$(mktemp)"
  total_count=0
  invalid_count=0

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -n "$line" ]] || continue
    total_count=$((total_count + 1))
    if jq -e . >/dev/null 2>&1 <<<"$line"; then
      echo "$line" >> "$tmp_valid"
    else
      invalid_count=$((invalid_count + 1))
    fi
  done < "$QUEUE_FILE"

  if [[ ! -s "$tmp_valid" ]]; then
    rm -f "$tmp_valid"
    : > "$QUEUE_FILE"
    if (( invalid_count > 0 )); then
      spine_enqueue_email_intent \
        "verify-gate-review" \
        "warn" \
        "verify gate review queue had invalid entries" \
        "invalid_entries=${invalid_count}; queue reset with no valid JSON lines." \
        "verify-gate-review-consumer-daily"
    fi
    return 0
  fi

  valid_count="$(wc -l < "$tmp_valid" | tr -d ' ')"
  unique_gates="$(jq -sr '[.[] | .gate_id] | unique | length' "$tmp_valid")"
  oldest="$(jq -sr 'map(.timestamp_utc // "") | sort | first // ""' "$tmp_valid")"
  newest="$(jq -sr 'map(.timestamp_utc // "") | sort | last // ""' "$tmp_valid")"
  top_counts="$(jq -sr 'group_by(.gate_id) | map({gate_id: .[0].gate_id, count: length}) | sort_by(-.count) | .[:5] | map("\(.gate_id):\(.count)") | join(", ")' "$tmp_valid")"

  cat "$tmp_valid" >> "$ARCHIVE_FILE"
  : > "$QUEUE_FILE"
  rm -f "$tmp_valid"

  spine_enqueue_email_intent \
    "verify-gate-review" \
    "warn" \
    "verify gate review queue digest" \
    "total_entries=${total_count} valid_entries=${valid_count} invalid_entries=${invalid_count} unique_gates=${unique_gates} window=${oldest}..${newest} top_gates=${top_counts} archive_file=${ARCHIVE_FILE}" \
    "verify-gate-review-consumer-daily"
}

echo "[verify-gate-review-consumer-daily] start $(date -u +%Y-%m-%dT%H:%M:%SZ)"
spine_job_run "verify-gate-review-consumer-daily:consume" consume_gate_review_queue
echo "[verify-gate-review-consumer-daily] done $(date -u +%Y-%m-%dT%H:%M:%SZ)"


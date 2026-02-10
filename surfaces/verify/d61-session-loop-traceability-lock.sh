#!/usr/bin/env bash
# D61: Session-loop traceability lock
# Fails when agent.session.closeout has not been run within
# SESSION_CLOSEOUT_FRESHNESS_HOURS (default: 48).
#
# Reads: mailroom/state/ledger.csv
set -euo pipefail

SP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LEDGER="$SP/mailroom/state/ledger.csv"
THRESHOLD_HOURS="${SESSION_CLOSEOUT_FRESHNESS_HOURS:-48}"

FAIL=0
err() { echo "  FAIL: $1" >&2; FAIL=1; }

[[ -f "$LEDGER" ]] || { err "ledger.csv not found"; exit 1; }

# Find the most recent agent.session.closeout entry with status=done
# Ledger columns: run_id,created_at,started_at,finished_at,status,prompt_file,result_file,error,context_used
# Capability entries use prompt_file=agent.session.closeout

LAST_TS=""
while IFS=, read -r run_id created_at started_at finished_at status prompt_file _rest; do
  if [[ "$prompt_file" == "agent.session.closeout" && "$status" == "done" && -n "$finished_at" ]]; then
    LAST_TS="$finished_at"
  fi
done < <(tail -n +2 "$LEDGER")

if [[ -z "$LAST_TS" ]]; then
  err "agent.session.closeout has never been run (0 done entries in ledger)"
  exit "$FAIL"
fi

# Parse timestamp to epoch
NOW=$(date +%s)
if date --version >/dev/null 2>&1; then
  # GNU date
  LAST_EPOCH=$(date -d "$LAST_TS" +%s 2>/dev/null || echo 0)
else
  # macOS date — handle ISO 8601 with T separator
  CLEAN_TS="${LAST_TS%%Z*}"
  CLEAN_TS="${CLEAN_TS%%+*}"
  LAST_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$CLEAN_TS" +%s 2>/dev/null || echo 0)
fi

if [[ "$LAST_EPOCH" -eq 0 ]]; then
  err "could not parse timestamp: $LAST_TS"
  exit 1
fi

DELTA_HOURS=$(( (NOW - LAST_EPOCH) / 3600 ))

if [[ "$DELTA_HOURS" -gt "$THRESHOLD_HOURS" ]]; then
  err "agent.session.closeout last run ${DELTA_HOURS}h ago (threshold: ${THRESHOLD_HOURS}h)"
fi

exit "$FAIL"

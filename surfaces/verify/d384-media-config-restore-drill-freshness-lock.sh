#!/usr/bin/env bash
# TRIAGE: D384 media-config-restore-drill-freshness-lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "$ROOT/ops/lib/spine-paths.sh"
spine_paths_init
RECEIPT_DIR="$SPINE_OUTBOX/reports/restore-drills"
RECEIPT_PATTERN="media-config-restore-drill-*.yaml"
MAX_AGE_DAYS=35

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

need() {
  command -v "$1" >/dev/null 2>&1 || fail "missing dependency: $1"
}

need yq
need find
need date

# Find latest receipt
latest_receipt=""
latest_ts=0

while IFS= read -r receipt; do
  [[ -f "$receipt" ]] || continue

  # Get generated_at timestamp
  generated_at="$(yq e -r '.generated_at // ""' "$receipt" 2>/dev/null || true)"
  [[ -n "$generated_at" && "$generated_at" != "null" ]] || continue

  # Convert to epoch (handle both formats)
  if date --version 2>&1 | grep -q GNU; then
    receipt_epoch="$(date -d "$generated_at" +%s 2>/dev/null || echo 0)"
  else
    # macOS date
    receipt_epoch="$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$generated_at" +%s 2>/dev/null || echo 0)"
  fi

  if [[ "$receipt_epoch" -gt "$latest_ts" ]]; then
    latest_ts="$receipt_epoch"
    latest_receipt="$receipt"
  fi
done < <(find "$RECEIPT_DIR" -maxdepth 1 -type f -name "$RECEIPT_PATTERN" 2>/dev/null || true)

[[ -n "$latest_receipt" ]] || fail "no media config restore drill receipt found"

# Check age
now_epoch="$(date +%s)"
age_seconds=$((now_epoch - latest_ts))
age_days=$((age_seconds / 86400))

[[ "$age_days" -le "$MAX_AGE_DAYS" ]] || fail "latest receipt is ${age_days} days old (max: ${MAX_AGE_DAYS})"

# Check result
result="$(yq e -r '.result // ""' "$latest_receipt")"
[[ "$result" == "PASS" ]] || fail "latest receipt result: $result (expected: PASS)"

# Check both stacks present
download_count="$(yq e '[.artifacts[] | select(.stack == "download-stack")] | length' "$latest_receipt")"
streaming_count="$(yq e '[.artifacts[] | select(.stack == "streaming-stack")] | length' "$latest_receipt")"

[[ "$download_count" -ge 1 ]] || fail "download-stack artifact missing from receipt"
[[ "$streaming_count" -ge 1 ]] || fail "streaming-stack artifact missing from receipt"

# Check both stacks passed
download_result="$(yq e -r '.comparison.download_stack.result // ""' "$latest_receipt")"
streaming_result="$(yq e -r '.comparison.streaming_stack.result // ""' "$latest_receipt")"

[[ "$download_result" == "PASS" ]] || fail "download-stack drill failed: $download_result"
[[ "$streaming_result" == "PASS" ]] || fail "streaming-stack drill failed: $streaming_result"

echo "PASS: media config restore drill receipt fresh (${age_days}d) and both stacks verified"

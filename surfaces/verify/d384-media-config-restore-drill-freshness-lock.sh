#!/usr/bin/env bash
# TRIAGE: D384 media-config-restore-drill-freshness-lock
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT_DEFAULT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
if CWD_ROOT="$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null)"; then
  ROOT_DEFAULT="$CWD_ROOT"
elif SCRIPT_ROOT="$(git -C "$SCRIPT_DIR/../.." rev-parse --show-toplevel 2>/dev/null)"; then
  ROOT_DEFAULT="$SCRIPT_ROOT"
fi
if [[ -n "${SPINE_ROOT:-}" && "$SPINE_ROOT" == "$ROOT_DEFAULT" ]]; then
  ROOT="$SPINE_ROOT"
else
  ROOT="$ROOT_DEFAULT"
fi
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

# Check media-home writer + playback artifacts present
media_home_count="$(yq e '[.artifacts[] | select(.stack == "media-home")] | length' "$latest_receipt")"
writer_count="$(yq e '[.artifacts[] | select(.stack == "media-home" and .role == "writer_plane")] | length' "$latest_receipt")"
playback_count="$(yq e '[.artifacts[] | select(.stack == "media-home" and .role == "playback_plane")] | length' "$latest_receipt")"

[[ "$media_home_count" -ge 2 ]] || fail "media-home artifacts missing from receipt"
[[ "$writer_count" -ge 1 ]] || fail "media-home writer_plane artifact missing from receipt"
[[ "$playback_count" -ge 1 ]] || fail "media-home playback_plane artifact missing from receipt"

# Check both planes passed
writer_result="$(yq e -r '.comparison.media_home.writer_plane.result // ""' "$latest_receipt")"
playback_result="$(yq e -r '.comparison.media_home.playback_plane.result // ""' "$latest_receipt")"

[[ "$writer_result" == "PASS" ]] || fail "media-home writer_plane drill failed: $writer_result"
[[ "$playback_result" == "PASS" ]] || fail "media-home playback_plane drill failed: $playback_result"

echo "PASS: media-home config restore drill receipt fresh (${age_days}d) and both planes verified"

#!/usr/bin/env bash
# TRIAGE: D257 media-capacity-guard-lock
# Capacity health check for the active home media plane.
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
POLICY_FILE="$ROOT/ops/bindings/infra.capacity.guard.policy.yaml"
source "$ROOT/ops/lib/runtime-paths.sh"
spine_runtime_resolve_paths

resolve_snapshot_source_path() {
  local tracked_rel="$1"
  local tracked_path="$ROOT/${tracked_rel#./}"
  local runtime_path="${SPINE_DOMAIN_STATE%/}/snapshots/$(basename "$tracked_rel")"

  if [[ -f "$runtime_path" ]]; then
    printf '%s\n' "$runtime_path"
  else
    printf '%s\n' "$tracked_path"
  fi
}

POLICY_MODE="report"

usage() {
  cat <<'USAGE'
Usage: d257-media-capacity-guard-lock.sh [--policy report|enforce]
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --policy)
      POLICY_MODE="${2:-report}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "D257 FAIL: unknown arg: $1"
      [[ "$POLICY_MODE" == "enforce" ]] && exit 1 || exit 0
      ;;
  esac
done

command -v yq >/dev/null 2>&1 || { echo "D257 FAIL: yq missing"; [[ "$POLICY_MODE" == "enforce" ]] && exit 1 || exit 0; }
command -v python3 >/dev/null 2>&1 || { echo "D257 FAIL: python3 missing"; [[ "$POLICY_MODE" == "enforce" ]] && exit 1 || exit 0; }
[[ -f "$POLICY_FILE" ]] || { echo "D257 FAIL: missing $POLICY_FILE"; [[ "$POLICY_MODE" == "enforce" ]] && exit 1 || exit 0; }

SNAPSHOT_REL="$(yq -r '.runway.snapshot_path // "ops/bindings/domains/media/media.capacity.snapshot.yaml"' "$POLICY_FILE" 2>/dev/null || echo "ops/bindings/domains/media/media.capacity.snapshot.yaml")"
SNAPSHOT_PATH="$(resolve_snapshot_source_path "$SNAPSHOT_REL")"
STORAGE_HOST_ID="$(yq -r '.target.storage_host_id // "pve"' "$POLICY_FILE" 2>/dev/null || echo pve)"
USE_SNAPSHOT_ONLY=0

if [[ "$STORAGE_HOST_ID" == "media-home" ]]; then
  USE_SNAPSHOT_ONLY=1
  SNAPSHOT_PATH="$ROOT/ops/bindings/domains/media/media.capacity.snapshot.yaml"
fi

WARN_PCT="$(yq -r '.thresholds.media_warn_pct // 80' "$POLICY_FILE" 2>/dev/null || echo 80)"
FAIL_PCT="$(yq -r '.thresholds.media_fail_pct // 85' "$POLICY_FILE" 2>/dev/null || echo 85)"
STALE_DAYS="$(yq -r '.thresholds.stale_days // 7' "$POLICY_FILE" 2>/dev/null || echo 7)"

if [[ ! -f "$SNAPSHOT_PATH" ]]; then
  echo "D257 media-capacity-guard-lock"
  echo "policy_mode: $POLICY_MODE"
  echo "snapshot_path: $SNAPSHOT_PATH"
  echo "snapshot_missing: true"
  echo "threshold_breach: no snapshot available for media capacity governance"
  echo "D257 FAIL"
  [[ "$POLICY_MODE" == "enforce" ]] && exit 1 || exit 0
fi

readarray -t SNAPSHOT_FIELDS < <(python3 - "$SNAPSHOT_PATH" <<'PY'
import datetime as dt
import math
import sys
import yaml

path = sys.argv[1]
doc = yaml.safe_load(open(path, "r", encoding="utf-8")) or {}
usage_pct = int(float(((doc.get("pool") or {}).get("usage_pct") or 0)))
runway_status = str(doc.get("runway_status") or "unknown")
generated_at = str(doc.get("generated_at_utc") or "")
days_to_fail = (doc.get("projection") or {}).get("days_to_fail")
slope = (doc.get("growth") or {}).get("slope_bytes_per_day")
sample_count = int(float((((doc.get("growth") or {}).get("slope_basis") or {}).get("sample_count") or 0)))
age_days = 0
if generated_at:
    stamp = generated_at[:-1] + "+00:00" if generated_at.endswith("Z") else generated_at
    try:
        age_days = max(0, int((dt.datetime.now(dt.timezone.utc) - dt.datetime.fromisoformat(stamp)).total_seconds() // 86400))
    except Exception:
        age_days = 0
print(usage_pct)
print(runway_status)
print("" if days_to_fail is None else days_to_fail)
print("" if slope is None else slope)
print(generated_at)
print(age_days)
print(sample_count)
PY
)

USAGE_PCT="${SNAPSHOT_FIELDS[0]:-0}"
RUNWAY_STATUS="${SNAPSHOT_FIELDS[1]:-unknown}"
DAYS_TO_FAIL="${SNAPSHOT_FIELDS[2]:-}"
SLOPE_BPD="${SNAPSHOT_FIELDS[3]:-}"
GENERATED_AT="${SNAPSHOT_FIELDS[4]:-}"
AGE_DAYS="${SNAPSHOT_FIELDS[5]:-0}"
SAMPLE_COUNT="${SNAPSHOT_FIELDS[6]:-0}"

if [[ "$USE_SNAPSHOT_ONLY" -eq 1 ]]; then
  MD_PCT="n/a"
else
  ssh_host="$(yq -r ".ssh.targets[] | select(.id == \"$STORAGE_HOST_ID\") | .host // \"\"" "$SSH_BINDING" 2>/dev/null || true)"
  ssh_user="$(yq -r ".ssh.targets[] | select(.id == \"$STORAGE_HOST_ID\") | .user // \"ubuntu\"" "$SSH_BINDING" 2>/dev/null || echo ubuntu)"
  [[ -n "$ssh_host" ]] || { echo "D257 FAIL: missing ssh target id='$STORAGE_HOST_ID'"; [[ "$POLICY_MODE" == "enforce" ]] && exit 1 || exit 0; }
  REF="$ssh_user@$ssh_host"
  SSH_OPTS=(-o ConnectTimeout=8 -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)
  raw_md="$(ssh "${SSH_OPTS[@]}" "$REF" "zpool list -Hp -o capacity 'md1400' 2>/dev/null | head -1" 2>/dev/null || true)"
  MD_PCT="$(python3 - "$raw_md" <<'PY'
import re, sys
m = re.search(r'(\d+(\.\d+)?)', (sys.argv[1] or '').strip())
print(int(float(m.group(1)))) if m else print('unknown')
PY
  )"
fi

echo "D257 media-capacity-guard-lock"
echo "policy_mode: $POLICY_MODE"
echo "snapshot_path: $SNAPSHOT_PATH"
echo "snapshot_generated_at_utc: ${GENERATED_AT:-unknown}"
echo "snapshot_age_days: ${AGE_DAYS:-0}"
echo "usage_pct: $USAGE_PCT"
echo "warn_pct: $WARN_PCT"
echo "fail_pct: $FAIL_PCT"
echo "runway_status: $RUNWAY_STATUS"
echo "days_to_fail: ${DAYS_TO_FAIL:-unknown}"
echo "slope_bytes_per_day: ${SLOPE_BPD:-unknown}"
echo "sample_count: ${SAMPLE_COUNT:-0}"
echo "storage_usage_pct: ${MD_PCT:-unknown}"

FAIL_REASONS=0

if (( USAGE_PCT >= FAIL_PCT )); then
  echo "critical_breach: media=${USAGE_PCT}% >= fail=${FAIL_PCT}%"
  FAIL_REASONS=$((FAIL_REASONS + 1))
fi

if (( USAGE_PCT >= WARN_PCT )); then
  echo "threshold_breach: media=${USAGE_PCT}% >= warn=${WARN_PCT}%"
  FAIL_REASONS=$((FAIL_REASONS + 1))
fi

python3 - "$AGE_DAYS" "$STALE_DAYS" "$SLOPE_BPD" "$USAGE_PCT" "$WARN_PCT" <<'PY'
import sys

age_days = int(float(sys.argv[1] or 0))
stale_days = int(float(sys.argv[2] or 0))
slope_raw = (sys.argv[3] or "").strip()
usage_pct = int(float(sys.argv[4] or 0))
warn_pct = int(float(sys.argv[5] or 0))

stale = usage_pct >= warn_pct and age_days >= stale_days
downward = False
if slope_raw:
    try:
        downward = float(slope_raw) < 0
    except Exception:
        downward = False
if stale and not downward:
    print("stale_no_trend: warn-or-higher media snapshot is stale and does not show downward usage trend")
PY

if python3 - "$AGE_DAYS" "$STALE_DAYS" "$SLOPE_BPD" "$USAGE_PCT" "$WARN_PCT" <<'PY'
import sys

age_days = int(float(sys.argv[1] or 0))
stale_days = int(float(sys.argv[2] or 0))
slope_raw = (sys.argv[3] or "").strip()
usage_pct = int(float(sys.argv[4] or 0))
warn_pct = int(float(sys.argv[5] or 0))

stale = usage_pct >= warn_pct and age_days >= stale_days
downward = False
if slope_raw:
    try:
        downward = float(slope_raw) < 0
    except Exception:
        downward = False
sys.exit(0 if stale and not downward else 1)
PY
then
  FAIL_REASONS=$((FAIL_REASONS + 1))
fi

if (( FAIL_REASONS == 0 )); then
  echo "D257 PASS"
  exit 0
fi

echo "D257 FAIL"
[[ "$POLICY_MODE" == "enforce" ]] && exit 1 || exit 0

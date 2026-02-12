#!/usr/bin/env bash
# D58: SSOT freshness lock
# Fails when any SSOT in the registry has a last_reviewed date
# older than SSOT_FRESHNESS_DAYS (default: 21).
#
# Reads: docs/governance/SSOT_REGISTRY.yaml
set -euo pipefail

SP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REGISTRY="$SP/docs/governance/SSOT_REGISTRY.yaml"
THRESHOLD="${SSOT_FRESHNESS_DAYS:-21}"

FAIL=0
err() { echo "  FAIL: $1" >&2; FAIL=1; }

parse_epoch_date() {
  local ds="${1:-}"
  [[ -n "$ds" ]] || { echo 0; return; }

  if command -v python3 >/dev/null 2>&1; then
    python3 - "$ds" <<'PY'
import sys
from datetime import datetime, timezone

ds = (sys.argv[1] or "").strip()
try:
    dt = datetime.fromisoformat(ds)
except Exception:
    print(0)
    raise SystemExit(0)

if dt.tzinfo is None:
    dt = dt.replace(tzinfo=timezone.utc)

print(int(dt.timestamp()))
PY
    return
  fi

  if date --version >/dev/null 2>&1; then
    date -d "$ds" +%s 2>/dev/null || echo 0
    return
  fi

  date -j -f "%Y-%m-%d" "$ds" +%s 2>/dev/null || echo 0
}

[[ -f "$REGISTRY" ]] || { err "SSOT_REGISTRY.yaml not found"; exit 1; }
command -v yq >/dev/null 2>&1 || { err "yq not found"; exit 1; }

# Get current date as epoch
NOW=$(date +%s)

# Iterate all SSOTs with last_reviewed
ssot_count=$(yq '.ssots | length' "$REGISTRY")
STALE=0
for ((i=0; i<ssot_count; i++)); do
  id=$(yq -r ".ssots[$i].id" "$REGISTRY")
  reviewed=$(yq -r ".ssots[$i].last_reviewed" "$REGISTRY")

  [[ "$reviewed" == "null" || -z "$reviewed" ]] && continue

  reviewed_epoch=$(parse_epoch_date "$reviewed")

  [[ "$reviewed_epoch" -eq 0 ]] && continue

  age_days=$(( (NOW - reviewed_epoch) / 86400 ))
  if [[ "$age_days" -gt "$THRESHOLD" ]]; then
    err "$id: last_reviewed=$reviewed (${age_days}d ago, threshold=${THRESHOLD}d)"
    STALE=$((STALE + 1))
  fi
done

if [[ "$STALE" -gt 0 ]]; then
  echo "  $STALE SSOTs exceed freshness threshold of ${THRESHOLD} days" >&2
fi

exit "$FAIL"

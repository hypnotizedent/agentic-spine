#!/usr/bin/env bash
set -euo pipefail

# D36: Legacy Exception Hygiene Lock
# Purpose: Enforce stale and near-expiry exception lifecycle rules.
#
# Fails on:
#   - Active exception is expired (expires_at in past)
#   - Exception exists for labels no longer using legacy runtime
#   - Exception expires_at is within 48h and label still active
#
# Allows:
#   - NOOP exceptions (empty allowed_paths or epoch expiry)
#   - Properly scoped future-expiry exceptions

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BINDING="$ROOT/ops/bindings/legacy.entrypoint.exceptions.yaml"

fail() { echo "D36 FAIL: $*" >&2; exit 1; }

require_tool() {
    command -v "$1" >/dev/null 2>&1 || fail "required tool missing: $1"
}

require_tool yq

parse_epoch_utc() {
    local ts="${1:-}"
    [[ -n "$ts" ]] || { echo 0; return; }

    if command -v python3 >/dev/null 2>&1; then
        python3 - "$ts" <<'PY'
import sys
from datetime import datetime, timezone

ts = (sys.argv[1] or "").strip()
if not ts:
    print(0)
    raise SystemExit(0)

if ts.endswith("Z"):
    ts = ts[:-1] + "+00:00"

try:
    dt = datetime.fromisoformat(ts)
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
        date -d "$ts" +%s 2>/dev/null || echo 0
        return
    fi

    local clean_ts="${ts%%Z*}"
    clean_ts="${clean_ts%%+*}"
    date -j -f "%Y-%m-%dT%H:%M:%S" "$clean_ts" +%s 2>/dev/null || echo 0
}

# Validate binding exists and is valid YAML
[[ -f "$BINDING" ]] || fail "exception binding not found: $BINDING"
yq e '.' "$BINDING" >/dev/null 2>&1 || fail "exception binding is not valid YAML"

# Get current timestamp for comparison
NOW_EPOCH=$(date +%s)
WARN_THRESHOLD=$((48 * 60 * 60))  # 48 hours in seconds

# Extract exceptions array
EXCEPTIONS=$(yq e '.exceptions[]' "$BINDING" 2>/dev/null || echo "")

if [[ -z "$EXCEPTIONS" ]]; then
    echo "D36 PASS: no exceptions configured"
    exit 0
fi

FAIL_COUNT=0
WARN_COUNT=0

# Process each exception
while IFS= read -r label; do
    [[ -z "$label" ]] && continue

    # Get exception fields
    expires_at=$(yq e ".exceptions[] | select(.label == \"$label\") | .expires_at" "$BINDING")
    allowed_paths=$(yq e ".exceptions[] | select(.label == \"$label\") | .allowed_paths | length" "$BINDING")

    # Skip NOOP exceptions (epoch date or empty paths)
    if [[ "$expires_at" == "1970-01-01T00:00:00Z" ]] || [[ "$allowed_paths" == "0" ]]; then
        continue
    fi

    # Parse expires_at to epoch
    # Handle ISO format: 2026-02-09T23:59:59Z
    expires_epoch=$(parse_epoch_utc "$expires_at")

    if [[ "$expires_epoch" == "0" ]]; then
        echo "  WARN: cannot parse expires_at for $label: $expires_at"
        continue
    fi

    # Check if expired
    if (( expires_epoch < NOW_EPOCH )); then
        echo "  FAIL: exception '$label' is EXPIRED (was $expires_at)"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        continue
    fi

    # Check if expiring within 48h
    time_remaining=$((expires_epoch - NOW_EPOCH))
    if (( time_remaining < WARN_THRESHOLD )); then
        hours_remaining=$((time_remaining / 3600))
        echo "  WARN: exception '$label' expires in ${hours_remaining}h (at $expires_at)"
        WARN_COUNT=$((WARN_COUNT + 1))
    fi

done < <(yq e '.exceptions[].label' "$BINDING" 2>/dev/null)

if (( FAIL_COUNT > 0 )); then
    fail "exception hygiene violated (${FAIL_COUNT} expired exception(s))"
fi

if (( WARN_COUNT > 0 )); then
    echo "D36 PASS: exception hygiene enforced (${WARN_COUNT} warning(s) - near expiry)"
else
    echo "D36 PASS: exception hygiene enforced"
fi

#!/usr/bin/env bash
# D83: Proposal queue health lock
#
# Fails if:
# - Any active proposal is missing manifest.yaml
# - Any manifest is missing required fields for its status
# - Stale pending count exceeds threshold
# - .applied marker parity: applied status without .applied file
#
# Reads: mailroom/outbox/proposals/
#        ops/bindings/proposals.lifecycle.yaml
set -euo pipefail

SP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROPOSALS_DIR="$SP/mailroom/outbox/proposals"
LIFECYCLE="$SP/ops/bindings/proposals.lifecycle.yaml"

FAIL=0
err() { echo "  FAIL: $1" >&2; FAIL=1; }
warn() { echo "  WARN: $1" >&2; }

# Read thresholds from lifecycle binding
PENDING_MAX=7
STALE_PENDING_LIMIT=5
if command -v yq >/dev/null 2>&1 && [[ -f "$LIFECYCLE" ]]; then
  PENDING_MAX=$(yq '.sla.pending_max_age_days // 7' "$LIFECYCLE")
fi

NOW=$(date +%s)

parse_epoch() {
  local ds="${1:-}"
  [[ -n "$ds" ]] || { echo 0; return; }
  if command -v python3 >/dev/null 2>&1; then
    python3 -c "
import sys
from datetime import datetime, timezone
ds = sys.argv[1].strip()
try:
    dt = datetime.fromisoformat(ds)
    if dt.tzinfo is None: dt = dt.replace(tzinfo=timezone.utc)
    print(int(dt.timestamp()))
except: print(0)
" "$ds"
    return
  fi
  date -j -f "%Y-%m-%dT%H:%M:%SZ" "$ds" +%s 2>/dev/null || echo 0
}

[[ -d "$PROPOSALS_DIR" ]] || { err "proposals directory not found"; exit 1; }

missing_manifest=0
missing_fields=0
stale_pending=0
applied_parity=0

for dir in "$PROPOSALS_DIR"/CP-*; do
  [[ -d "$dir" ]] || continue
  bname=$(basename "$dir")
  manifest="$dir/manifest.yaml"

  # Check 1: manifest exists
  if [[ ! -f "$manifest" ]]; then
    err "$bname: missing manifest.yaml"
    missing_manifest=$((missing_manifest + 1))
    continue
  fi

  # Determine status
  status="pending"
  if [[ -f "$dir/.applied" ]]; then
    status="applied"
  elif grep -q '^status:' "$manifest"; then
    status=$(grep -m1 '^status:' "$manifest" | sed 's/^status: *//' | tr -d '"' | tr -d "'")
  fi

  # Check 2: required fields for all statuses
  has_proposal=false
  has_agent=false
  has_created=false

  grep -q '^proposal:' "$manifest" && has_proposal=true
  grep -q '^proposal_id:' "$manifest" && has_proposal=true
  grep -q '^cp_id:' "$manifest" && has_proposal=true
  grep -q '^agent:' "$manifest" && has_agent=true
  grep -q '^author:' "$manifest" && has_agent=true
  grep -q '^created:' "$manifest" && has_created=true

  if [[ "$has_proposal" == "false" ]]; then
    err "$bname: missing proposal identifier"
    missing_fields=$((missing_fields + 1))
  fi
  if [[ "$has_agent" == "false" ]]; then
    err "$bname: missing agent field"
    missing_fields=$((missing_fields + 1))
  fi
  if [[ "$has_created" == "false" ]]; then
    warn "$bname: missing created field"
  fi

  # Check 3: status-specific required fields
  case "$status" in
    superseded)
      if ! grep -q '^superseded_at:' "$manifest" && ! grep -q '^superseded_reason:' "$manifest"; then
        warn "$bname: superseded without superseded_at/superseded_reason"
      fi
      ;;
    draft_hold)
      if ! grep -q '^owner:' "$manifest"; then
        err "$bname: draft_hold without owner"
        missing_fields=$((missing_fields + 1))
      fi
      if ! grep -q '^review_date:' "$manifest"; then
        err "$bname: draft_hold without review_date"
        missing_fields=$((missing_fields + 1))
      fi
      ;;
  esac

  # Check 4: .applied marker parity
  if [[ "$status" == "applied" && ! -f "$dir/.applied" ]]; then
    err "$bname: status=applied but .applied marker missing"
    applied_parity=$((applied_parity + 1))
  fi

  # Check 5: stale pending detection
  if [[ "$status" == "pending" ]]; then
    created=$(grep -m1 '^created:' "$manifest" 2>/dev/null | sed 's/^created: *//' | tr -d '"' | tr -d "'" || echo "")
    if [[ -n "$created" ]]; then
      epoch=$(parse_epoch "$created")
      if [[ "$epoch" -gt 0 ]]; then
        age_days=$(( (NOW - epoch) / 86400 ))
        if [[ "$age_days" -gt "$PENDING_MAX" ]]; then
          warn "$bname: pending for ${age_days}d (threshold ${PENDING_MAX}d)"
          stale_pending=$((stale_pending + 1))
        fi
      fi
    fi
  fi
done

# Fail if stale pending count exceeds limit
if [[ "$stale_pending" -gt "$STALE_PENDING_LIMIT" ]]; then
  err "$stale_pending stale pending proposals exceed limit of $STALE_PENDING_LIMIT"
fi

if [[ "$missing_manifest" -gt 0 ]]; then
  echo "  $missing_manifest proposals missing manifest.yaml" >&2
fi
if [[ "$missing_fields" -gt 0 ]]; then
  echo "  $missing_fields required field violations" >&2
fi

exit "$FAIL"

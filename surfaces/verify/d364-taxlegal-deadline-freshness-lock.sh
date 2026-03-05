#!/usr/bin/env bash
# TRIAGE: Deadline tracking is stale or missing required fields. Refresh deadlines.yaml (must be within 24h TTL). Ensure every entry has deadline_id, case_id, due_date, risk_level. Past-due entries need status: overdue or status: closed.
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

HITS=0
err() {
  echo "  FAIL: $*" >&2
  HITS=$((HITS + 1))
}

CASE_BASE="$ROOT/mailroom/state/cases/tax-legal"
DEADLINES_FILE="$CASE_BASE/deadlines.yaml"

# If no case directories exist, nothing to check
if [[ ! -d "$CASE_BASE" ]]; then
  echo "D362 PASS: taxlegal-deadline-freshness-lock (no case directories exist)"
  exit 0
fi

# Check if any case subdirectories actually exist
CASE_COUNT=0
for d in "$CASE_BASE"/*/; do
  [[ -d "$d" ]] && CASE_COUNT=$((CASE_COUNT + 1))
done

if [[ "$CASE_COUNT" -eq 0 ]]; then
  echo "D362 PASS: taxlegal-deadline-freshness-lock (no case subdirectories exist)"
  exit 0
fi

# Need yq for YAML parsing
command -v yq >/dev/null 2>&1 || { err "missing dependency: yq"; echo "D362 FAIL: $HITS violation(s)"; exit 1; }

# ── Check 1: If cases exist with deadline references but no deadlines.yaml, FAIL ──
if [[ ! -f "$DEADLINES_FILE" ]]; then
  # Check if any case has a checklist.yaml mentioning deadlines
  HAS_DEADLINE_REFS=false
  while IFS= read -r -d '' checklist; do
    if grep -qi 'deadline' "$checklist" 2>/dev/null; then
      HAS_DEADLINE_REFS=true
      break
    fi
  done < <(find "$CASE_BASE" -type f -name 'checklist.yaml' -print0 2>/dev/null)

  if [[ "$HAS_DEADLINE_REFS" == "true" ]]; then
    err "cases reference deadlines in checklist.yaml but $DEADLINES_FILE does not exist"
    echo "D362 FAIL: $HITS violation(s)"
    exit 1
  fi

  echo "D362 PASS: taxlegal-deadline-freshness-lock (no deadlines.yaml and no deadline references)"
  exit 0
fi

# ── Check 2: Freshness — last_refreshed within 24 hours ──
LAST_REFRESHED="$(yq e -r '.last_refreshed // ""' "$DEADLINES_FILE" 2>/dev/null)"
if [[ -z "$LAST_REFRESHED" || "$LAST_REFRESHED" == "null" ]]; then
  err "deadlines.yaml missing last_refreshed field"
else
  # Parse the timestamp and compute age in hours
  REFRESH_EPOCH="$(TZ=UTC date -jf '%Y-%m-%dT%H:%M:%S' "${LAST_REFRESHED%%[+-]*}" '+%s' 2>/dev/null || \
                   TZ=UTC date -jf '%Y-%m-%d %H:%M:%S' "${LAST_REFRESHED%%[+-]*}" '+%s' 2>/dev/null || \
                   TZ=UTC date -jf '%Y-%m-%d' "${LAST_REFRESHED}" '+%s' 2>/dev/null || echo "")"
  if [[ -z "$REFRESH_EPOCH" ]]; then
    err "deadlines.yaml last_refreshed has unparseable timestamp: $LAST_REFRESHED"
  else
    NOW_EPOCH="$(date '+%s')"
    AGE_HOURS=$(( (NOW_EPOCH - REFRESH_EPOCH) / 3600 ))
    if [[ "$AGE_HOURS" -gt 24 ]]; then
      err "deadlines.yaml is stale: last_refreshed $AGE_HOURS hours ago (TTL: 24h)"
    fi
  fi
fi

# ── Check 3: Required fields on every deadline entry ──
REQUIRED_FIELDS=("deadline_id" "case_id" "due_date" "risk_level")
DEADLINE_COUNT="$(yq e '.deadlines | length' "$DEADLINES_FILE" 2>/dev/null || echo "0")"

if [[ "$DEADLINE_COUNT" -gt 0 ]]; then
  for i in $(seq 0 $((DEADLINE_COUNT - 1))); do
    for field in "${REQUIRED_FIELDS[@]}"; do
      val="$(yq e -r ".deadlines[$i].$field // \"\"" "$DEADLINES_FILE" 2>/dev/null)"
      if [[ -z "$val" || "$val" == "null" ]]; then
        dl_id="$(yq e -r ".deadlines[$i].deadline_id // \"entry-$i\"" "$DEADLINES_FILE" 2>/dev/null)"
        err "deadline '$dl_id' missing required field: $field"
      fi
    done
  done

  # ── Check 4: Past-due deadlines must have status: overdue or status: closed ──
  TODAY="$(date '+%Y-%m-%d')"
  for i in $(seq 0 $((DEADLINE_COUNT - 1))); do
    due_date="$(yq e -r ".deadlines[$i].due_date // \"\"" "$DEADLINES_FILE" 2>/dev/null)"
    [[ -z "$due_date" || "$due_date" == "null" ]] && continue

    if [[ "$due_date" < "$TODAY" ]]; then
      status="$(yq e -r ".deadlines[$i].status // \"\"" "$DEADLINES_FILE" 2>/dev/null)"
      if [[ "$status" != "overdue" && "$status" != "closed" ]]; then
        dl_id="$(yq e -r ".deadlines[$i].deadline_id // \"entry-$i\"" "$DEADLINES_FILE" 2>/dev/null)"
        err "deadline '$dl_id' is past due ($due_date) but status is '$status' (expected: overdue or closed)"
      fi
    fi
  done
fi

# ── Result ──
if [[ "$HITS" -gt 0 ]]; then
  echo "D362 FAIL: $HITS violation(s)"
  exit 1
fi

echo "D362 PASS: taxlegal-deadline-freshness-lock ($DEADLINE_COUNT deadlines verified, freshness OK)"
exit 0

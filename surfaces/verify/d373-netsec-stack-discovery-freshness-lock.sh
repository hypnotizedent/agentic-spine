#!/usr/bin/env bash
# TRIAGE: enforce stack discovery knowledge base freshness and source success rate.
# D373: netsec-stack-discovery-freshness-lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
DB_PATH="$ROOT/ops/runtime/stack-discovery.db"
MAX_STALENESS_HOURS=36
MIN_SUCCESS_PCT=80

PASS_COUNT=0
FAIL_COUNT=0
TOTAL=0

check() {
  local label="$1"
  local result="$2"
  TOTAL=$((TOTAL + 1))
  if [[ "$result" == "PASS" ]]; then
    echo "  PASS: $label"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  FAIL: $label"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

echo "D373: netsec-stack-discovery-freshness-lock"
echo

# ── 1. SQLite DB exists ──────────────────────────────────────────────────────
if [[ -f "$DB_PATH" ]]; then
  check "stack-discovery.db exists" "PASS"
else
  check "stack-discovery.db exists" "FAIL"
  echo
  echo "summary: 0/${TOTAL} checks passed (DB missing — run stack.discovery.refresh)"
  echo "status: FAIL"
  exit 1
fi

command -v sqlite3 >/dev/null 2>&1 || { echo "D373 FAIL: missing dependency: sqlite3" >&2; exit 1; }

# ── 2. DB has tools table with data ──────────────────────────────────────────
TOOL_COUNT="$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM tools;" 2>/dev/null || echo 0)"
if [[ "$TOOL_COUNT" -gt 0 ]]; then
  check "tools table has data (count=$TOOL_COUNT)" "PASS"
else
  check "tools table has data (count=$TOOL_COUNT)" "FAIL"
fi

# ── 3. Most recent refresh is within staleness window ────────────────────────
LATEST_REFRESH="$(sqlite3 "$DB_PATH" "SELECT MAX(refreshed_at) FROM refresh_log;" 2>/dev/null || echo "")"
if [[ -n "$LATEST_REFRESH" && "$LATEST_REFRESH" != "null" && "$LATEST_REFRESH" != "" ]]; then
  # macOS date: parse ISO 8601 timestamp
  if date --version >/dev/null 2>&1; then
    # GNU date
    REFRESH_EPOCH="$(date -d "$LATEST_REFRESH" +%s 2>/dev/null || echo 0)"
  else
    # macOS date
    REFRESH_EPOCH="$(date -jf "%Y-%m-%dT%H:%M:%SZ" "$LATEST_REFRESH" +%s 2>/dev/null || echo 0)"
  fi
  NOW_EPOCH="$(date +%s)"
  AGE_HOURS=$(( (NOW_EPOCH - REFRESH_EPOCH) / 3600 ))

  if [[ "$AGE_HOURS" -le "$MAX_STALENESS_HOURS" ]]; then
    check "refresh freshness (${AGE_HOURS}h <= ${MAX_STALENESS_HOURS}h)" "PASS"
  else
    check "refresh freshness (${AGE_HOURS}h > ${MAX_STALENESS_HOURS}h)" "FAIL"
  fi
else
  check "refresh freshness (no refresh_log entries)" "FAIL"
fi

# ── 4. Source success rate >= threshold ──────────────────────────────────────
# Get the most recent refresh batch (all entries with the latest timestamp)
if [[ -n "$LATEST_REFRESH" && "$LATEST_REFRESH" != "null" && "$LATEST_REFRESH" != "" ]]; then
  TOTAL_SOURCES="$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM refresh_log WHERE refreshed_at = '$LATEST_REFRESH';" 2>/dev/null || echo 0)"
  OK_SOURCES="$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM refresh_log WHERE refreshed_at = '$LATEST_REFRESH' AND status = 'ok';" 2>/dev/null || echo 0)"

  if [[ "$TOTAL_SOURCES" -gt 0 ]]; then
    SUCCESS_PCT=$(( (OK_SOURCES * 100) / TOTAL_SOURCES ))
    if [[ "$SUCCESS_PCT" -ge "$MIN_SUCCESS_PCT" ]]; then
      check "source success rate (${SUCCESS_PCT}% >= ${MIN_SUCCESS_PCT}%)" "PASS"
    else
      check "source success rate (${SUCCESS_PCT}% < ${MIN_SUCCESS_PCT}%)" "FAIL"
    fi
  else
    check "source success rate (no sources in latest refresh)" "FAIL"
  fi
else
  check "source success rate (no refresh data)" "FAIL"
fi

# ── 5. DB integrity check ───────────────────────────────────────────────────
INTEGRITY="$(sqlite3 "$DB_PATH" "PRAGMA integrity_check;" 2>/dev/null || echo "error")"
if [[ "$INTEGRITY" == "ok" ]]; then
  check "SQLite integrity check" "PASS"
else
  check "SQLite integrity check ($INTEGRITY)" "FAIL"
fi

# ── summary ──────────────────────────────────────────────────────────────────
echo
echo "summary: ${PASS_COUNT}/${TOTAL} checks passed"
if [[ $FAIL_COUNT -gt 0 ]]; then
  echo "status: FAIL"
  exit 1
fi
echo "status: PASS"

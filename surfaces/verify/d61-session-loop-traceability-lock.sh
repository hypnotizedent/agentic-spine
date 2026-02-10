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
LOOPS_LEDGER="$SP/mailroom/state/open_loops.jsonl"
LOOP_TTL_HIGH_HOURS="${LOOP_TTL_HIGH_HOURS:-48}"

FAIL=0
err() { echo "  FAIL: $1" >&2; FAIL=1; }
warn() { echo "  WARN: $1" >&2; }

# ledger.csv is runtime state. In CI or fresh clones it may be absent; treat as
# "unavailable" and skip the closeout freshness check (loop TTL can still run).
SKIP_CLOSEOUT_CHECK=0
if [[ "${CI:-}" == "true" || "${CI:-}" == "1" || -n "${GITHUB_ACTIONS:-}" ]]; then
  warn "CI environment detected (skipping closeout freshness check)"
  SKIP_CLOSEOUT_CHECK=1
fi
if [[ ! -f "$LEDGER" ]]; then
  warn "ledger.csv not found (skipping closeout freshness check)"
  SKIP_CLOSEOUT_CHECK=1
fi

# Find the most recent agent.session.closeout entry with status=done
# Ledger columns: run_id,created_at,started_at,finished_at,status,prompt_file,result_file,error,context_used
# Capability entries use prompt_file=agent.session.closeout

LAST_TS=""
if [[ "$SKIP_CLOSEOUT_CHECK" == "0" ]]; then
  while IFS=, read -r run_id created_at started_at finished_at status prompt_file _rest; do
    if [[ "$prompt_file" == "agent.session.closeout" && "$status" == "done" && -n "$finished_at" ]]; then
      LAST_TS="$finished_at"
    fi
  done < <(tail -n +2 "$LEDGER" 2>/dev/null || true)

  if [[ -z "$LAST_TS" ]]; then
    err "agent.session.closeout has never been run (0 done entries in ledger)"
    exit "$FAIL"
  fi
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

# Loop TTL/SLA: fail if any open high-severity loop has no ledger activity within threshold.
#
# Activity model (locked):
# - open_loops.jsonl is append-only
# - reduce to latest record per loop_id (latest wins by file order)
# - use latest record created_at as "last activity"
if [[ -f "$LOOPS_LEDGER" ]]; then
  if command -v python3 >/dev/null 2>&1; then
    if ! python3 - "$LOOPS_LEDGER" "$LOOP_TTL_HIGH_HOURS" <<'PY'
import json
import sys
from datetime import datetime, timezone

path = sys.argv[1]
threshold_hours = int(sys.argv[2])

def loop_key(row):
    return row.get("loop_id") or row.get("id")

def parse_ts(ts):
    if not ts:
        return None
    ts = ts.strip()
    if ts.endswith("Z"):
        ts = ts[:-1] + "+00:00"
    try:
        return datetime.fromisoformat(ts)
    except Exception:
        return None

rows = []
with open(path, "r", encoding="utf-8") as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            rows.append(json.loads(line))
        except json.JSONDecodeError:
            continue

state = {}
for row in rows:
    lid = loop_key(row)
    if not lid:
        continue
    cur = state.get(lid, {"loop_id": lid})
    if row.get("action") == "close":
        cur["status"] = "closed"
    for k, v in row.items():
        if k in ("id", "action"):
            continue
        cur[k] = v
    cur["loop_id"] = lid
    state[lid] = cur

now = datetime.now(timezone.utc)
stale = []
for loop in state.values():
    if loop.get("status") != "open":
        continue
    if (loop.get("severity") or "").lower() != "high":
        continue
    created_at = parse_ts(loop.get("created_at"))
    if not created_at:
        continue
    if created_at.tzinfo is None:
        created_at = created_at.replace(tzinfo=timezone.utc)
    age_h = int((now - created_at).total_seconds() // 3600)
    if age_h > threshold_hours:
        stale.append((age_h, loop.get("loop_id"), loop.get("owner") or "unassigned", loop.get("created_at")))

stale.sort(reverse=True)
if stale:
    for age_h, loop_id, owner, created_at in stale:
        print(f"  FAIL: high loop stale >{threshold_hours}h: {loop_id} owner={owner} age={age_h}h created_at={created_at}", file=sys.stderr)
    sys.exit(1)
sys.exit(0)
PY
    then
      FAIL=1
    fi
  else
    err "python3 missing (cannot enforce loop TTL)"
  fi
fi

exit "$FAIL"

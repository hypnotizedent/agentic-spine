#!/usr/bin/env bash
# D61: Session-loop traceability lock
# Fails when agent.session.closeout has not been run within
# SESSION_CLOSEOUT_FRESHNESS_HOURS (default: 48).
#
# Reads: mailroom/state/ledger.csv, mailroom/state/loop-scopes/*.scope.md
set -euo pipefail

SP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LEDGER="$SP/mailroom/state/ledger.csv"
THRESHOLD_HOURS="${SESSION_CLOSEOUT_FRESHNESS_HOURS:-48}"
SCOPES_DIR="$SP/mailroom/state/loop-scopes"
LOOP_TTL_HIGH_HOURS="${LOOP_TTL_HIGH_HOURS:-48}"

FAIL=0
err() { echo "  FAIL: $1" >&2; FAIL=1; }
warn() { echo "  WARN: $1" >&2; }

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

NOW=$(date +%s)
if [[ "$SKIP_CLOSEOUT_CHECK" == "0" ]]; then
  LAST_EPOCH=$(parse_epoch_utc "$LAST_TS")
  if [[ "$LAST_EPOCH" -eq 0 ]]; then
    err "could not parse timestamp: $LAST_TS"
    exit 1
  fi

  DELTA_HOURS=$(( (NOW - LAST_EPOCH) / 3600 ))

  if [[ "$DELTA_HOURS" -gt "$THRESHOLD_HOURS" ]]; then
    err "agent.session.closeout last run ${DELTA_HOURS}h ago (threshold: ${THRESHOLD_HOURS}h)"
  fi
fi

# Loop TTL/SLA: fail if any open high-severity loop exceeds age threshold.
# Reads scope file frontmatter (status, severity, created date).
if [[ -d "$SCOPES_DIR" ]]; then
  if command -v python3 >/dev/null 2>&1; then
    if ! python3 - "$SCOPES_DIR" "$LOOP_TTL_HIGH_HOURS" <<'PY'
import sys
from datetime import datetime, timezone
from pathlib import Path

scopes_dir = sys.argv[1]
threshold_hours = int(sys.argv[2])

def parse_frontmatter(path):
    fm = {}
    in_fm = False
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            stripped = line.strip()
            if stripped == "---":
                if in_fm:
                    break
                in_fm = True
                continue
            if in_fm and ":" in stripped:
                key, _, val = stripped.partition(":")
                fm[key.strip()] = val.strip().strip('"').strip("'")
    return fm

def parse_ts(ts):
    if not ts:
        return None
    ts = ts.strip()
    # Handle date-only (YYYY-MM-DD)
    if len(ts) == 10:
        try:
            return datetime.fromisoformat(ts + "T00:00:00+00:00")
        except Exception:
            return None
    if ts.endswith("Z"):
        ts = ts[:-1] + "+00:00"
    try:
        return datetime.fromisoformat(ts)
    except Exception:
        return None

now = datetime.now(timezone.utc)
stale = []

for scope_file in sorted(Path(scopes_dir).glob("*.scope.md")):
    fm = parse_frontmatter(scope_file)
    status = fm.get("status", "")
    if status not in ("active", "draft", "open"):
        continue
    severity = (fm.get("severity") or "").lower()
    if severity not in ("critical", "high"):
        continue
    created = parse_ts(fm.get("created", fm.get("created_at", "")))
    if not created:
        continue
    blocked_by = (fm.get("blocked_by") or "").strip()
    if blocked_by and blocked_by.lower() not in ("null", "none", "n/a"):
        # Blocked loops are allowed to exceed the high-loop TTL; they are not actionable.
        continue
    if created.tzinfo is None:
        created = created.replace(tzinfo=timezone.utc)
    age_h = int((now - created).total_seconds() // 3600)
    if age_h > threshold_hours:
        owner = fm.get("owner", "unassigned")
        loop_id = fm.get("loop_id", scope_file.stem)
        stale.append((age_h, loop_id, owner, fm.get("created", "")))

stale.sort(reverse=True)
if stale:
    for age_h, loop_id, owner, created_at in stale:
        print(f"  FAIL: high loop stale >{threshold_hours}h: {loop_id} owner={owner} age={age_h}h created={created_at}", file=sys.stderr)
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

#!/usr/bin/env bash
# TRIAGE: Verify projection reconcile pipeline health: header sync, surface sync, and runtime evidence.
# D309: projection-reconcile-health-lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"

fail() { echo "D309 FAIL: $*" >&2; exit 1; }

errors=0

# ── Check 1: gen-gate-registry-header.sh --check ──
GEN_HEADER="$ROOT/bin/generators/gen-gate-registry-header.sh"
if [[ ! -x "$GEN_HEADER" ]]; then
  echo "D309 HIT: missing generator: $GEN_HEADER" >&2
  errors=$((errors + 1))
else
  if ! "$GEN_HEADER" --check >/dev/null 2>&1; then
    echo "D309 HIT: gate registry header stale" >&2
    errors=$((errors + 1))
  fi
fi

# ── Check 2: docs.projection.verify succeeds ──
VERIFY="$ROOT/ops/plugins/docs/bin/docs-projection-verify"
if [[ ! -x "$VERIFY" ]]; then
  echo "D309 HIT: missing verifier: $VERIFY" >&2
  errors=$((errors + 1))
else
  if ! "$VERIFY" >/dev/null 2>&1; then
    echo "D309 HIT: entry-surface projection drift detected" >&2
    errors=$((errors + 1))
  fi
fi

# ── Check 3: runtime evidence within 4h ──
LOG_FILE="$ROOT/mailroom/logs/runtime-jobs.ndjson"
if [[ ! -f "$LOG_FILE" ]]; then
  echo "D309 SKIP: no runtime-jobs log yet (fresh install)" >&2
else
  now_epoch="$(date +%s)"
  threshold=$((now_epoch - 14400))  # 4 hours

  # Find most recent projection-reconcile entry
  last_entry="$(grep '"projection-reconcile:' "$LOG_FILE" 2>/dev/null | tail -1 || true)"
  if [[ -z "$last_entry" ]]; then
    echo "D309 HIT: no projection-reconcile runtime evidence found" >&2
    errors=$((errors + 1))
  else
    last_ts="$(echo "$last_entry" | python3 -c "
import sys, json
from datetime import datetime, timezone
entry = json.loads(sys.stdin.readline())
ts = entry.get('started_at', '')
if ts.endswith('Z'):
    ts = ts[:-1] + '+00:00'
dt = datetime.fromisoformat(ts)
if dt.tzinfo is None:
    dt = dt.replace(tzinfo=timezone.utc)
print(int(dt.timestamp()))
" 2>/dev/null || echo 0)"
    if [[ "$last_ts" =~ ^[0-9]+$ ]] && (( last_ts < threshold )); then
      echo "D309 HIT: projection-reconcile last ran >4h ago" >&2
      errors=$((errors + 1))
    fi
  fi
fi

if (( errors > 0 )); then
  fail "$errors projection-reconcile health violation(s)"
fi

echo "D309 PASS: projection-reconcile health checks passed"

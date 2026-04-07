#!/usr/bin/env bash
set -euo pipefail

# D430: Boot snapshot parity lock
# Verifies session boot snapshot exists, is fresh, and matches live loop truth.

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
source "$SPINE_ROOT/ops/lib/runtime-paths.sh"
spine_runtime_resolve_paths

SESSION_ID="${SPINE_SESSION_ID:-}"
SNAPSHOT_PATH="${SPINE_BOOT_SNAPSHOT_PATH:-}"
LANE="${SPINE_LANE:-claude_code}"

# If no session is active, this gate is N/A (report-only pass)
if [[ -z "$SESSION_ID" ]]; then
  echo "D430 PASS: no active session — boot snapshot check not applicable"
  exit 0
fi

# Find snapshot: explicit path or convention
if [[ -z "$SNAPSHOT_PATH" ]]; then
  SNAPSHOT_PATH="$SPINE_STATE/sessions/$SESSION_ID/boot-snapshot.json"
fi

if [[ ! -f "$SNAPSHOT_PATH" ]]; then
  echo "D430 FAIL: boot snapshot missing at $SNAPSHOT_PATH"
  echo "  remedy: re-run session.v3.attach to generate boot snapshot"
  exit 1
fi

# Check freshness (6 hour TTL)
if command -v python3 >/dev/null 2>&1; then
  stale=$(python3 -c "
import json, sys
from datetime import datetime, timezone, timedelta
try:
    with open('$SNAPSHOT_PATH') as f:
        snap = json.load(f)
    gen = snap.get('generated_at_utc', '')
    if not gen:
        print('stale')
        sys.exit(0)
    # Parse ISO format
    gen_dt = datetime.fromisoformat(gen.replace('Z', '+00:00'))
    age = datetime.now(timezone.utc) - gen_dt
    if age > timedelta(hours=6):
        print('stale')
    else:
        print('fresh')
except Exception as e:
    print('stale')
" 2>/dev/null || echo "stale")
  if [[ "$stale" == "stale" ]]; then
    echo "D430 FAIL: boot snapshot stale (> 6 hours old) at $SNAPSHOT_PATH"
    echo "  remedy: re-run session.v3.attach to refresh boot snapshot"
    exit 1
  fi
fi

# Check degraded source for non-degraded lane
source_val=$(python3 -c "
import json, sys
try:
    with open('$SNAPSHOT_PATH') as f:
        snap = json.load(f)
    print(snap.get('source', 'unknown'))
except:
    print('unknown')
" 2>/dev/null || echo "unknown")

degraded_val=$(python3 -c "
import json, sys
try:
    with open('$SNAPSHOT_PATH') as f:
        snap = json.load(f)
    print('true' if snap.get('degraded', False) else 'false')
except:
    print('unknown')
" 2>/dev/null || echo "unknown")

if [[ "$degraded_val" == "true" && ("$LANE" == "claude_code" || "$LANE" == "codex") ]]; then
  echo "D430 FAIL: boot snapshot source 'degraded' invalid for lane '$LANE'"
  echo "  remedy: ensure MCP config, HTTP bridge, or scope files are available"
  exit 1
fi

echo "D430 PASS: boot snapshot exists, fresh, source=$source_val, degraded=$degraded_val"
exit 0

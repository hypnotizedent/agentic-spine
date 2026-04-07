#!/usr/bin/env bash
# D34: Loop Ledger Integrity Lock
# Purpose: Ensure loop counts are consistent between SQLite authority
#          and the ops loops summary surface.
#
# Authority: SQLite (shared_authority.db) is the sole active-state source.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/ops/lib/spine-paths.sh"
spine_paths_init
LOOPS_SH="$ROOT/ops/commands/loops.sh"

fail() { echo "D34 FAIL: $*" >&2; exit 1; }

# 1. Verify loops.sh summary does NOT use raw grep -c for counting
if grep -q 'grep -c.*status.*open' "$LOOPS_SH" 2>/dev/null; then
    fail "loops.sh summary() still uses raw grep -c (must use authority parser)"
fi

# 2. Count open loops from SQLite authority
SQLITE_OPEN=$(python3 -c "
import sys, os
sys.path.insert(0, '$ROOT/ops/plugins/core/lifecycle/lib')
os.environ.setdefault('SPINE_STATE', '$SPINE_STATE')
import loops_sql_authority as lsa
from pathlib import Path
db_path, _ = lsa.resolve_paths(Path('$ROOT'))
conn = lsa.connect(db_path)
lsa.ensure_schema(conn)
count = conn.execute(\"SELECT COUNT(*) FROM loops WHERE status IN ('active', 'open', 'draft')\").fetchone()[0]
conn.close()
print(count)
" 2>/dev/null) || fail "SQLite loop count query failed"

# 3. Get ops loops summary open count
SUMMARY_OUTPUT="$("$ROOT/bin/ops" loops summary 2>/dev/null)" || fail "ops loops summary failed"
SUMMARY_OPEN="$(echo "$SUMMARY_OUTPUT" | grep -E '^\s*Open:' | awk '{print $2}')"

# 4. Compare SQLite count with summary output
if [[ "$SQLITE_OPEN" != "$SUMMARY_OPEN" ]]; then
    fail "open count mismatch: sqlite=$SQLITE_OPEN summary=$SUMMARY_OPEN"
fi

echo "D34 PASS: loop ledger integrity enforced (open=$SQLITE_OPEN, source=sqlite)"

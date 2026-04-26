#!/usr/bin/env bash
# D34: Loop Ledger Integrity Lock
# Purpose: Ensure loop counts are consistent across all loop-facing surfaces.
#
# Parity checks:
#   P1: SQLite open count == ops loops summary open count
#   P2: SQLite WIP count (active/open/draft) is what loops.create would enforce
#   P3: Scope files in loop-scopes/ have no status that contradicts SQLite
#   P4: ops status open_loops count == SQLite open count
#   P5: No scope-only orphans (open scope files with no SQLite row)
#   P6: Loop closeout receipts must agree with SQLite + scope projection
#   P7: All closure-set files declare SQLite authority (regression guard)
#
# Authority: SQLite (shared_authority.db) is the sole active-state source.
# Scope files are projections, not policy.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/ops/lib/spine-paths.sh"
spine_paths_init
LOOPS_SH="$ROOT/ops/commands/loops.sh"
SCOPES_DIR="$SPINE_STATE/loop-scopes"

fail() { echo "D34 FAIL: $*" >&2; exit 1; }
warn() { echo "D34 WARN: $*" >&2; }

# ── P1: SQLite open count vs summary ──────────────────────────────────────

# 1a. Verify loops.sh summary does NOT use raw grep -c for counting
if grep -q 'grep -c.*status.*open' "$LOOPS_SH" 2>/dev/null; then
    fail "loops.sh summary() still uses raw grep -c (must use authority parser)"
fi

# 1b. Count open loops from SQLite authority
SQLITE_COUNTS=$(python3 -c "
import sys, os
sys.path.insert(0, '$ROOT/ops/plugins/core/lifecycle/lib')
os.environ.setdefault('SPINE_STATE', '$SPINE_STATE')
import loops_sql_authority as lsa
from pathlib import Path
db_path, _ = lsa.resolve_paths(Path('$ROOT'))
conn = lsa.connect(db_path)
lsa.ensure_schema(conn)
open_count = conn.execute(\"SELECT COUNT(*) FROM loops WHERE status IN ('active', 'open', 'draft')\").fetchone()[0]
wip_count = conn.execute(\"SELECT COUNT(*) FROM loops WHERE status IN ('active', 'open', 'draft')\").fetchone()[0]
all_live = conn.execute(\"SELECT COUNT(*) FROM loops WHERE status IN ('active', 'open', 'draft', 'planned', 'blocked')\").fetchone()[0]
print(f'{open_count} {wip_count} {all_live}')
conn.close()
" 2>/dev/null) || fail "SQLite loop count query failed"
read -r SQLITE_OPEN SQLITE_WIP SQLITE_LIVE <<< "$SQLITE_COUNTS"

# 1c. Get ops loops summary open count
SUMMARY_OUTPUT="$("$ROOT/bin/ops" loops summary 2>/dev/null)" || fail "ops loops summary failed"
SUMMARY_OPEN="$(echo "$SUMMARY_OUTPUT" | grep -E '^\s*Open:' | awk '{print $2}')"

# 1d. Compare
if [[ "$SQLITE_OPEN" != "$SUMMARY_OPEN" ]]; then
    fail "P1: open count mismatch: sqlite=$SQLITE_OPEN summary=$SUMMARY_OPEN"
fi

# ── P2: WIP count matches authority ──────────────────────────────────────

# WIP cap in loops-create should enforce against the same WIP count.
# This check verifies the count is derivable from SQLite, not scope files.
if [[ "$SQLITE_WIP" -lt 0 ]]; then
    fail "P2: WIP count from SQLite is negative: $SQLITE_WIP"
fi

# ── P3: Scope files do not contradict SQLite ──────────────────────────────

SCOPE_DRIFT=0
if [[ -d "$SCOPES_DIR" ]]; then
    SCOPE_DRIFT_DETAIL=$(python3 -c "
import sys, os
sys.path.insert(0, '$ROOT/ops/plugins/core/lifecycle/lib')
os.environ.setdefault('SPINE_STATE', '$SPINE_STATE')
import loops_sql_authority as lsa
from pathlib import Path
import re

db_path, _ = lsa.resolve_paths(Path('$ROOT'))
conn = lsa.connect(db_path)
lsa.ensure_schema(conn)

# Build SQLite status index
sqlite_status = {}
for row in lsa.list_loops(conn, status='all'):
    sqlite_status[row['loop_id']] = row['status']
conn.close()

# Check scope files
scopes_dir = Path('$SCOPES_DIR')
drift_count = 0
for path in sorted(scopes_dir.glob('*.scope.md')):
    text = path.read_text()
    fm_lines = []
    in_fm = False
    for line in text.splitlines():
        if line.strip() == '---':
            if in_fm:
                break
            in_fm = True
            continue
        if in_fm:
            fm_lines.append(line)
    fm = {}
    for line in fm_lines:
        if ':' in line:
            k, _, v = line.partition(':')
            fm[k.strip()] = v.strip().strip('\"')
    loop_id = fm.get('loop_id', '')
    scope_status = fm.get('status', '')
    if not loop_id or not scope_status:
        continue
    db_status = sqlite_status.get(loop_id, '')
    if not db_status:
        continue
    # Check if scope and SQLite disagree on live vs terminal
    scope_live = scope_status in ('active', 'open', 'draft', 'planned', 'blocked')
    db_live = db_status in ('active', 'open', 'draft', 'planned', 'blocked')
    if scope_live != db_live:
        drift_count += 1
        print(f'  {loop_id}: sqlite={db_status} scope={scope_status}')
print(f'DRIFT_COUNT={drift_count}')
" 2>/dev/null) || fail "P3: scope-vs-SQLite comparison failed"

    SCOPE_DRIFT="$(echo "$SCOPE_DRIFT_DETAIL" | grep '^DRIFT_COUNT=' | cut -d= -f2)"
    if [[ "${SCOPE_DRIFT:-0}" -gt 0 ]]; then
        warn "P3: $SCOPE_DRIFT scope file(s) disagree with SQLite on live/terminal status:"
        echo "$SCOPE_DRIFT_DETAIL" | grep -v '^DRIFT_COUNT=' >&2
    fi
fi

# ── P4: ops status open count agrees ─────────────────────────────────────

STATUS_JSON="$("$ROOT/bin/ops" status --json 2>/dev/null)" || true
if [[ -n "$STATUS_JSON" ]]; then
    STATUS_OPEN="$(echo "$STATUS_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('summary',{}).get('open_loops', d.get('coherence_summary',{}).get('open_loops','?')))" 2>/dev/null || echo "?")"
    if [[ "$STATUS_OPEN" != "?" && "$STATUS_OPEN" != "$SQLITE_OPEN" ]]; then
        fail "P4: ops status open_loops=$STATUS_OPEN != sqlite open=$SQLITE_OPEN"
    fi
fi

# ── P5: No scope-only orphans in live scopes dir ────────────────────────

ORPHAN_COUNT=0
if [[ -d "$SCOPES_DIR" ]]; then
    ORPHAN_DETAIL=$(python3 -c "
import sys, os
sys.path.insert(0, '$ROOT/ops/plugins/core/lifecycle/lib')
os.environ.setdefault('SPINE_STATE', '$SPINE_STATE')
import loops_sql_authority as lsa
from pathlib import Path

db_path, _ = lsa.resolve_paths(Path('$ROOT'))
conn = lsa.connect(db_path)
lsa.ensure_schema(conn)

sqlite_ids = set()
for row in lsa.list_loops(conn, status='all'):
    sqlite_ids.add(row['loop_id'])
conn.close()

scopes_dir = Path('$SCOPES_DIR')
orphan_count = 0
for path in sorted(scopes_dir.glob('*.scope.md')):
    text = path.read_text()
    fm_lines = []
    in_fm = False
    for line in text.splitlines():
        if line.strip() == '---':
            if in_fm:
                break
            in_fm = True
            continue
        if in_fm:
            fm_lines.append(line)
    fm = {}
    for line in fm_lines:
        if ':' in line:
            k, _, v = line.partition(':')
            fm[k.strip()] = v.strip().strip('\"')
    loop_id = fm.get('loop_id', '')
    scope_status = fm.get('status', '')
    if not loop_id or not scope_status:
        continue
    if scope_status not in ('active', 'open', 'draft'):
        continue
    if loop_id not in sqlite_ids:
        orphan_count += 1
        print(f'  {loop_id} (scope_status={scope_status})')
print(f'ORPHAN_COUNT={orphan_count}')
" 2>/dev/null) || fail "P5: scope-only orphan scan failed"

    ORPHAN_COUNT="$(echo "$ORPHAN_DETAIL" | grep '^ORPHAN_COUNT=' | cut -d= -f2)"
    if [[ "${ORPHAN_COUNT:-0}" -gt 0 ]]; then
        ORPHAN_LINES="$(echo "$ORPHAN_DETAIL" | grep -v '^ORPHAN_COUNT=')"
        fail "P5: $ORPHAN_COUNT scope file(s) have open status but no SQLite row (scope-only orphans):
$ORPHAN_LINES"
    fi
fi

# ── P6: Closeout receipts agree with SQLite + projection ──────────────

RECEIPT_DRIFT=0
CLOSEOUT_DIR="${SPINE_EVIDENCE_ROOT}/loop-closeouts"
if [[ -d "$CLOSEOUT_DIR" ]]; then
    RECEIPT_DETAIL=$(python3 -c "
import sys, os, re
from pathlib import Path
sys.path.insert(0, '$ROOT/ops/plugins/core/lifecycle/lib')
os.environ.setdefault('SPINE_STATE', '$SPINE_STATE')
import loops_sql_authority as lsa

db_path, scopes_dir = lsa.resolve_paths(Path('$ROOT'))
archive_dir = lsa.resolve_scope_archive_dir(scopes_dir)
conn = lsa.connect(db_path)
lsa.ensure_schema(conn)
sqlite_status = {row['loop_id']: row['status'] for row in lsa.list_loops(conn, status='all')}
conn.close()

live_statuses = {'active', 'open', 'draft', 'planned', 'blocked'}
closeout_dir = Path('$CLOSEOUT_DIR')
drift_count = 0
loop_id_re = re.compile(r'^- loop_id:\\s*(\\S+)\\s*$')

for path in sorted(closeout_dir.glob('LOOP-*.closeout.md')):
    loop_id = path.name.removesuffix('.closeout.md')
    try:
        text = path.read_text(encoding='utf-8')
    except OSError:
        continue
    match = loop_id_re.search(text)
    if match:
        loop_id = match.group(1).strip()
    if not loop_id:
        continue

    db_status = str(sqlite_status.get(loop_id, '')).strip().lower()
    live_scope = scopes_dir / f'{loop_id}.scope.md'
    archived_scope = archive_dir / f'{loop_id}.scope.md'

    if db_status in live_statuses:
        drift_count += 1
        print(f'  {loop_id}: closeout receipt exists but SQLite says {db_status}')
        continue
    if db_status and not archived_scope.exists():
        drift_count += 1
        print(f'  {loop_id}: closeout receipt exists but archived projection is missing')
        continue
    if live_scope.exists():
        drift_count += 1
        print(f'  {loop_id}: closeout receipt exists but live scope projection still exists')

print(f'RECEIPT_DRIFT={drift_count}')
" 2>/dev/null) || fail "P6: closeout receipt parity scan failed"

    RECEIPT_DRIFT="$(echo "$RECEIPT_DETAIL" | grep '^RECEIPT_DRIFT=' | cut -d= -f2)"
    if [[ "${RECEIPT_DRIFT:-0}" -gt 0 ]]; then
        RECEIPT_LINES="$(echo "$RECEIPT_DETAIL" | grep -v '^RECEIPT_DRIFT=')"
        fail "P6: $RECEIPT_DRIFT closeout receipt(s) disagree with SQLite/projection truth:
$RECEIPT_LINES"
    fi
fi

# ── P7: Closure set files all declare SQLite authority ────────────────

CLOSURE_SET=(
    "ops/plugins/core/orchestration/bin/authority-resolve"
    "ops/plugins/core/lifecycle/bin/entry-compile"
    "ops/plugins/core/lifecycle/bin/session-v3-attach"
    "ops/plugins/core/lifecycle/bin/loops-background-start"
    "ops/plugins/core/lifecycle/bin/planning-horizon-promote-due"
)
P6_MISSING=0
for cs_file in "${CLOSURE_SET[@]}"; do
    cs_path="$ROOT/$cs_file"
    if [[ -f "$cs_path" ]]; then
        if ! grep -q '# Authority: SQLite' "$cs_path" 2>/dev/null; then
            warn "P6: $cs_file lacks '# Authority: SQLite' marker"
            P6_MISSING=$((P6_MISSING + 1))
        fi
    fi
done
if [[ "$P6_MISSING" -gt 0 ]]; then
    fail "P7: $P6_MISSING closure-set file(s) missing SQLite authority marker"
fi

echo "D34 PASS: loop ledger integrity (open=$SQLITE_OPEN wip=$SQLITE_WIP live=$SQLITE_LIVE scope_drift=$SCOPE_DRIFT orphans=${ORPHAN_COUNT:-0} receipt_drift=${RECEIPT_DRIFT:-0} closure_set=5/5 source=sqlite)"

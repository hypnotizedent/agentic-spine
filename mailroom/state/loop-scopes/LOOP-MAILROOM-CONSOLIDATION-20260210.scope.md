---
status: active
owner: "@ronny"
last_verified: 2026-02-10
scope: loop-scope
loop_id: LOOP-MAILROOM-CONSOLIDATION-20260210
severity: high
---

# Loop Scope: LOOP-MAILROOM-CONSOLIDATION-20260210

## Goal

Eliminate the split-brain in work tracking. The spine must have **one canonical system** for open work, not two disconnected engines with five unlinked data stores. Every agent entering the spine via `AGENTS.md` must be able to discover all open work — loops, gaps, inbox items, parked items — from a single command, with no tribal knowledge required.

## Problem / Current State (2026-02-10)

The mailroom has fragmented into parallel systems that don't cross-reference:

**System A — JSONL engine** (`open_loops.jsonl`, 177 lines):
- Fed by `ops loops collect` auto-scanning receipts for failures
- `ops loops list --open` reads ONLY this file — it's the sole agent entry point
- Auto-generates `OL_*` IDs, most are noise from one-off capability failures
- Does NOT read scope files, inbox, gaps, or parked items

**System B — folder engine** (`mailroom/inbox/`, `parked/`, `done/`):
- 3 OPEN items in inbox (PVE-NODE-NAME-FIX-HOME, HOME-BACKUP, HOME-MEDIA-DOCS)
- 1 redundant item in parked (MD1400-SAS-DRIVER-RESOLVE, duplicates a loop-scope)
- 1 mislabeled item in done (SHOP-VM-BACKUP-COVERAGE, says OPEN but in done/)
- **Invisible to `ops loops list`** — no code reads these folders
- **Invisible to agents** — AGENTS.md only says "run `ops loops list --open`"

**System C — gap registry** (`operational.gaps.yaml`):
- 7 open gaps, some linked to loops by convention (free-text `fixed_in`/`notes` field)
- Agents only find gaps if told to grep or run `/gaps`

**System D — scope files** (`loop-scopes/*.scope.md`):
- 57 files with YAML frontmatter (status, owner, severity)
- Most useful format — has phases, receipts, success criteria
- But `ops loops list` doesn't read these; they're maintained by hand separately

**System E — ledger** (`ledger.csv`, 560KB):
- Append-only receipt log — read by `loops collect` for failure detection
- Not a work tracker, but gets confused with one

**Result:** An agent runs `ops loops list --open`, sees 4 items, and misses 3 inbox items, 7 open gaps, and 1 parked item. The operator has to remember to tell agents where to look every session.

## Architectural Decision

**Loop-scopes are the canonical work tracker.** Everything else either feeds into them or gets archived.

- `loop-scopes/*.scope.md` = **the SSOT for open work** (status in frontmatter)
- `operational.gaps.yaml` = **the SSOT for gaps** (gets a `parent_loop` structured field)
- `ledger.csv` = **the receipt trail** (append-only, not a work tracker)
- `open_loops.jsonl` = **deprecated** (replaced by reading scope frontmatter)
- `mailroom/inbox/` = **intake queue** (items must be promoted to scope files or archived)
- `mailroom/parked/` = **holding pen** (items waiting on external blockers, must ref a scope)
- `mailroom/done/` = **archive** (closed items, status must say CLOSED)

## Success Criteria

1. `ops loops list --open` reads `loop-scopes/*.scope.md` frontmatter (not JSONL)
2. A new `ops status` command outputs unified view: open loops + open gaps + unprocessed inbox + anomalies
3. `AGENTS.md` step 3 updated to `ops status` as the single entry point
4. All 3 inbox items either promoted to loop-scopes or archived with reason
5. Parked MD1400-SAS-DRIVER-RESOLVE archived (redundant with canonical scope)
6. Done/SHOP-VM-BACKUP-COVERAGE status corrected or archived
7. `operational.gaps.yaml` schema gains `parent_loop` field (optional, structured)
8. `open_loops.jsonl` archived and no longer written to by `loops collect`
9. Gate (D-next) enforces: every inbox item must be promoted or archived within 48h
10. Gate (D-next) enforces: `ops status` returns 0 only when no anomalies exist

## Phases

### P0: Triage mailroom state (no code changes)
- Promote or archive all inbox/parked/done items
- Add `parent_loop` to open gaps where applicable
- Archive `open_loops.jsonl` (rename to `open_loops.jsonl.archived`)

### P1: Rewire `ops loops list` to read scope frontmatter
- `list_loops()` reads `loop-scopes/*.scope.md` YAML frontmatter
- Filter by `status: active|draft` (open) vs `status: closed`
- Preserve existing output format for compatibility

### P2: Build `ops status` unified view
- Reads: scope files + gaps + inbox + parked + done
- Cross-references gaps to loops via `parent_loop`
- Flags anomalies (status mismatches, unlinked gaps, stale inbox)
- Becomes the canonical agent entry point

### P3: Gates + AGENTS.md update
- Register D-next gates for inbox staleness and status clean
- Update `AGENTS.md` step 3 to `ops status`
- Update `SESSION_PROTOCOL.md` references

## Receipts

- (add run keys here)

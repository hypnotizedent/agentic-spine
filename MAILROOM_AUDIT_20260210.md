# MAILROOM AUDIT REPORT
**READ-ONLY STRUCTURAL REVIEW**
Generated: 2026-02-10

---

## 1. DIRECTORY STRUCTURE INVENTORY

### Mailroom Root Structure
```
/mailroom/
├── inbox/                    ← Multi-lane agent work queue
│   ├── queued/              ← Drop zone (enqueued work waiting)
│   ├── running/             ← In-flight (watcher processing)
│   ├── done/                ← Success (71 items)
│   ├── failed/              ← API errors (empty)
│   ├── parked/              ← Blocked (empty except .keep)
│   └── archived/            ← Old completed work (3 items)
├── done/                     ← REDUNDANT: Separate done folder (1 item)
│   └── archived/            ← REDUNDANT: Nested archived (LOOP-SHOP-VM)
├── outbox/                   ← Results storage (80 items + subdirs)
│   ├── *.md                 ← Result files (74 files)
│   ├── audit-export/        ← Audit/snapshot exports (36 items)
│   ├── quarantine/          ← Untracked/risky content (2 subdirs)
│   ├── backup-calendar/     ← ICS exports
│   ├── maker/               ← Empty placeholder
│   └── spine-*.zip          ← Backup archives
├── parked/                   ← REDUNDANT: Separate parked folder (1 item)
│   └── archived/            ← REDUNDANT: Nested archived (MD1400-SAS)
├── state/                    ← Governance metadata
│   ├── ledger.csv          ← Transaction log (3550 entries)
│   ├── loop-scopes/        ← Loop scope SSOT (57 scope files)
│   ├── locks/              ← Concurrency controls (.lock files)
│   └── *.jsonl/*.cursor    ← Loop collection state
├── receipts/                 ← REDUNDANT: Receipts here too
│   └── sessions/           ← 1 receipt (CERT-20260209)
└── logs/                     ← Watcher activity
    ├── hot-folder-watcher.log
    ├── agent-inbox.err
    └── agent-inbox.out
```

### Top-Level Receipts (Outside Mailroom)
```
/receipts/
├── audits/              ← Audit session receipts
├── workbench/           ← Workbench run receipts
└── sessions/            ← 3686 session receipt folders (MAIN SINK)
    └── R<run_key>/      ← One folder per run
        └── receipt.md   ← Proof + metadata
```

---

## 2. README DOCUMENTATION STATUS

**VERDICT: CRITICAL MISSING**

✗ **NO README in mailroom root** — Confirmed
✗ **NO INDEX or navigation guide** — Agents entering cold cannot determine folder purposes without reading source code
✗ **MAILROOM_RUNBOOK.md exists** but lives in `docs/governance/` — not discoverable from the mailroom itself

**What a cold-start agent sees:**
```bash
$ cd mailroom
$ ls
done/  inbox/  logs/  outbox/  parked/  receipts/  state/
```

No inline guidance on:
- Which folder is the "source of truth" for work
- Whether `inbox/` or `parked/` should be used
- Why both `mailroom/done/` and `inbox/done/` exist
- Where to find open work
- How to check work status

---

## 3. LEDGER.CSV SCHEMA & VOLUME

**File:** `mailroom/state/ledger.csv`

### Schema (9 columns)
```csv
run_id           # Unique identifier (alphanumeric or CAP-YYYYMMDD__name__R* format)
created_at       # ISO8601 timestamp
started_at       # ISO8601 timestamp (null if not yet started)
finished_at      # ISO8601 timestamp (null if running)
status           # Enum: running, done, failed, parked
prompt_file      # Original filename in inbox/
result_file      # Output filename in outbox/ (usually receipt.md)
error            # Error message (null if no error)
context_used     # Context mode: none, rag-lite, capability
```

### Volume & Distribution

| Metric | Value |
|--------|-------|
| Total Rows | 3550 |
| Unique run_ids | ~1000+ (multiple transitions per run) |
| Status Distribution | (sampling) mostly `done`, some `failed`, ~0 `parked` |
| Date Range | 2026-02-01 to 2026-02-10 (9 days) |
| Append-only? | Yes (no deletions observed) |

### Example Entries (raw)
```csv
oyvq40133,2026-02-03T00:58:18Z,2026-02-03T00:58:18Z,,running,...
oyvq40133,2026-02-03T00:58:27Z,,2026-02-03T00:58:27Z,done,...
CAP-20260202-210119__spine.verify__Riewh15615,2026-02-03T02:01:19Z,...,failed,...
```

**Observation:** Each run typically has 2+ rows (status transitions: enqueued → running → done/failed).

---

## 4. LOOP-SCOPES FORMAT & PURPOSE

**Location:** `mailroom/state/loop-scopes/*.scope.md`
**Count:** 57 files
**Pattern:** `LOOP-<NAME>-<DATE>.scope.md`

### Format Example
```yaml
---
status: closed|active|draft|open
owner: "@ronny"
last_verified: YYYY-MM-DD
scope: loop-scope
loop_id: LOOP-<NAME>-<DATE>
severity: high|medium|low
---

# Loop Scope: LOOP-<NAME>-<DATE>

## Goal
[Narrative description of what the loop aims to achieve]

## Problem / Current State
[What's broken or needs work]

## Success Criteria
- Bulleted list of proof points

## Phases
1. First actionable step
2. Second actionable step
...

## Evidence
- **R-<identifier>**: Link to receipt folder
- Machine-readable proof (e.g., JSON artifact)

## Receipts
- `R<date>-<identifier>` (timestamp) — Description
...

## Deferred / Follow-ups
[Items punted to future loops]
```

### Real Example
- **LOOP-MAILROOM-CONSOLIDATION-20260210.scope.md** — Describes split-brain work tracking across 4 parallel systems (JSONL, folder, gap, scope)
- **LOOP-MAILROOM-GAP-LINKAGE-20260211.scope.md** — Links orphan gaps to parent loops
- **LOOP-UDR6-SHOP-CUTOVER-20260209.scope.md** — Multi-phase infrastructure migration

**Key insight:** Loop scopes are the richest format (include phases, owners, severity) but are **NOT indexed by the ledger or `ops loops list`**. They live as static .scope.md files that must be maintained by hand.

---

## 5. OUTBOX CONTENTS & SPECIAL DIRECTORIES

**Location:** `mailroom/outbox/`
**Total Items:** ~110 items (74 result files + subdirectories)

### Result Files (Top-Level)
```
74 *.md files matching pattern:
  - S20260201-180000__email_received__R0001__RESULT.md
  - S20260202-201045__inline__R1bq943242__RESULT.md
  - CAP-20260202-215058__spine.status__R813b24065 (some without __RESULT suffix)
  - CLAUDE__RESULT.md
  - MEDIA_STACK_RCA_PHASE_A_RETROSPECTIVE.md
  - ORDER_INTAKE_CONTRACT_SPEC__RESULT.md
```

### audit-export/ (36 items)
```
audit-export/
├── 2026-02-10-full-certification.md
├── FS_EXPORT_20260208-005315/
├── FS_EXPORT_20260208-143911/
├── FS_EXPORT_20260208-160810/
└── ...5 more FS_EXPORT snapshots
```
**Purpose:** Point-in-time filesystem audits for verification loops

### quarantine/ (2 subdirectories)
```
quarantine/
├── WORKBENCH_UNTRACKED_20260208-161550/  ← Large tree of untracked files from workbench
│   ├── infra/compose/
│   ├── scripts/
│   └── scripts/backups/
└── parked-fixtures/
```
**Purpose:** Content that was either untracked, risky, or requires manual review. **Not production.**

### backup-calendar/
```
backup-calendar/
└── backup-calendar.ics
```
**Purpose:** Calendar export (ICS format) for scheduled backups. Single file.

### maker/ (Empty)
```
maker/
└── .gitkeep
```
**Purpose:** Unknown. Placeholder for future content? No documentation.

### spine-*.zip
```
spine-dd0672385e81-20260210T163415Z.zip
spine-backups.ics
```
**Purpose:** Full spine backup archives. Can be very large.

---

## 6. RECEIPTS DUPLICATION: TWO LOCATIONS

### Top-Level `/receipts/` (CANONICAL)
```
/receipts/
├── audits/           ← Audit session receipts
├── workbench/        ← Workbench run receipts  
└── sessions/         ← MAIN: 3686+ R<run_key>/ folders
    └── R<run_key>/
        └── receipt.md
```

**Evidence:** `ADHOC_20260131_231421_HOME_DRIFT_AUDIT`, `CERT-20260209-200000__full-certification-audit__T1`, etc. (3686 directories)

### Inside Mailroom `/mailroom/receipts/`
```
/mailroom/receipts/
└── sessions/
    └── CERT-20260209-200000__full-certification-audit__T1/
        (1 folder, appears to be a copy or symlink)
```

**Problem:**
- **Primary truth is `/receipts/`** — Runbook references this in ledger reconciliation
- **Mailroom receipt folder is ~empty** — Only 1 receipt visible
- **No documentation** on why both exist or how they're kept in sync
- **Agents reading MAILROOM_RUNBOOK.md might be confused** — Runbook says "all receipts" but they're actually outside the mailroom

---

## 7. INBOX FOLDER REDUNDANCY

### inbox/ (Queue System - Active)
```
inbox/
├── queued/         ← Current work entry point (empty or backlog)
├── running/        ← In-flight (0-1 files)
├── done/           ← Completed (71 items)
│   └── Files named: S20260208-202438__audit_mt4_register_automation_services__Rmt04.md
├── failed/         ← API errors (empty, .keep only)
├── parked/         ← Manual holds (empty, .keep only)
└── archived/       ← Old completed items (3 items)
    ├── LOOP-HOME-BACKUP-INFRASTRUCTURE-ENABLE.md
    ├── LOOP-HOME-MEDIA-STACK-DOCUMENTATION.md
    └── LOOP-PVE-NODE-NAME-FIX-HOME.md
```

### Separate mailroom/done/ (Inactive)
```
done/
└── archived/
    └── LOOP-SHOP-VM-BACKUP-COVERAGE-COMPLETE.md (1 item)
```

**Problem:** 
- **inbox/done/** has 71 items → Active execution queue
- **mailroom/done/** has 1 item → Dead folder
- **inbox/archived/** has 3 items → Loop scopes
- **mailroom/done/archived/** has 1 item → Also a loop scope (duplicate?)
- **NO GUIDANCE** on why the split or which agents should use which

---

## 8. PARKED FOLDER REDUNDANCY

### inbox/parked/ (Queue System - Part of Runbook)
```
inbox/parked/
└── .keep (empty, no actual parked items)
```

### Separate mailroom/parked/ (Dead Folder)
```
parked/
└── archived/
    └── LOOP-MD1400-SAS-DRIVER-RESOLVE.md (1 item)
```

**Problem:**
- **Runbook says blocks go to `inbox/parked/`** — Clean queue semantics
- **mailroom/parked/** exists separately with an archived loop scope
- **No rationale** for parallel folder structure
- **No agent knows to look in mailroom/parked/**

---

## 9. AGENT DISCOVERABILITY: Cold-Start Experience

### What the Runbook Says
**From `MAILROOM_RUNBOOK.md`:**
```
## Mailroom Structure

mailroom/
├── inbox/
│   ├── queued/    ← Drop zone: enqueued work waits here
│   ├── running/   ← In-flight: watcher is processing
│   ├── done/      ← Success: API call succeeded
│   ├── failed/    ← Error: API call or processing failed
│   └── parked/    ← Blocked: requires manual intervention
├── outbox/        ← Results: <run_key>__RESULT.md files
├── state/         ← Loop scopes, ledger, locks
└── logs/          ← Watcher activity
```

### What Actually Exists
```
mailroom/ (11 subdirs)
├── inbox/
├── outbox/
├── done/           ← NOT IN RUNBOOK
├── parked/         ← NOT IN RUNBOOK  
├── receipts/       ← NOT IN RUNBOOK
├── state/
├── logs/
└── .DS_Store, .keep, etc.
```

### What a Cold-Start Agent Infers
1. "The runbook says `inbox/` is the work queue"
   - ✓ Clear: queued/ → running/ → done/
   - ✗ Confusing: `/done/` is also visible, is it old?
   
2. "Where do I find open work?"
   - Runbook says: `./bin/ops loops list --open` (reads JSONL)
   - But scope files are more complete
   - No command shows inbox items or gaps
   - Agent doesn't know these three systems exist separately
   
3. "What if I need to check a parked item?"
   - Runbook says `inbox/parked/`
   - But `mailroom/parked/` also exists (dead)
   - No agent convention; risky to guess

4. "Are mailroom/receipts/ and /receipts/ synced?"
   - Runbook mentions `/receipts/` in ledger reconciliation
   - `mailroom/receipts/` appears to be a duplicate
   - No SOP for which is canonical

---

## 10. ISOLATED AUTONOMOUS WORK vs. DAY-TO-DAY OPERATIONS

### Current Structure (No Separation)
```
mailroom/
├── inbox/          ← ALL work: tests, inline requests, loops, etc.
├── state/
│   └── loop-scopes/ ← Long-lived multi-phase work (explicit governance)
└── (no separate "experimental" zone)
```

### Gap: No Sandbox or Staging
- **All work flows through the same queue** (inbox/)
- **Short-lived inline requests** (ad-hoc R* tests) mix with **long-lived loops** (LOOP-*)
- **No separation** between:
  - One-off capability proofs vs. multi-week infrastructure loops
  - Draft/experimental work vs. production-critical loops
  - Isolated agent research vs. team consensus work
  
### Implication for Agents
- An agent testing a new feature must **feed it through the main inbox**
- No way to say "try this, collect results, don't integrate yet"
- Loop scopes exist for governance but don't create isolated workspaces
- Agents risk cluttering the main queue with experimental work

---

## 11. DOCUMENTATION GAPS vs. AGENT NEEDS

### What Agents SHOULD Know But Don't Have

| Gap | Current State | Impact |
|-----|---------------|--------|
| **Folder Purpose Hierarchy** | No README in mailroom/ | Agent guesses: inbox/ = main, done/ = old, mailroom/done = ??? |
| **inbox/ Queue vs. Loop Scopes** | Separate systems, not linked | Agent doesn't know `inbox/done/` items may also be scope files |
| **When to Use Each Tool** | `ops loops list --open` vs. grep scopes vs. `/gaps` | Agent uses only one; misses work in other systems |
| **Receipts Location** | Two locations, no SOP | Agent doesn't know which to check or if they're synced |
| **Parked vs. Blocked** | Two parked folders | Agent doesn't know where to put blocked work |
| **Loop Scope Lifecycle** | 57 scope files with no index | Agent manually hunts for LOOP-* files to understand ongoing work |
| **Outbox Purpose** | Results live there, but it's a dump | Agent doesn't know what audit-export/, quarantine/, maker/ are for |
| **Ledger Schema** | Documented in runbook | Agent doesn't know 3550 rows track 1000+ runs with multiple transitions per run |

### What Agents MUST Discover by Reading Code
1. "Are loop scopes real or just documentation?" → Read MAILROOM_RUNBOOK.md line 126
2. "Where do I check open loops?" → Read AGENTS.md for `ops loops list --open` reference
3. "Why are results in outbox/ AND inbox/done/?" → Manually trace watcher.sh code
4. "What's the canonical receipts location?" → Grep runbook for `/receipts/` references

---

## VERDICT SECTION

### A. REDUNDANCY

**Severity: HIGH**

| Redundant Structure | Issue | Impact |
|-----|--------|--------|
| `mailroom/done/` + `inbox/done/` | Two "completed work" folders | Agents don't know which to query; one is dead |
| `mailroom/parked/` + `inbox/parked/` | Two "blocked work" folders | Risk of parked items being invisible |
| `mailroom/inbox/archived/` + `mailroom/done/archived/` | Archived items in two places | Harder to audit historical work |
| `/receipts/` + `/mailroom/receipts/` | Receipts in two locations | No SOP for which is truth; sync unknown |
| `loop-scopes/*.scope.md` + `open_loops.jsonl` | Two loop registries, not cross-linked | `ops loops list` doesn't read scopes; scope files aren't indexed |

**Root Cause:** Split-brain evolution. Mailroom grew with parallel subsystems (folder queue, JSONL engine, scope files, gap registry) that don't share state.

---

### B. MISSING DOCUMENTATION

**Severity: CRITICAL**

1. **No README in mailroom root**
   - Agents entering the mailroom directory see 7+ folders with no guidance
   - Runbook exists but lives outside; not discoverable from the mailroom
   
2. **No folder index or purpose key**
   ```
   # MISSING: mailroom/INDEX.md or mailroom/README.md
   # Should include: purpose of each folder, when to use each, relationships
   ```

3. **No loop scope index or registry**
   - 57 scope files with no summary or discovery mechanism
   - Agent must manually ls/ to find open loops
   - No link from ledger or `ops` output to scopes

4. **No guidance on parallel systems**
   - Agents don't know four systems exist: JSONL, folder queue, gaps, scopes
   - No SOP: "Use `ops loops list --open` (reads JSONL), but check scope files (richer), also check gaps, also check inbox/"
   - Risk: Agent misses work in unmonitored system

5. **No outbox directory guide**
   - `audit-export/`, `quarantine/`, `backup-calendar/`, `maker/` unexplained
   - What is "quarantine"? Is it prod-ready or staging? Unknown.

---

### C. AGENT CONFUSION RISKS

**Severity: HIGH**

#### Risk 1: Work Discovery Blindness
An agent runs:
```bash
./bin/ops loops list --open
# Returns 20 JSONL-based loops
```

But doesn't know:
- 57 scope files exist (richer format, includes phases)
- 3 items in inbox/archived (might be open)
- 7 gaps in operational.gaps.yaml (no link to loops)
- 1 item in mailroom/parked (blocked work)

**Outcome:** Agent starts work on something already in progress or duplicates effort.

#### Risk 2: Ambiguous Folder Purpose
An agent:
1. Reads runbook → sees `inbox/` described as the queue
2. Sees `mailroom/done/` in the filesystem
3. Assumes it's old completed work
4. Later discovers loop scopes also live in done/archived (active governance)
5. Confused about what's dead vs. active

#### Risk 3: Receipts Location Confusion
Runbook says:
> "Every `done` ledger entry should have a receipt folder: `receipts/sessions/R<run_key>/receipt.md`"

Agent checks:
```bash
ls /mailroom/receipts/sessions/  # 1 item
ls /receipts/sessions/           # 3686 items
```

Agent thinks: "Which is the truth? Are they synced? Am I looking at stale data?"

#### Risk 4: Blocking Work Ambiguity
Runbook says: "Move parked file back to queued for retry: `mv inbox/parked/filename.md inbox/queued/`"

Agent checks:
```bash
ls mailroom/inbox/parked/        # empty (.keep only)
ls mailroom/parked/              # has an archived loop
```

Agent thinks: "So parked/ is for queued items, and mailroom/parked/ is... dead? Old? Why is it there?"

---

### D. SYSTEM ARCHITECTURE FRAGILITY

**Severity: MEDIUM → HIGH**

**Current State (from loop scope LOOP-MAILROOM-CONSOLIDATION-20260210):**

The mailroom has split into 4 parallel, barely-linked systems:

1. **JSONL Engine** (`open_loops.jsonl`)
   - Fed by `ops loops collect` (scans receipts for failures)
   - Queried by `ops loops list --open` (agent entry point)
   - ~177 lines, mostly auto-generated OL_* IDs
   - Does NOT read scope files, inbox, or gaps

2. **Folder Engine** (`inbox/`, `parked/`, `done/`)
   - 3 open items in inbox (visible to humans, not to ops)
   - Invisible to `ops loops list`
   - Invisible to agents unless manually directed

3. **Gap Registry** (`operational.gaps.yaml`)
   - 7 open gaps
   - No auto-link to loops; only free-text `fixed_in` field
   - Agents find gaps only via grep or `/gaps` command

4. **Scope Files** (`loop-scopes/*.scope.md`)
   - 57 files, richest format (phases, owners, severity)
   - Not indexed by ledger or `ops loops list`
   - Maintained by hand

**Risk:** If any system falls out of sync, agents can't tell. Example:
- Loop A is marked `closed` in its scope file
- But an inbox item still references Loop A
- Ledger has 10 rows linking Loop A
- JSONL has stale OL_LoopA entries
- Agent thinks it's still open, restarts it

---

### E. WHAT NEEDS TO CHANGE

**Priority 1: Create Mailroom Index & Navigation (URGENT)**
```markdown
# mailroom/README.md

## Quick Start

1. **Check open work:** `./bin/ops status`
2. **Queue a request:** `./bin/ops run <prompt.md>`
3. **Monitor:** `ls mailroom/inbox/{queued,running,done}/`
4. **Govern loops:** See `mailroom/state/loop-scopes/` (57 scopes)
5. **Receipts:** See `/receipts/sessions/` (canonical location)

## Folder Guide

| Folder | Purpose | Content | Agent Action |
|--------|---------|---------|--------------|
| `inbox/queued/` | Work queue entry | New requests | Drop files here via ops |
| `inbox/running/` | In-flight processing | 0-1 files | (watcher only) |
| `inbox/done/` | Completed API calls | ~71 items | Read for results |
| `inbox/failed/` | Failed API calls | ~0 items | Investigate + retry |
| `inbox/parked/` | Blocked (manual review) | ~0 items | Unblock secrets + unpark |
| `inbox/archived/` | Old completed loops | 3 items | Historical reference |
| `state/ledger.csv` | All transitions (3550 rows) | Audit trail | Query via ops tools |
| `state/loop-scopes/` | Open loops (57 files) | Long-term work | Source of truth for loops |
| `outbox/` | Results & exports | 80+ items | Read for loop outputs |
| `/receipts/sessions/` | Canonical receipts | 3686+ folders | Check proof of execution |

## DO NOT USE

- `mailroom/done/` — Dead folder, use `inbox/done/` instead
- `mailroom/parked/` — Dead folder, use `inbox/parked/` instead
- `mailroom/receipts/` — Use `/receipts/` instead

## Systems You Need to Know

1. **Ops CLI** → `./bin/ops status`, `./bin/ops loops list --open`
2. **Loop Scopes** → `mailroom/state/loop-scopes/*.scope.md` (57 files, richer format)
3. **Gaps** → `operational.gaps.yaml` (7 open)
4. **Ledger** → `mailroom/state/ledger.csv` (complete audit trail)

See `docs/governance/MAILROOM_RUNBOOK.md` for deep dive.
```

**Priority 2: Consolidate/Deprecate Dead Folders**
- Move `mailroom/done/archived` → `inbox/archived/` (merge)
- Move `mailroom/parked/archived` → `inbox/archived/` (merge)
- Delete empty `mailroom/done/`, `mailroom/parked/` folders
- Or: Archive and document why they exist (if historical)

**Priority 3: Link Receipt Folders**
- Clarify: **`/receipts/` is canonical**, `mailroom/receipts/` is a copy (or deprecate the copy)
- Update runbook to remove ambiguity
- Add a .README in mailroom/receipts/ saying "See /receipts/ instead"

**Priority 4: Create Loop Scope Index**
```bash
# Add to mailroom/state/ or ops output:
./bin/ops loops summary
# Output:
# Open Loops (57 total):
#   - LOOP-MAILROOM-CONSOLIDATION-20260210 (severity: high, owner: @ronny)
#   - LOOP-UDR6-SHOP-CUTOVER-20260209 (severity: high, owner: @ronny)
#   ... (full list with status)
```

**Priority 5: Link the Four Systems**
- Make `ops loops list --open` read scope files (not just JSONL)
- Index loop scopes in the ledger or a metadata file
- Create a reconciliation report: "Loops vs. Gaps vs. Inbox vs. JSONL"
- Example: `./bin/ops audit --check-consolidation`

**Priority 6: Document Outbox Subdirectories**
```markdown
# mailroom/outbox/README.md

| Subdirectory | Purpose | Retention |
|---|---|---|
| Root (*.md) | Loop/capability results | Keep (append-only ledger) |
| audit-export/ | Point-in-time FS snapshots | Keep for traceability |
| quarantine/ | Untracked/risky content | Review & archive or delete |
| backup-calendar/ | Scheduled backup exports | Overwrite periodically |
| maker/ | (Reserved for future use) | N/A |
| spine-*.zip | Full spine backups | Rotate (keep last 5) |
```

**Priority 7: Add Loop Scope Cleanup SOP**
- Create a workflow for moving closed loops out of active view
- Example: `closed` scopes stay in loop-scopes/ but are filtered by `ops loops list --open`
- Document where to find historical closed loops

---

## APPENDIX: Key File Sizes & Dates

| File | Size | Last Modified | Notes |
|------|------|---|---|
| ledger.csv | 3550 rows | 2026-02-10 | Append-only; all transitions |
| open_loops.jsonl | 177 lines | 2026-02-10 | Auto-generated, incomplete |
| loop-scopes/ | 57 files | 2026-02-11 | Hand-maintained, richer |
| inbox/done/ | 71 items | 2026-02-10 | API call results |
| outbox/ | 74 + subdirs | 2026-02-10 | Results + snapshots + exports |
| /receipts/sessions/ | 3686+ folders | 2026-02-10 | Canonical proof store |
| mailroom/receipts/ | 1 folder | 2026-02-09 | Appears to be copy/stale |

---

**END AUDIT**

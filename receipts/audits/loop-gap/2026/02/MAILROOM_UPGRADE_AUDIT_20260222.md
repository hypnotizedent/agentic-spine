---
status: authoritative
owner: "@ronny"
created: 2026-02-22
scope: mailroom-upgrade-audit
---

# Mailroom Upgrade Audit — 2026-02-22

> Full sweep of the mailroom system: what's working, what's dead, what's confusing agents, and what needs to change before multi-agent orchestration and spine memory engine.

---

## Current State

The mailroom has 560+ files across outbox, state, and logs. The proposal system works. Alerts fire. Briefings generate. But the mailroom was never upgraded alongside the spine — it grew organically and now has structural debt that will become a serious problem as we add more agents.

---

## The 8 Problems

### 1. CRITICAL — Ledger Is Dead

`state/ledger.csv` has 2 lines. The README says it's the "source of truth for run history" but it stopped being populated after Feb 16. There are 77+ RESULT files in the outbox with no ledger entries. Any agent querying history gets nothing.

**Evidence:** `wc -l state/ledger.csv` → 2 (header + 1 row from Feb 16)

**Impact:** No audit trail, no run history, no way for agents to query "what happened yesterday." The spine memory engine will need this.

### 2. HIGH — Outbox Is a Dumping Ground

The outbox has flat RESULT files at root AND structured subdirectories (proposals/, reports/, alerts/, operations/, finance/, calendar/, immich-reconcile/, briefing/, backup-calendar/, maker/). There's no documented rule about what goes where.

**Evidence:** 77 flat RESULT files + 10 ad-hoc files (retrospectives, CSVs, ICS files, a ZIP) sit alongside 11 subdirectories. An agent producing a report doesn't know: root? reports/? operations/? A new subdirectory?

**Impact:** Agents invent their own routing, which is exactly what happened with the communications audit (dropped in reports/ instead of proposals/).

### 3. HIGH — Write-Only Design, No Query Surface

Agents can WRITE proposals (`proposals.submit`) but the documented governance surfaces don't tell agents how to READ the mailroom. `proposals.list` exists as a capability but isn't mentioned in AGENTS.md, SESSION_PROTOCOL.md, or the governance brief.

**Evidence:** AGENTS.md mentions `proposals.submit` and `proposals.apply` but not `proposals.list`. An agent coordinating with another agent has no documented way to check "is there already a pending proposal for this?"

**Impact:** Multi-agent orchestration requires agents to read each other's proposals. Without this, agents will duplicate work or conflict.

### 4. HIGH — Proposal Contract Is Scattered Across 6 Files

The full proposal lifecycle is defined in:
1. `docs/governance/AGENT_GOVERNANCE_BRIEF.md` — when to use
2. `docs/governance/SESSION_PROTOCOL.md` — queue hygiene
3. `docs/core/PROPOSAL_FORMAT.md` — directory structure
4. `ops/bindings/proposals.lifecycle.yaml` — state machine, SLA, admission
5. `docs/governance/PROPOSAL_FLOW_QUICKSTART.md` — 3-line quickstart
6. `ops/plugins/proposals/QUICK_START.md` — plugin quickstart

No single file covers the complete contract. An agent must read all 6 to understand proposals.

**Impact:** Every new agent session partially understands proposals and gets something wrong (missing receipt, wrong action verb, no loop binding, status set incorrectly).

### 5. MEDIUM — Proposal Status Enum Not Canonical

Valid statuses across the codebase: `draft`, `pending`, `applied`, `superseded`, `draft_hold`, `read-only`, `invalid`. But `PROPOSAL_FORMAT.md` only mentions `pending` and `applied`. `proposals.lifecycle.yaml` has the full list. `SESSION_PROTOCOL.md` has a partial list.

**Evidence:** The communications audit proposal I created used `status: pending` (correct) but only because I copied from an existing proposal — the session protocol skill doesn't define valid statuses.

### 6. MEDIUM — Loop Binding Contradiction

`proposals-submit` script enforces mandatory loop binding (fails without one). But `PROPOSAL_FORMAT.md` line 90 says "Loop tracking is optional but recommended."

**Impact:** Agents reading the format doc think loops are optional, then get rejected at submit time.

### 7. MEDIUM — Inbox Queue Is Completely Unused

`inbox/queued/`, `inbox/running/`, `inbox/done/`, `inbox/failed/`, `inbox/parked/` — all empty. The watcher PID file exists (`state/agent-inbox.pid: 42445`) but there's no evidence the queue lanes have ever processed anything.

Additionally, `inbox/archived/` is documented in README.md but doesn't exist as a directory.

**Impact:** The inbox was designed as the dispatch model but proposals bypassed it entirely. Two competing models (inbox lanes vs. proposal folders) creates confusion about which is canonical.

### 8. LOW — Stale/Dead Subdirectories

- `maker/` — contains only `.gitkeep`, untouched since Feb 7
- `backup-calendar/` — single stale ICS file from Feb 21
- 13 orphaned RESULT files pre-dating the ledger (documented in `.orphan-reconciliation.md` but never cleaned up)

---

## What Works Well

Before fixing, acknowledge what's solid:

- **Proposal structure** — CP- naming, manifest + receipt + files/ is clean and consistent. All 16 proposals follow the pattern.
- **Alerts pipeline** — 206 alerts across 8 stacks, continuously firing, no stale entries.
- **Admission controller** — 5 mandatory checks on proposals.apply, no bypass. This is the strongest governance point.
- **Briefing pipeline** — Daily briefings generating to outbox/briefing/, fresh within 24h.
- **Loop scopes** — 312 scope files, healthy tracking, active loop governance.
- **Logs** — 21 log files, all active, zero errors in .err files.

---

## Fix Plan

### Phase 1: Consolidate the Proposal Contract (Day 1)

Create `docs/governance/PROPOSAL_LIFECYCLE_REFERENCE.md` — ONE file that covers:
- When to use proposals (single-agent vs multi-agent rules)
- Complete proposal creation procedure (CLI and manual)
- Directory structure with manifest schema
- Full status enum: `draft → pending → applied | superseded | draft_hold | read-only | invalid`
- Admission controller checks (all 5)
- Loop binding requirement (mandatory, not optional)
- Action verbs: `create | modify | delete` (plus aliases: `created→create`, `update|edit→modify`, `remove→delete`)
- SLA thresholds (pending 7d max, draft 14d max, archive after 3d)
- Archival procedure

Then update all 6 existing files to point to this reference instead of duplicating the contract.

### Phase 2: Fix the Outbox Routing Rules (Day 1)

Update `mailroom/README.md` with a clear routing table:

| What | Where | Who Writes |
|------|-------|-----------|
| Agent deliverables | `outbox/proposals/CP-*/files/` | Agents (via proposal flow) |
| Capability run results | `outbox/<run_key>__RESULT.md` | Watcher/capability system |
| Health alerts | `outbox/alerts/` | Alerting probe cycle |
| Daily briefings | `outbox/briefing/` | Briefing pipeline |
| Operations snapshots | `outbox/operations/` | Control plane |
| Finance queues | `outbox/finance/` | Finance agent |
| Immich reconciliation | `outbox/immich-reconcile/` | Immich agent |
| Calendar exports | `outbox/calendar/` | Calendar sync |

Anything not in this table does NOT belong in the outbox. New domain subdirectories require a governance entry.

### Phase 3: Fix the Ledger (Day 1-2)

Options:
1. **Recover** — backfill ledger from RESULT files and receipt timestamps
2. **Reset** — acknowledge the gap, start fresh with a migration note
3. **Replace** — if the ledger model is wrong for the spine memory engine, design the new schema now

Recommendation: Option 2 (reset with migration note). The spine memory engine will likely need a different schema anyway. Don't invest in recovering a format that's about to change.

### Phase 4: Surface `proposals.list` in Governance Docs (Day 1)

Add `proposals.list` to:
- AGENTS.md quick commands
- SESSION_PROTOCOL.md
- The new PROPOSAL_LIFECYCLE_REFERENCE.md
- The session protocol skill (ronny-session-protocol)

Agents need to be able to query "what's pending?" before submitting duplicate proposals.

### Phase 5: Resolve Inbox vs. Proposals Model (Week 1)

The inbox queue lanes and the proposal folders serve overlapping purposes. Decide:

**Option A:** Inbox is for automated/scheduled capability runs (watcher-dispatched). Proposals are for agent-submitted changes (human-reviewed). Both coexist, different purposes.

**Option B:** Deprecate inbox lanes. Everything goes through proposals. Watcher becomes a proposal generator.

Recommendation: Option A — the inbox was designed for automated dispatch (prompts → watcher → run → result), proposals were designed for agent coordination. They serve different flows. Document this distinction clearly.

### Phase 6: Clean Up Dead Weight (Day 2)

- Archive or delete `maker/` (unused since Feb 7)
- Archive `backup-calendar/` if superseded by `calendar/`
- Create `inbox/archived/` directory (documented in README but missing)
- Run `proposals.archive` to move old applied/superseded proposals to `.archived/`

---

## Priority for Multi-Agent Orchestration

If the immediate goal is multi-agent orchestration + spine memory engine, the critical path is:

1. **Phase 4 first** — agents must be able to READ proposals to coordinate
2. **Phase 1 second** — the proposal contract must be in one place so new agents don't get confused
3. **Phase 3 third** — the memory engine needs a working history layer (ledger or replacement)
4. **Phase 2/5/6** — hygiene, can happen in parallel

---

## Evidence Sources

- Outbox inventory: 560+ files, 109 MB total
- Proposals audit: 16 CP- folders, 100% structurally valid
- Ledger: 2 lines (header + 1 entry from Feb 16)
- Inbox lanes: all empty
- 6 governance files cross-referenced for proposal contract
- proposals-submit script (131 lines), proposals-apply script (917 lines)
- proposals.lifecycle.yaml (state machine, SLA, admission)
- 312 loop scope files, 17 gap claims
- 206 active alerts, 21 log files (zero errors)

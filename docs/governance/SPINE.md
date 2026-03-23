---
status: authoritative
owner: "@ronny"
last_verified: 2026-03-23
scope: spine-minimal-operating-contract
---

# SPINE.md - Minimal Operating Contract

This is the single canonical governance doc for daily single-operator use.
All other governance docs should either be generated artifacts or scoped deep-dive references.

## Startup

```bash
cd ~/code/agentic-spine
./bin/ops cap run session.v3.attach -- --allow-no-loop
```

## Daily Workflow

```bash
# Commit on main (intentional only)
OPS_GOVERNED_MAIN_OVERRIDE=1 git commit -m "..."

# Push on main (intentional only)
OPS_GOVERNED_MAIN_OVERRIDE=1 git push origin main
```

## V3 Operating Model (2026-03-23)

### Rule 1: Controller Lane
One controller terminal operates on `main`. The controller owns all shared authority surface mutations, loop lifecycle transitions, closeout propagation, worktree creation/pruning, and landing of worker branches. No other terminal may mutate shared authority surfaces directly.

The controller may use a governed worktree for large structural slices, then land back to `main`. The constraint is one owner, one integration lane, no parallel hotspot mutation.

### Rule 2: Worker Scope
Workers execute in worktrees or on remote systems with a declared, disjoint write scope. Workers must not touch shared hotspot surfaces. If a worker needs a hotspot mutation, it files a request back to the controller. Workers may be terminated or parked without data loss.

### Rule 3: Active WIP Cap
**Maximum 5 active loops.** When above cap: close, supersede, defer, or consolidate. "Open because nobody decided" is a policy violation. Planned loops older than 14 days without activity must be triaged.

### Rule 4: Shared Authority Hotspots (Controller-Only)
| Surface | Rule |
|---------|------|
| `ops/bindings/operational.gaps.yaml` | Controller-only. Future: migrate to SQLite. |
| Loop scope files | Controller owns lifecycle transitions. Workers may update own loop's `next_action` only. |
| `friction-queue.ndjson` | Controller-only. Workers use `friction.ingest`. |
| `gate-id-reservations.yaml` | Controller-only. |
| `path.claims.yaml` | Controller-only. |

### Rule 5: Closure
Work is done when runtime, control plane, bindings/projections, and residue all agree. Missing propagation must fail loudly (gate failure, verify failure, session attach block) instead of relying on operator memory.

### Rule 6: Boring Lane
`session.v3.attach` is the only entry. Main must be boring: 0 dirty, 0 untracked in governed paths, 0 stashes from other sessions, 0 ahead/behind. If not boring: stop, fix, then work.

## Execution Lane Bootstrap (Phase 2)

Create governed execution lanes instead of manual worktree setup:

```bash
# Create clean execution lane from origin/main
./bin/ops cap run session.execution.lane.bootstrap \
  --type <discovery|fix|landing|review|hotfix> \
  --branch <branch-name> \
  [--parent-loop <LOOP-ID>] \
  [--domain <domain>]

# Close lane when done
./bin/ops cap run session.execution.lane.closeout \
  --lane-id <LANE-ID> \
  --status <landed|deferred|abandoned|...>

# Scan for stale/floating lanes
./bin/ops cap run session.execution.lane.scan
```

**Lane types**:
- `discovery`: Read-only exploration, evidence-only writes
- `fix`: Bounded bug fix or gap closure, verify required
- `landing`: Merge approved changes to main, verify must pass
- `review`: Review code or proposals, no mutations
- `hotfix`: Emergency fix to main, requires incident ref

**What bootstrap guarantees**:
- Fresh worktree from current `origin/main`
- Clean branch (no collision with existing branches)
- Lane metadata stamped (type, created_at, status)
- Closeout checklist generated
- State tracked in `~/.runtime/spine/state/execution-lanes/`

See: `docs/governance/AGENT_EXECUTION_LANE_AUDIT_RECEIPT_20260319.md` for background.

## Verify

```bash
./bin/ops cap run verify.run -- fast
./bin/ops cap run verify.run -- domain <domain>
```

## Minimality Rules

1. One doc per concern: add sections to an existing canonical doc before creating a new file.
2. One script per concern: extend existing scripts with flags/subcommands instead of creating near-duplicates.
3. Delete legacy: `.legacy` copies are migration debt and must be removed once active scripts are in place.
4. One override path: use `OPS_GOVERNED_MAIN_OVERRIDE=1`; do not require multi-var metadata ceremony for routine local work.
5. One daily remote: `origin` is canonical for day-to-day workflow.

## Mailroom Boundary

Mailroom runtime state is **externalized** to `$SPINE_STATE` (canonical: `~/code/.runtime/spine/state/`).
The repo-local `mailroom/` directory is **forbidden** and enforced by D377/D396/D397.

All `mailroom/state/` paths in contracts are resolved at runtime by `spine_resolve_mailroom_path()` to the external state root. Do NOT create files under the repo-local `mailroom/` directory — use `$SPINE_STATE/` directly or rely on the path resolver.

Domain runtime data must live in domain runtime roots/services, not in mailroom state.

## First-Class Governance Features

### Session Entry Hook (Agent Admission Control)
**Path**: `.claude/hooks/session-entry-hook.sh` (372 lines)

Every agent that starts a Claude Code session in this repo is automatically enrolled in the governance system before executing a single command. The hook enforces:
- Worktree isolation (D140): rejects unidentified worktree sessions
- Terminal role validation: establishes agent role context
- Multi-agent detection: blocks conflicts (4-hour TTL)
- Dynamic governance brief: delivers current governance context
- Proposal queue gating: alerts if >5 pending proposals

This is the **first line of agent governance**. See: `docs/governance/DREAM_SYSTEM.md` for details.

### D399: Live External-State Enforcement
**Path**: `surfaces/verify/d399-microsoft-mint-customer-mailbox-canonical-lock.sh` (560 lines)

Unlike file-check gates, D399 makes **LIVE API calls to Microsoft** for a Mint-domain contract. It performs 14 live checks against Microsoft Exchange/Graph API to enforce consistency between declared contracts (`communications.providers.contract.yaml`) and live production state.

This is the current frontier of spine enforcement for domain-scoped live checks. It should run from Mint-domain verification and Mint-repo push paths, not as a Spine-global pre-push requirement on unrelated `agentic-spine` changes. See: `docs/governance/DREAM_SYSTEM.md` for details.

## Projection Metadata

<!-- ENTRY_SURFACE_GATE_METADATA_START -->
# ENTRY SURFACE GATE METADATA (generated)
entry_surface_gate_metadata: projection
source_registry: ops/bindings/gate.registry.yaml
registry_updated: 2026-03-22
gate_count_total: 411
gate_count_active: 111
gate_count_retired: 300
max_gate_id: D421
<!-- ENTRY_SURFACE_GATE_METADATA_END -->

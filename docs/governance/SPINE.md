---
status: authoritative
owner: "@ronny"
last_verified: 2026-04-07
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

## Governance Freeze

Until `2026-05-07`, no new gates, contracts, registries, bindings, governance docs, or loops may be created unless the change clearly removes more artifacts than it adds. Default to deletion, collapse, reuse, and direct execution over new control-plane surfaces.

**What session.v3.attach does:**
1. Cleans leaked ambient env vars (SPINE_ROOT, SPINE_CODE) from previous sessions
2. Runs context-aware main checkout healing (auto-restore generated drift, cleanup stale stashes, fast-forward main)
3. Cleans up stale/floating worktrees from previous sessions
4. Resolves current loop context (or allows adhoc with --allow-no-loop)
5. Compiles entry packet with friction snapshot
6. Emits session exports (SPINE_SESSION_ID, SPINE_LOOP_ID, etc.)

## Daily Workflow

```bash
# Root main stays usable and bounded.
./bin/ops cap run session.v3.attach -- --allow-no-loop

# Use a managed worktree when isolation helps.
./bin/ops cap run session.execution.lane.bootstrap \
  --type fix \
  --branch <branch-name> \
  --parent-loop <LOOP-ID>

# Controller-only exception on root main: clean-entry exact landing.
./bin/ops cap run git.stage.commit.scoped -- \
  --source-treeish <treeish-or-stash-ref> \
  --path <exact-file> \
  --message "..."

# Optional end-to-end exact-slice landing with push.
./bin/ops cap run git.stage.commit.scoped -- \
  --path <exact-file> \
  --message "..." \
  --push
```

## Adopted Interactive Repo Mutation Workflow

For controller-issued work packets that send a secondary terminal to mutate
governed spine repo paths under `ops/`, `bin/`, or `surfaces/`, the default
repo-local ceremony is:

```bash
./bin/ops cap run session.interactive.dispatch -- \
  --governed-repo-mutation \
  --summary "..." \
  --loop <LOOP-ID> \
  --governed-path ops/... \
  --first-command "..."
```

The target terminal pastes the emitted export lines and attach command, runs the
first command, then completes with:

```bash
./bin/ops cap run session.interactive.complete -- --run-key <RUN_KEY>
```

Missing completion is checked with:

```bash
./bin/ops cap run session.interactive.status -- --list-pending --governed-repo-mutations-only
```

Until the rollout has real signal, the next eligible task in this class must
use this ceremony. Re-measure with:

```bash
./bin/ops cap run session.interactive.status -- --governed-repo-mutation-summary
```

Re-measure is due after `3` real in-scope starts or `7` days from the rollout
anchor, whichever comes first.

This adoption is honest about scope. It does not force single-terminal work,
external editors, arbitrary Bash, machine-wide terminal behavior, domain files
outside governed paths, or autonomous transport into this ceremony.

## Execution Discipline

1. **Use governed capabilities, not raw shell.** If `./bin/ops cap list` shows a capability, use it. Raw bash/git/ssh is a last resort.
2. **Mutating work requires a loop.** No loop active for non-trivial changes? Create one with `loops.create` first. No floating WIP.
3. **Keep mutations bounded.** Use exact-slice landing on `main` when that is enough; use a worktree when you need isolation.
4. **Use scoped landing when helpful.** `git.stage.commit.scoped` remains the safest path for exact-slice landings on `main`.
6. **Shared root-lane mutation is blocking contention.** Multiple terminals are independent only when they do not share the same root checkout, git index, or protected hotspot surfaces. Separate managed worktrees are the normal parallel model.
7. **Verify after mutations.** After committing, run `./bin/ops cap run verify.run -- fast` to confirm no gates broke.
8. **Run git/worktree hygiene as an explicit maintenance pass.** Inventory with `python3 ./ops/plugins/core/lifecycle/bin/git-worktree-hygiene --brief`. Safe prune remains dry-run by default and only applies with `--apply`. Policy and operator notes live in `docs/governance/GIT_WORKTREE_HYGIENE.md`.

## V3 Operating Model (2026-03-27)

### Rule 1: Root Main Role
Root `main` is the controller-owned integration lane. It is for attach, review, exact-slice landings, loop lifecycle transitions, closeout propagation, worktree creation/pruning, and other protected hotspot actions. Root `main` is not a general mutation lane.

### Rule 2: Managed Mutation Lanes
Broad work, concurrent work, and anything that cannot be landed as one exact controller slice belong in managed worktrees. Separate managed worktrees are the normal parallel work model.

### Rule 3: Bounded Controller Landing
Prefer exact-slice landings on `main` when you want bounded mutation with explicit staging. Use a worktree when it materially helps.

### Rule 4: Blocking Shared-Lane Contention
Multiple terminals are independent only when they do not share the same root checkout, git index, or protected hotspot surfaces. Shared root-checkout or shared-index mutation is blocking contention, not parallel work.

### Rule 5: Worker Scope
Workers execute in managed worktrees or on remote systems with a declared, disjoint write scope. Workers must not touch shared hotspot surfaces directly. If a worker needs a hotspot mutation, it files the request back to the controller. Workers may be terminated or parked without data loss.

**Worker worktree sessions:** Worker worktrees should start through `session.v3.attach` as well. The attach surface resolves the active worktree, compiles the governed entry packet, and enforces the declared write scope. Downstream runtime extraction remains future work and is unrelated to this workflow rule.

### Rule 6: Active WIP Cap
**Maximum 5 active loops.** When above cap: close, supersede, defer, or consolidate. "Open because nobody decided" is a policy violation. Planned loops older than 14 days without activity must be triaged.

### Rule 7: Shared Authority Hotspots (Controller-Only)
| Surface | Rule |
|---------|------|
| `ops/bindings/operational.gaps.yaml` | Controller-only. Future: migrate to SQLite. |
| Loop scope files | Controller owns lifecycle transitions. Workers may update own loop's `next_action` only. |
| `friction-queue.ndjson` | Controller-only. Workers use `friction.ingest`. |
| `gate-id-reservations.yaml` | Controller-only. |
| `path.claims.yaml` | Controller-only. |

### Rule 8: Closure
Work is done when runtime, control plane, bindings/projections, and residue all agree. Missing propagation must fail loudly (gate failure, verify failure, session attach block) instead of relying on operator memory.

### Rule 9: Root Main Cleanliness At Attach
`session.v3.attach` is the only entry. It can auto-heal governed generated drift, stale cleanup-candidate stashes, fast-forward-safe main drift, and floating worktree residue.

**Auto-healed on attach:**
- Governed generated drift (docs projections, gate metadata) → restored from HEAD
- Stale cleanup-candidate stashes (branch merged, branch deleted, >72h old main stash) → archived and dropped
- Main behind origin/main (fast-forward only) → auto-pulled
- Floating worktrees (stale, abandoned) → cleanup warnings

**Blocks session attach:**
- Ungoverned dirty files in non-hotspot paths
- Untracked files anywhere in the repo
- Non-fast-forward divergence from origin/main
- Dirty files in session bootstrap paths (ops/plugins/core/session/, ops/lib/, bin/ops)

**Attach can tolerate governed hotspot recovery context while classifying work:**
- Dirty files in ops/bindings/*.yaml (contracts, gaps, registries)
- Dirty files in ops/commands/tests/*.sh (test files)
- Dirty files in ops/plugins/core/lifecycle/bin/* (lifecycle scripts)
- Dirty files in ops/plugins/core/lifecycle/tests/* (lifecycle tests)
- Dirty files in surfaces/verify/*.sh (gates)

That tolerance is not landing authority. Root `main` still returns to clean state unless the controller is in an explicit `staged_only` landing window for one exact slice.

## Bounded Work Fast Lane

Single-domain patches that meet all of the following criteria qualify for fast-lane mode,
which collapses ceremony to attach → do → receipt without loop/gap/disposition overhead:

**Criteria** (all must hold):
- Patches touch **≤ 5 files**
- All files are within **one domain**
- No shared authority hotspot mutations (Rule 7 surfaces: operational.gaps.yaml, loop scopes, friction-queue.ndjson, gate-id-reservations.yaml, path.claims.yaml)
- Domain already has CI governance (verify gate coverage)

**Usage**:
```bash
./bin/ops cap run session.v3.attach -- --fast-lane
# Make bounded fix, commit, verify — no loop required
```

**What fast-lane provides**:
- Session attach with lane=fix, no loop resolution
- `SPINE_FAST_LANE=1` exported for downstream guards
- Governed commit still required
- Verify still runs
- Receipt emitted (session_id, files_touched, domain, verify_result, commit_sha)

**What fast-lane omits**:
- Loop registration
- Gap filing
- Disposition ceremony
- Wave orchestration

**Hotspot guard**: If a fast-lane commit touches any Rule 7 surface, the commit is
rejected and the session must be re-attached with full ceremony (loop required).

Fast-lane reduces loop/gap ceremony. Use worktrees when they help; use exact-slice landing when they do not.

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
- State tracked in `~/code/.runtime/spine/state/execution-lanes/`

Historical note: the initial execution-lane rollout audit is retired from the active governance surface; this section is the current operating authority.

### Worktree Lifecycle Auto-Cleanup (Phase 3)

Session attach (`session.v3.attach`) automatically detects and cleans up floating worktrees:

**Cleanup triggers:**
- Lane state is `landed`, `abandoned`, `deferred` (terminal states)
- Worktree has been inactive for >14 days
- Branch backing the worktree has been deleted
- Branch has been merged to main

**Cleanup actions:**
- Archive worktree metadata to `~/code/.runtime/spine/state/execution-lanes/archive/`
- Remove worktree directory (if safe - no uncommitted work)
- Remove branch (if merged or explicitly abandoned)
- Update lane state to include cleanup timestamp

**Manual cleanup:**
```bash
# Scan for stale lanes and get recommendations
./bin/ops cap run session.execution.lane.scan

# Force cleanup of specific lane
./bin/ops cap run session.execution.lane.closeout \
  --lane-id <LANE-ID> \
  --status abandoned \
  --cleanup-worktree
```

This prevents worktree accumulation and ensures main checkout sessions start clean.

## Verify

```bash
./bin/ops cap run verify.run -- fast
./bin/ops cap run verify.run -- domain <domain>
```

## Remote Sync

- If a repo-owned implementation pass lands cleanly and verification is green,
  push it before starting the next implementation pass.
- If a session ends with local commits ahead of `origin/main`, push them or
  record the blocker explicitly.
- `new_truth` work should prefer a reviewable branch/worktree posture unless an
  exact bounded direct landing is explicitly chosen.
- Workflow discipline is enforced by the governed session, worktree, and verify surfaces named in this contract. Historical workflow-policy writeups now live under the archive boundary.

## Session Closeout

Run friction capabilities before ending a session with significant work:

```bash
# Surface friction from this session
./bin/ops cap run friction.queue.status

# Record failures or workarounds:
./bin/ops cap run friction.ingest -- \
  --loop-id LOOP-XXX \
  --capability <what-failed> \
  --expected "what should have happened" \
  --actual "what actually happened" \
  --severity <low|medium|high> \
  --auto-reconcile
```

Loop closeout ceremony:
```bash
./bin/ops cap run loop.closeout.finalize -- \
  --loop-id LOOP-XXX \
  --acceptance-matrix <path> \
  --disposition landed \
  --completion-level loop_complete \
  --propagation-evidence "..." \
  --owner "@ronny"
```

## Minimality Rules

1. One doc per concern: add sections to an existing canonical doc before creating a new file.
2. One script per concern: extend existing scripts with flags/subcommands instead of creating near-duplicates.
3. Delete legacy: `.legacy` copies are migration debt and must be removed once active scripts are in place.
4. Use `git.stage.commit.scoped` for exact-slice landings when you want bounded staging and push in one flow.
5. One daily remote: `origin` (Gitea) is canonical operational truth; `github` is publication-only.

## Consolidated Authority Notes

### Deprecated Terms

- Deprecated-term enforcement is folded into this file.
- Legacy repo token for drift and docs checks: `legacy-repo`.
- Deprecated-term mentions are non-blocking only in archive, certification, and explicit historical/planning surfaces.

### Lean Budget

- Thresholds:
  - `active_gates_max=120`
  - `blocking_fast_gates_max=25`
  - `verify_files_max=80`
  - `bindings_files_max=180`
  - `governance_docs_max=35`
  - `legacy_scripts_max=0`
- Required domain docs:
  - `aof`, `backup`, `communications`, `core`, `finance`, `home`, `immich`, `infra`, `loop_gap`, `media`, `microsoft`, `mint`, `n8n`, `observability`, `proxmox-network`, `rag`, `secrets`, `surveillance`, `tax-legal`, `workbench`
- Change budget:
  - `verify max_net_new=0`
  - `governance max_net_new=0`
  - `bindings max_net_new=0`
  - `gate_add_requires_retire_ratio=2`

### Policy Autotune

- Weekly cadence: Monday `09:10` in `America/New_York`.
- Rolling analysis window: `7` days.
- Guardrails:
  - `no_touch_gate_ids=D3,D62,D63,D124,D126,D127,D140`
  - `max_recommendations_per_week=2`
  - `max_policy_edits_per_week=2`
  - `require_human_apply=true`
  - `auto_propose_enabled=true`
- Tune targets:
  - `d48_behavior`
  - `core_mode_gate_membership`
  - `verify_route_domain_routing`
  - `check_cadence_friction`
- Proposal defaults:
  - `description_prefix=policy-autotune-weekly`
  - `loop_id=LOOP-INFRA-HARDWARE-PLANE-AUDIT-20260227`
  - reports under `$SPINE_STATE/policy-autotune/` and `$SPINE_OUTBOX/reports/policy-autotune/`
- Advisory thresholds:
  - `verify.core.run soak warn=180 minutes`
  - `stability.control.snapshot soak warn=120 minutes`
  - `rerun_per_commit_ratio warn=4.0`
  - `release_fail_rate_pct warn=20.0`
  - `queue_pending_warn=8`
  - `queue_pending_critical=12`
  - `pending_age_days_warn=7`
  - `pending_age_days_critical=14`
- AOF thresholds:
  - `gate_count warn=150 critical=200`
  - `cap_count warn=400 critical=600`
  - `open_gaps warn=5 critical=10`
  - `verify_pass_rate healthy_min_pct=90 min_sample_size=5`

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

This is the **first line of agent governance**. Daily operating authority stays in this contract; V3 finalization and March 25 closeout narratives remain repo-tracked history, not daily startup surfaces.

### D399: Live External-State Enforcement
**Path**: `surfaces/verify/d399-microsoft-mint-customer-mailbox-canonical-lock.sh` (560 lines)

Unlike file-check gates, D399 makes **LIVE API calls to Microsoft** for a Mint-domain contract. It performs 14 live checks against Microsoft Exchange/Graph API to enforce consistency between declared contracts (`communications.providers.contract.yaml`) and live production state.

This is the current frontier of spine enforcement for domain-scoped live checks. It should run from Mint-domain verification and Mint-repo push paths, not as a Spine-global pre-push requirement on unrelated `agentic-spine` changes. Historical deep-dive material is retired from the active governance surface.

## Projection Metadata

<!-- ENTRY_SURFACE_GATE_METADATA_START -->
# ENTRY SURFACE GATE METADATA (generated)
entry_surface_gate_metadata: projection
source_registry: ops/bindings/gate.registry.yaml
registry_updated: 2026-04-05
gate_count_total: 428
gate_count_active: 120
gate_count_retired: 298
max_gate_id: D428
<!-- ENTRY_SURFACE_GATE_METADATA_END -->

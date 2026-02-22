# Agentic System — Full Audit Report

**Date:** 2026-02-22
**Scope:** Every file in `/code` — agentic-spine, agentic-spine-apply, mint-modules, workbench, top-level
**Mode:** Read-only. Zero changes made.

---

## TL;DR — The 7 Systemic Problems

| # | Problem | Severity | Where |
|---|---------|----------|-------|
| 1 | **Hardcoded `/Users/ronnyworks` paths everywhere** — system is non-portable | CRITICAL | .mcp.json, agents.registry.yaml, CLAUDE.md, AGENTS.md (~150+ refs) |
| 2 | **149 drift gates run sequentially** — excessive pre-flight | HIGH | agentic-spine/surfaces/verify/ |
| 3 | **Stale worktrees accumulating** — agentic-spine-apply is 13 commits behind, orphaned git refs | HIGH | agentic-spine-apply/, agentic-spine-.worktrees/ |
| 4 | **Payment module half-implemented** — in-memory DB, no shared-auth, missing from deploy | HIGH | mint-modules/payment/ |
| 5 | **Competing loop/gap/lifecycle systems** — 3 plugins tracking the same work | MEDIUM | agentic-spine/ops/plugins/{loops,lifecycle,evidence} |
| 6 | **Two archive dirs in workbench** + 27MB of legacy ronny-ops imports | MEDIUM | workbench/.archive/ + workbench/archive/ |
| 7 | **Identity confusion** — "agentic-spine" vs "ronny-ops" vs "spine" vs "mint-os" | MEDIUM | Docs across all repos |

---

## REPO 1: agentic-spine (Core Governance)

### Confusion / Disconnects

- **F-SPINE-01**: `.brain/` path migration incomplete — `.claude/` dir still exists at root alongside `docs/brain/`. D46/D47 gates enforce split but ownership is fragmented.
  - *Files:* `.claude/settings.json`, `docs/brain/`, `ops/bindings/deprecated.terms.yaml`
  - *Action:* Complete migration; consolidate into `docs/brain/`

- **F-SPINE-02**: Verify lane terminology inconsistent — `verify.core.run`, `verify.domain.run`, `verify.pack.run`, `verify.route.recommend` all documented separately with no decision tree.
  - *Files:* `SPINE_SCAFFOLD.md`, `AGENTS.md`, `README.md`
  - *Action:* Consolidate into single `verify.run --scope <type>` or add VERIFY_FLOW.md decision tree

- **F-SPINE-03**: `ronny-ops` references not fully obsoleted — deprecated.terms.yaml has extensive allowlist for a dead monolith.
  - *Files:* `ops/bindings/deprecated.terms.yaml` (lines 54-93)
  - *Action:* Create SPINE_VS_WORKBENCH_AUTHORITY.md; move allowlist to workbench

- **F-SPINE-04**: Dual entry points — `bin/ops` vs `bin/cli/bin/spine` dispatch commands differently with unclear when-to-use-which.
  - *Files:* `bin/ops`, `bin/cli/bin/spine`
  - *Action:* Eliminate dual entry; make cli a thin wrapper or remove it

### Half-Implemented

- **F-SPINE-05**: Conflicts plugin is non-functional — empty capabilities, stub scripts.
  - *Files:* `ops/plugins/conflicts/` (8 files)
  - *Action:* Archive to `.archive/plugins/conflicts/`

- **F-SPINE-06**: ms-graph plugin has scripts but declares zero capabilities in MANIFEST.yaml.
  - *Files:* `ops/plugins/ms-graph/` (3 scripts)
  - *Action:* Register capabilities or archive

- **F-SPINE-07**: Wave orchestration semantics unclear — is it parallel batch? sequential pipeline? No docs.
  - *Files:* `ops/commands/wave.sh`, capabilities.yaml
  - *Action:* Document in WAVE_ORCHESTRATION.md or mark lifecycle: beta

- **F-SPINE-08**: Evidence plugin `spine.control.cycle` has no closeout/rollback/failure recovery documented.
  - *Files:* `ops/plugins/evidence/bin/spine-control`
  - *Action:* Document control loop contract or mark experimental

### Long Gate Checks

- **F-SPINE-09**: **149 individual drift gates** (D1-D149) run sequentially in `surfaces/verify/`. Full suite is a bottleneck.
  - *Files:* `surfaces/verify/d1-*.sh` through `surfaces/verify/d149-*.sh`
  - *Action:* Group into composite checks; tag as fast/medium/slow; create `verify.core.fast` for quick preflight

- **F-SPINE-10**: API precondition checking scattered across 3 places — `api-preconditions.sh`, individual capability `requires` fields, and inline checks in plugin scripts.
  - *Files:* `surfaces/verify/api-preconditions.sh`, `ops/capabilities.yaml`, various plugin scripts
  - *Action:* Consolidate into single `secrets-preconditions-check`

### Unnecessary Things

- **F-SPINE-11**: `ops/tools/legacy-freeze.sh` and `legacy-thaw.sh` — not wired into any capability.
  - *Action:* Archive to `.archive/ops/tools/`

- **F-SPINE-12**: Monolith plugin script names don't match capability names (`monolith-git-status` vs `monolith.git_status`). Missing `monolith-tree` script.
  - *Action:* Rename scripts to match capabilities 1:1

- **F-SPINE-13**: `capability_map.yaml` (74KB) is "auto-generated" but checked into git alongside `capabilities.yaml` (5870 lines). Dual registry.
  - *Files:* `ops/capabilities.yaml`, `ops/bindings/capability_map.yaml`
  - *Action:* Add capability_map.yaml to .gitignore; generate from capabilities.yaml via pre-commit hook

- **F-SPINE-14**: 26 test files in `surfaces/verify/tests/` not integrated into any CI or verify pipeline.
  - *Action:* Create `verify.gates.test-all` capability or archive

### Drift

- **F-SPINE-15**: Gate naming inconsistent — most follow `dNN-name.sh` but outliers: `drift-gate.sh`, `foundation-gate.sh`, `health-check.sh`, `monitoring_verify.sh`.
  - *Action:* Standardize all to `dNN-*` pattern or move utilities to `surfaces/lib/`

- **F-SPINE-16**: Docs hierarchy mixed — `docs/core/`, `docs/governance/`, `docs/brain/`, `docs/governance/domains/` with unclear ownership.
  - *Action:* Restructure: core/ = invariants, governance/ = policies, domains/ = domain-specific, brain/ = agent context

### Competing Systems

- **F-SPINE-17**: 5 verification lanes (`verify.core.run`, `.domain.run`, `.release.run`, `.pack.run`, `.route.recommend`) — operator must run meta-check first to pick one.
  - *Action:* Consolidate into single `verify.run --scope` with flag

- **F-SPINE-18**: Loops, gaps, and lifecycle are 3 separate plugins tracking overlapping work items.
  - *Files:* `ops/plugins/loops/`, `ops/plugins/lifecycle/`, `ops/bindings/operational.gaps.yaml`
  - *Action:* Unify into single `ops/plugins/work/` plugin

- **F-SPINE-19**: Multiple secret injection methods — `secrets.exec`, `secrets.set.interactive`, plus inline loading in scripts.
  - *Action:* Standardize on `secrets.exec`; deprecate alternatives

### Superseded

- **F-SPINE-20**: `ops/hooks/sync-agent-surfaces.sh` marked retired in AGENTS.md but still on disk.
  - *Action:* Archive to `.archive/hooks/`

- **F-SPINE-21**: PROPOSAL_FORMAT.md may not match current CP-* UUID scheme used in mailroom.
  - *Action:* Update to reflect current format

---

## REPO 2: agentic-spine-apply (Stale Worktree)

- **F-APPLY-01**: Entire directory is a git worktree, 13 commits behind main, 1 unmerged commit (`9584842`).
  - *Action:* Check if commit `9584842` is superseded by main's `dfd7af6` (D67 fix). If yes, `git worktree remove`. If no, cherry-pick to main then remove.

- **F-APPLY-02**: Git reports worktree path as prunable — path references broken due to VM mount vs `/Users/ronnyworks/` mismatch.
  - *Action:* Run `git worktree prune` after cleanup

- **F-APPLY-03**: Second worktree also exists: `agentic-spine-.worktrees/apply-cp-20260221-mobile-ledger-rerun/` — no documented purpose, stale refs.
  - *Action:* Verify merged status; remove if complete

---

## REPO 3: mint-modules (Business Modules)

### Critical (P1 — Blocking for Sharing)

- **F-MINT-01**: Payment module uses **in-memory repository** with explicit TODO: "Replace with Postgres adapter when DB write is ready."
  - *File:* `payment/src/services/payment-repository.ts` (lines 14-16)
  - *Action:* Implement Postgres adapter before any production traffic

- **F-MINT-02**: Payment module doesn't use `@mint-modules/shared-auth` — implements custom auth, breaking consistency with all 7 other modules.
  - *File:* `payment/package.json`
  - *Action:* Add shared-auth dependency

- **F-MINT-03**: Payment service **missing from deploy compose files** — module exists but can't be deployed via standard path.
  - *Files:* `deploy/docker-compose.staging.yml`, `deploy/docker-compose.prod.yml`
  - *Action:* Add payment service to both compose files

### Medium (P2)

- **F-MINT-04**: Payment module not listed in README.md module table (lists 7, payment is 8th).
  - *Action:* Add to README

- **F-MINT-05**: Pricing module uses ESM (`"type": "module"`) while all others are CommonJS.
  - *File:* `pricing/package.json`
  - *Action:* Standardize module type

- **F-MINT-06**: Port allocation inconsistency — all modules use 3xxx except payment at 4000. No documented rationale.
  - *Action:* Document port allocation strategy

- **F-MINT-07**: Multiple migration entry points — `scripts/db-bootstrap.sh` vs per-module `scripts/db-migrate.sh`.
  - *Action:* Clarify SSOT for migrations

### Archive Candidates

- **F-MINT-08**: WORKSPACE_PLAN.md dated 2026-02-04 says "PLAN ONLY" but implementation is complete.
  - *Action:* Archive

- **F-MINT-09**: MINT_NORMALIZATION_BACKLOG_20260222.md — all 23 items CLOSED.
  - *Action:* Archive to docs/ARCHIVE/COMPLETED/

- **F-MINT-10**: Completed worktree `.worktrees/orchestration/LOOP-MINT-SHIPPING-PHASE1-IMPLEMENT-20260212/G/` — ~5800 files duplicating codebase.
  - *Action:* Archive or delete if merged

---

## REPO 4: workbench (Tools / Agents / Infra)

- **F-BENCH-01**: **Two archive directories** — `.archive/` (544K, immutable) and `archive/` (27MB, active imports). Naming collision creates ambiguity.
  - *Action:* Rename `.archive/` → `.archive-immutable/` or consolidate

- **F-BENCH-02**: Immich MCP server SPEC.md exists with 10 tools defined but "Implementation pending."
  - *File:* `infra/compose/mcpjungle/servers/immich-photos/SPEC.md`
  - *Action:* Implement or move to PLANNED_MCP_SPEC.md

- **F-BENCH-03**: 3 deferred infrastructure dirs (homeassistant, immich, arr) — unpromoted from ronny-ops monolith with identical DEFERRED.md files.
  - *Action:* Promote to tracked status or move to archive with expiration

- **F-BENCH-04**: Legacy agents README (355 lines, 28 archived scripts) still references `~/ronny-ops/` paths.
  - *File:* `.archive/legacy-agents/README.md`
  - *Action:* Rename to ARCHIVE_README.md; rely on git history

- **F-BENCH-05**: MCP servers defined in two locations — MCPJungle configs AND agent-local tools. Overlap unclear (media-stack vs agents/media, firefly vs agents/finance).
  - *Action:* Document handoff: MCPJungle = remote stable, agent tools = local dev

- **F-BENCH-06**: `archive/ronny-ops-*` — 27MB of legacy monolith backups with no expiration date.
  - *Action:* Set explicit expiration in RETENTION.md

- **F-BENCH-07**: Quarantine dir has no README explaining why items were quarantined.
  - *File:* `quarantine/WORKBENCH_UNTRACKED_20260208-161550/`
  - *Action:* Add README with action plan

- **F-BENCH-08**: N8N workflow snapshots duplicated (40 files, 1.2MB).
  - *File:* `infra/compose/n8n/workflows/snapshots/20260216-112351/`
  - *Action:* Define retention policy; delete if unneeded

- **F-BENCH-09**: `bin/` symlinks use hardcoded `/Users/ronnyworks` — breaks on other machines.
  - *Action:* Move to dotfiles/zsh aliases or use relative paths

- **F-BENCH-10**: Half-written audit template with "XXX" placeholders still present.
  - *File:* `.archive/legacy-agents/ARCHIVE_AUDIT_ULTRATHINK.md`
  - *Action:* Delete or mark as template

---

## CROSS-REPO: Systemic Issues

### Portability (CRITICAL)

- **F-CROSS-01**: `/Users/ronnyworks` hardcoded in ~150+ files across all repos. MCP configs, agent registry, CLAUDE.md, AGENTS.md all use absolute paths.
  - *Key files:* `agentic-spine/.mcp.json`, `workbench/.mcp.json`, `agentic-spine/ops/bindings/agents.registry.yaml`, `CLAUDE.md`, `AGENTS.md`
  - *Action:* Replace with `$HOME/code/` or `~/code/` expansion throughout

### Identity

- **F-CROSS-02**: System called "agentic-spine", "ronny-ops" (legacy), "spine" (informal), "mint-os" (product). No canonical brand doc.
  - *Action:* Create IDENTITY.md establishing canonical names; update legacy refs

### Duplicate Configs

- **F-CROSS-03**: CLAUDE.md exists in 3 locations (main + 2 worktrees). Stale copies will confuse agents.
  - *Action:* Delete worktree copies; single source in main

- **F-CROSS-04**: .mcp.json exists in 4 locations with subtle differences.
  - *Action:* Consolidate; worktrees should inherit, not copy

### Boundary Clarity

- **F-CROSS-05**: Mint-agent has dual write scope — workbench AND mint-modules. Only cross-repo write coupling in the system.
  - *File:* `agents.registry.yaml` lines 296-297
  - *Action:* Document intent explicitly in contract

---

## What's Actually Good

Before cleanup, worth noting what's working well:

1. **Architecture is sound** — Spine (governance) / Workbench (tools) / Mint-modules (business) separation is correct
2. **Contract-driven design** — DNA contracts, boundary docs, governance gates are mature
3. **Mint-modules isolation** — zero code coupling to spine/workbench. Correct for sharing.
4. **Receipt/proof system** — every action produces evidence. Good audit trail.
5. **Mailroom externalization** — runtime state properly separated from tracked config
6. **Deprecated terms enforcement** — D5/D28/D29 gates actively block legacy coupling

The issues are **accumulated complexity and cleanup debt**, not architectural flaws.

---

## Summary Counts

| Category | Count | Critical | High | Medium | Low |
|----------|-------|----------|------|--------|-----|
| Confusion/Disconnects | 9 | 1 | 2 | 4 | 2 |
| Half-Implemented | 7 | 1 | 2 | 3 | 1 |
| Long Gate Checks | 2 | 0 | 1 | 1 | 0 |
| Unnecessary Things | 10 | 0 | 1 | 5 | 4 |
| Drift | 5 | 1 | 1 | 2 | 1 |
| Competing Systems | 4 | 0 | 1 | 3 | 0 |
| Superseded | 5 | 0 | 1 | 2 | 2 |
| Archive Candidates | 6 | 0 | 0 | 3 | 3 |
| Cross-Repo Systemic | 5 | 1 | 1 | 2 | 1 |
| **TOTAL** | **53** | **4** | **10** | **25** | **14** |

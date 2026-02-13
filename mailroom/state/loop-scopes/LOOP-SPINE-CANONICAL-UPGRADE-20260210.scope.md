---
status: active
owner: "@ronny"
last_verified: 2026-02-13
scope: loop-scope
loop_id: LOOP-SPINE-CANONICAL-UPGRADE-20260210
---

# Loop Scope: LOOP-SPINE-CANONICAL-UPGRADE-20260210

## Goal
Agent knowledge architecture that eliminates manual explaining:
- Layer 1 slash commands for operational workflows
- RAG wired via MCP for semantic discovery
- Self-documenting drift gates with proactive awareness
- Enhanced session context injection

## Problem Statement
Agents get rules (Layer 0: auto-injected governance brief) but not recipes (Layer 1: workflow commands). They fall into policy docs (Layer 2: governance/SSOTs) to figure out command syntax, which causes friction and repeated explanations.

The RAG VM (ai-consolidation, 207) is operational but disconnected — no MCP wire, zero agent usage.

Gates are reactive (explain after failure) not proactive (warn before violation).

## Success Criteria
- [x] 7 slash commands (/fix, /triage, /propose, /loop, /howto, /check, /gates) repo-governed and synced
- [ ] RAG VM wired via MCP adapter for natural agent queries (BLOCKED: VM unreachable)
- [x] Gate registry (ops/bindings/gate.registry.yaml) covering D1-D85 surface (D21 retired/reserved)
- [x] Drift gates include inline triage hints on failure
- [x] Session entry includes capability precondition hints and gate reference card
- [x] P5 domain agent bridge explicitly deferred with contract

## Phases

### P0: Scope Capture
- Map all agent knowledge surfaces (slash commands, RAG, gates, context)
- Identify friction points and gap analysis
- Define tier priorities and dependencies
- **Status:** complete
- **Evidence:** CP-20260213-141014 applied (commit ab89ef1)

### P1: Layer 1 Slash Commands
Create workflow slash commands with repo-governed source and sync-to-home execution surfaces.

**Source model:**
- Canonical source: repo path (e.g. `surfaces/commands/*.md`) — version-controlled, reviewable
- Sync target: `~/.claude/commands/` (Claude Code), with parity surfaces for Codex and OpenCode
- Sync mechanism: governed script (e.g. `ops/hooks/sync-slash-commands.sh`) — not manual copy
- Existing commands (/verify, /ctx, /gaps) migrated to repo source as part of P1

| Command | Purpose |
|---------|---------|
| `/fix` | Guided gap workflow: file → claim → verify → close with arg syntax |
| `/triage` | Drift gate failure: reads failing gate, explains violation, suggests fix |
| `/propose` | Multi-agent write flow: submit → edit manifest → check status |
| `/loop` | Loop lifecycle: when to loop vs gap, create → link gaps → close checklist |
| `/howto` | Decision router: "I need to..." → routes to correct workflow |
| `/check` | Proactive gate check: "Will this action violate any gates?" |
| `/gates` | Gate reference: list all gates, filter by category, show fix hints |

**Dependency:** None (can start immediately)
**DoD:**
- All 7 commands exist in repo source directory
- Sync script copies to `~/.claude/commands/` and parity surfaces
- Existing /verify, /ctx, /gaps migrated to repo source
- Each command is invocable and produces correct workflow guidance
**Evidence commands:**
- `ls surfaces/commands/*.md` — all 10 files present (7 new + 3 migrated)
- `./bin/ops cap run spine.verify` — PASS
**Risk:** Commands reference cap syntax that changes; mitigate by reading from capabilities.yaml at invocation time.
**Rollback:** Delete repo source files, restore `~/.claude/commands/` from git history.

### P2: RAG Integration
Wire the idle RAG VM into agent workflows:

- Create MCP server adapter wrapping `rag.anythingllm.ask`
- Wire adapter in Claude Code MCP settings
- Index P1 workflow recipes into AnythingLLM workspace
- Document agent query patterns in governance

**Dependency:** P1 (recipes must exist to index them)
**VM:** ai-consolidation (207), AnythingLLM :3002, Qdrant :6333
**DoD:**
- MCP adapter exists and is registered in capability map
- Claude Code can query RAG via MCP tool call
- P1 recipes indexed and returning relevant results
- Agent query patterns documented in governance
**Evidence commands:**
- `./bin/ops cap run rag.anythingllm.ask "how do I file a gap?"` — returns actionable answer
- `./bin/ops cap run spine.verify` — PASS
**Risk:** RAG VM may be unreachable or AnythingLLM workspace stale; mitigate by health-checking VM first.
**Rollback:** Remove MCP adapter config; RAG VM continues running independently.

### P3: Self-Documenting Gates
Make drift gates explain themselves on failure:

- Add `# TRIAGE:` header to all active gate scripts in `surfaces/verify/` (D1-D84 surface, D21 retired/reserved)
- Update `drift-gate.sh` to extract and display triage hints on failure
- Inline fix suggestions appear in `spine.verify` output only when a gate fails

**Dependency:** None (parallel with P1)
**Files affected:** `surfaces/verify/*.sh`, `surfaces/verify/drift-gate.sh`
**DoD:**
- All active D-numbered gate scripts contain `# TRIAGE:` header with fix hint
- `drift-gate.sh` extracts `TRIAGE:` line from script on failure and prints it
- `spine.verify` output contract unchanged for passing gates (no visual noise)
- Failing gates show triage hint inline after failure message
**Evidence commands:**
- `grep -c '# TRIAGE:' surfaces/verify/d*.sh` — matches active gate count
- `./bin/ops cap run spine.verify` — PASS (existing gates unaffected)
**Risk:** Triage header parsing changes drift-gate.sh output contract; mitigate by only showing hints on failure.
**Rollback:** Remove `# TRIAGE:` headers (no functional impact); revert drift-gate.sh extraction logic.

### P4: Enhanced Session Context
Improve what agents see at session start:

- Auto-inject capability precondition hints in governance brief or context
- Compact gate reference card (one-liners, generated from P6 registry)
- Surface bootstrap log output (avoid agents re-running ops status)

**Dependency:** P6 (gate reference generated from registry)
**DoD:**
- `generate-context.sh` includes gate reference card section from registry
- Precondition hints for common workflows visible at session entry
- Context is registry-driven (not hardcoded lists)
**Evidence commands:**
- `./docs/brain/generate-context.sh && grep -c 'D[0-9]' docs/brain/context.md` — gate lines present
- `./bin/ops cap run spine.verify` — PASS
**Risk:** Context bloat slows session entry; mitigate by keeping gate card compact (one-liners only).
**Rollback:** Revert generate-context.sh; session entry returns to current behavior.

### P5: Domain Agent Bridge (deferred)
Longer-term vision for domain expertise:

- Wire domain agents (media, n8n, finance) as MCP servers
- Enable `agent.route --query` to consult domain experts
- Eliminates "fighting for information" endgame

**Status:** explicitly deferred
**Dependency:** P2 (MCP patterns established from RAG wiring)
**Deferral contract:**
- P5 is NOT in scope for this loop execution
- No implementation work, no partial progress, no ambiguous "in progress"
- Will be picked up in a future loop after P2 MCP patterns are validated
- Gap filed as deferred with clear re-entry criteria
**Re-entry criteria:** P2 complete, MCP adapter pattern validated, domain agent registry entries exist in agents.registry.yaml

### P6: Gate Registry (self-updating meta-layer)
Create self-updating gate awareness infrastructure:

- Create `ops/bindings/gate.registry.yaml` with structured metadata for all active gates (D1-D84 surface, D21 retired/reserved)
- Define categories: path-hygiene, git-hygiene, ssot-hygiene, secrets-hygiene, doc-hygiene, loop-gap-hygiene, workbench-hygiene, infra-hygiene, agent-surface-hygiene, process-hygiene
- Each gate entry includes: id, name, category, description, check_script, fix_hint, severity
- Add D85 meta-gate to enforce registry ↔ script parity (fails if registry drifts from actual gate scripts)
- `/gates` and `/check` commands (P1) read from registry at runtime (always fresh)
- Gate template includes metadata block for new gates

**Dependency:** P3 (builds on triage header work)
**Files created:** `ops/bindings/gate.registry.yaml`, `surfaces/verify/d85-gate-registry-parity-lock.sh`
**DoD:**
- Registry YAML exists with entry for every active gate in drift-gate.sh
- D85 gate script exists and passes (registry ↔ script parity)
- `spine.verify` includes D85 in its run
- Capability map updated for any new capabilities
**Evidence commands:**
- `yq '.gates | length' ops/bindings/gate.registry.yaml` — matches active gate count
- `./bin/ops cap run spine.verify` — PASS (includes D85)
**Risk:** Registry drifts from gate scripts immediately after creation; D85 meta-gate prevents this.
**Rollback:** Remove registry YAML and D85 script; revert drift-gate.sh D85 invocation line.

## Gate Categories (for P6)

| Category | Description | Gates |
|----------|-------------|-------|
| path-hygiene | Path and filesystem constraints | D30, D31, D42, D46, D47 |
| git-hygiene | Git worktree, branch, and remote constraints | D48, D62, D64 |
| ssot-hygiene | SSOT and binding consistency | D54, D58, D59 |
| secrets-hygiene | Secrets and API constraints | D20, D25, D43, D55, D63, D70 |
| doc-hygiene | Documentation and indexing constraints | D16, D17, D27, D68, D84 |
| loop-gap-hygiene | Work registration and traceability | D34, D61, D75, D83 |
| workbench-hygiene | Workbench-specific constraints | D72, D73, D74, D77, D78, D79, D80 |
| infra-hygiene | Infrastructure and service binding checks | D22, D23, D24, D35, D50, D51, D52, D69 |
| agent-surface-hygiene | Agent entry and discovery surfaces | D26, D32, D49, D56, D65, D66 |
| process-hygiene | Operational processes and metadata | D29, D33, D38, D53, D60, D67, D71, D81, D82 |

**Notes:** D21 retired/reserved (merged into D56). D1-D15 are inline checks in drift-gate.sh. D78 listed under workbench-hygiene (primary owner). Full category assignment finalized during P6 implementation from actual gate script inspection.

## Original Scope (deferred to separate loops)
- CLAUDE.md duplication resolution (D46/D65) → separate loop
- SPINE_SCAFFOLD generation from contracts → separate loop
- Capability tag/index for discovery → separate loop

## Receipts
- P0: CP-20260213-141014 applied (commit ab89ef1) — CAP-20260213-145838__proposals.apply__Rny9m35317
- P1: 10 slash commands committed (commit 389be58) — GAP-OP-280 closed
- P3: 71 gate scripts + drift-gate.sh v2.8 (commit b78b787) — GAP-OP-282 closed
- P6: gate.registry.yaml + D85 parity gate (commit 1167031) — GAP-OP-285 closed
- P4: generate-context.sh gate card + hints (commit 0b855d8) — GAP-OP-283 closed
- P2: BLOCKED — RAG VM (207) unreachable (port 3002 timeout) — GAP-OP-281 closed as blocked
- P5: DEFERRED — deferral contract in scope, no implementation — GAP-OP-284 closed as deferred

## Notes
- RAG VM status: unreachable as of 2026-02-13 (port 3002 timeout)
- Slash commands: 10 repo-governed in surfaces/commands/, synced to ~/.claude/commands/
- Gate count: D1-D85 surface (D21 retired/reserved), all active gates have TRIAGE headers
- Gate registry: ops/bindings/gate.registry.yaml (85 gates, 11 categories, 81 fix hints)
- D85 meta-gate enforces registry ↔ script parity

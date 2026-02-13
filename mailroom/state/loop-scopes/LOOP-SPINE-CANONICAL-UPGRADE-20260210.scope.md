---
status: planned
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
- [ ] 5 workflow slash commands: /fix, /triage, /propose, /loop, /howto
- [ ] 2 proactive awareness commands: /check, /gates
- [ ] RAG VM wired via MCP adapter for natural agent queries
- [ ] Gate registry (ops/bindings/gate.registry.yaml) with all 84 gates
- [ ] Drift gates include inline triage hints on failure
- [ ] Session entry includes capability precondition hints

## Phases

### P0: Scope Capture (current)
- Map all agent knowledge surfaces (slash commands, RAG, gates, context)
- Identify friction points and gap analysis
- Define tier priorities and dependencies
- **Status:** in progress (parallel terminals)

### P1: Layer 1 Slash Commands
Create workflow slash commands in `~/.claude/commands/`:

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
**Files affected:** `~/.claude/commands/*.md`

### P2: RAG Integration
Wire the idle RAG VM into agent workflows:

- Create MCP server adapter wrapping `rag.anythingllm.ask`
- Wire adapter in Claude Code `.mcp.json` settings
- Index P1 workflow recipes into AnythingLLM workspace
- Document agent query patterns in governance

**Dependency:** P1 (recipes must exist to index them)
**VM:** ai-consolidation (207), AnythingLLM :3002, Qdrant :6333

### P3: Self-Documenting Gates
Make drift gates explain themselves on failure:

- Add `# TRIAGE:` header to all 84 gate scripts in `surfaces/verify/`
- Update `drift-gate.sh` to extract hints on failure
- Inline fix suggestions appear in `spine.verify` output

**Dependency:** None (parallel with P1)
**Files affected:** `surfaces/verify/*.sh`

### P4: Enhanced Session Context
Improve what agents see at session start:

- Auto-inject capability precondition hints in governance brief
- Compact D1-D84 gate reference card (one-liners, generated from registry)
- Surface bootstrap log output (avoid agents re-running ops status)

**Dependency:** P6 (gate reference generated from registry)

### P5: Domain Agent Bridge (future)
Longer-term vision for domain expertise:

- Wire domain agents (media, n8n, finance) as MCP servers
- Enable `agent.route --query` to consult domain experts
- Eliminates "fighting for information" endgame

**Dependency:** P2 (MCP patterns established from RAG wiring)

### P6: Gate Registry (self-updating meta-layer)
Create self-updating gate awareness infrastructure:

- Create `ops/bindings/gate.registry.yaml` with structured metadata for all 84 gates
- Define categories: path-hygiene, git-hygiene, ssot-hygiene, secrets-hygiene, doc-hygiene, loop-gap-hygiene, workbench-hygiene
- Each gate entry includes: id, name, category, description, check, fix_hint, affected_paths, severity
- Add D85 meta-gate to enforce registry ↔ script parity (fails if registry drifts)
- `/gates` and `/check` commands read from registry at runtime (always fresh)
- Gate template includes metadata block for new gates

**Dependency:** P3 (builds on triage header work)
**Files created:** `ops/bindings/gate.registry.yaml`, `surfaces/verify/d85-gate-registry-parity-lock.sh`
**Ensures:** System self-updates when new gates are added — impossible to add a gate without updating registry

## Gate Categories (for P6)

| Category | Description | Gates |
|----------|-------------|-------|
| path-hygiene | Path and filesystem constraints | D30, D31, D42, D46, D47, D78 |
| git-hygiene | Git worktree, branch, and remote constraints | D48, D61, D62, D64 |
| ssot-hygiene | SSOT and binding consistency | D54, D58, D59 |
| secrets-hygiene | Secrets and API constraints | D20, D25, D43, D55, D63, D70 |
| doc-hygiene | Documentation and indexing constraints | D16, D17, D68, D84 |
| loop-gap-hygiene | Work registration and traceability | D34, D61, D75, D83 |
| workbench-hygiene | Workbench-specific constraints | D77, D78, D79, D80 |

## Original Scope (deferred to separate loops)
- CLAUDE.md duplication resolution (D46/D65) → separate loop
- SPINE_SCAFFOLD generation from contracts → separate loop
- Capability tag/index for discovery → separate loop

## Receipts
- (link receipts when executed)

## Parallel Work Tracking
| Terminal | Loop | Current Work |
|----------|------|--------------|
| Terminal A | LOOP-SPINE-CANONICAL-UPGRADE | Scope capture, RAG analysis |
| Terminal B | LOOP-SPINE-CANONICAL-UPGRADE | Planning, loop scope update |
| Terminal C | LOOP-LOW-SEVERITY-CLOSEOUT-20260213 | ✓ Complete — gap closeout |

## Notes
- RAG VM status: 97 docs indexed, 85 eligible, parity OK, D68 enforced
- Existing slash commands: /verify, /ctx, /gaps (diagnostic only)
- Gate count: 84 drift gates, zero have triage headers, no registry exists
- Gate metadata currently scattered: inline in drift-gate.sh comments + separate scripts

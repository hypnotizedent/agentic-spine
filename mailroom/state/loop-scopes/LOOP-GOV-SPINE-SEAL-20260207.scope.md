# LOOP-GOV-SPINE-SEAL-20260207

> **Status:** open (blocked)
> **Blocked By:** LOOP-INFRA-VM-RESTRUCTURE-20260206
> **Owner:** @ronny
> **Created:** 2026-02-07
> **Severity:** medium

---

## Executive Summary

Add a governance certification system ("Spine Seal") to distinguish spine-native docs from legacy imports, and implement operational gap tracking so agents can log SSOT issues discovered during work without expanding loop scope.

---

## Origin Story

This loop was discovered during `LOOP-INFRA-VM-RESTRUCTURE-20260206`. While working on VM migrations:

1. An agent struggled to find Infisical config because `SERVICE_REGISTRY.yaml` had no entry
2. The agent guessed paths instead of consulting SSOT bindings (agent behavior issue)
3. `docker.compose.targets.yaml` was found to be stale (still lists migrated services under docker-host)
4. The agent fixed what was in-scope but had no canonical place to log out-of-scope gaps

This revealed two missing governance primitives:
- **Provenance tracking** — No way to distinguish "built under spine governance" from "imported from legacy"
- **Operational gap logging** — No place for agents to record SSOT issues discovered during work

---

## The Problem

### Current State

| Thing | Has It? | Location |
|-------|---------|----------|
| Extraction gap tracking | Yes | `docs/core/AGENTIC_GAP_MAP.md` |
| Doc header checks | Yes | `docs.lint` capability |
| "spine-native" terminology | Yes | Used informally in code |
| Provenance field in docs | No | — |
| Operational gap log | Yes | `ops/bindings/operational.gaps.yaml` |
| Doc certification status | No | — |

### Why It Matters

Agents can't tell which docs to trust completely vs treat with skepticism:
- Some docs were extracted from legacy and never fully verified
- Some docs were built under spine governance with receipts
- There's no visible signal of this difference

When agents discover SSOT issues during work, they either:
- Fix it inline (scope creep)
- Note it in external memory (invisible to other agents)
- Ignore it (problem persists)

---

## The Solution

### Phase 1: Operational Gap Tracking

Create `ops/bindings/operational.gaps.yaml`:

```yaml
# Operational gaps discovered during agent work
# NOT extraction gaps — runtime discoveries
version: 1
updated: "2026-02-07"

gaps:
  - id: GAP-OP-001
    discovered_by: "LOOP-INFRA-VM-RESTRUCTURE-20260206"
    discovered_at: "2026-02-07"
    type: stale-ssot
    doc: "ops/bindings/docker.compose.targets.yaml"
    description: "Still lists cloudflared, pihole, infisical under docker-host after migration"
    severity: low
    status: open
    fixed_in: null
```

This gives:
- Traceability (which loop discovered which gap)
- Audit trail (when found, is it fixed)
- Cleanup input (review periodically, create loops for open gaps)

### Phase 2: Doc Provenance Field

Add to doc headers:

```markdown
> **Status:** authoritative
> **Provenance:** spine-native  # NEW
> **Owner:** @ronny
> **Last verified:** 2026-02-07
```

Values:
| Provenance | Meaning |
|------------|---------|
| `spine-native` | Built under spine governance, receipts exist |
| `legacy-import` | Imported from pre-spine, not yet certified |
| `workbench-ref` | Reference from workbench, not spine-owned |

### Phase 3: D37 Drift Gate

Create `surfaces/verify/d37-doc-provenance-lock.sh`:

```bash
# D37: Doc provenance lock
# All docs in docs/governance + docs/core must have provenance field
```

This enforces the provenance field exists on canonical docs.

### Phase 4: Receipt Observations Section (Optional)

Enhance receipt format to allow agent observations:

```markdown
## Observations (Non-Blocking)

| Type | Description | Scope |
|------|-------------|-------|
| SSOT Gap | SERVICE_REGISTRY missing infisical entry | Fixed in-scope |
| Stale Doc | docker.compose.targets.yaml lists migrated services | Out of scope |
```

### Phase 5: Governance Gaps Capability

Create capability `governance.gaps.list` to:
- Show all open operational gaps
- Show docs missing provenance field
- Show docs with `legacy-import` provenance (candidates for certification)

---

## Agent Behavior Pattern

Document "How Agents Should Think About This":

```
When working on a loop and discovering an issue:

1. Is this REQUIRED for the current loop to succeed?
   - Yes → It's in scope, do it
   - No  → Continue to step 2

2. Is this BLOCKING the current loop?
   - Yes → Escalate to operator
   - No  → Continue to step 3

3. Capture the observation:
   - Add to operational.gaps.yaml (if SSOT issue)
   - Add to receipt notes (if behavioral observation)
   - Do NOT start implementing

4. Continue with current loop scope
```

---

## Success Criteria

| Criteria | Metric |
|----------|--------|
| Operational gaps are trackable | `operational.gaps.yaml` exists and has entries |
| Provenance field is enforced | D37 gate passes |
| Core docs have provenance | All `docs/core/*.md` have `Provenance:` header |
| Governance docs have provenance | All `docs/governance/*.md` have `Provenance:` header |
| Agent behavior is documented | Pattern is in a governance doc |
| Capability exists | `ops cap run governance.gaps.list` works |

---

## Non-Goals

- Do NOT certify all legacy docs in this loop (just add the field, mark as `legacy-import`)
- Do NOT refactor all receipts (observations section is optional enhancement)
- Do NOT create complex workflows (keep it lightweight)

---

## Phases

| Phase | Scope | Dependency | Status |
|-------|-------|------------|--------|
| P0 | Create `operational.gaps.yaml` with known gaps | None | **DONE** |
| P0.5 | Create `docs/brain/lessons/` with VM INFRA lessons | None | **DONE** |
| P1 | Add provenance field to `docs/core/*.md` | Blocked by VM INFRA | Pending |
| P2 | Add provenance field to `docs/governance/*.md` | P1 | Pending |
| P3 | Create D37 drift gate | P2 | Pending |
| P4 | Document agent behavior pattern | P3 | Pending |
| P5 | Create `governance.gaps.list` capability | P4 | Pending |
| P6 | Document Claude memory → spine routing pattern | P4 | Pending |

---

## Additional Concern: Claude Memory Routing

### The Problem

Claude Code stores agent memories in:
```
~/.claude/projects/-Users-ronnyworks-Code-agentic-spine/memory/MEMORY.md
```

This file contains valuable lessons (Proxmox, Cloudflare, Pi-hole gotchas) but:
- Lives **outside** the spine
- Only the originating terminal sees it
- Not auditable, not governed
- Lost context when terminal compacts
- Other agents can't learn from it

### The Solution

Route Claude memory content to spine-canonical locations:

| Memory Content | Destination |
|----------------|-------------|
| Hard-won lessons (how-to, gotchas) | `docs/brain/lessons/*.md` |
| SSOT gaps discovered | `ops/bindings/operational.gaps.yaml` |
| Manual TODOs | Loop `next_action` or new loop |
| Relocation state | Already in loop artifacts |

### Artifacts Created During This Discovery

| Artifact | Purpose |
|----------|---------|
| `ops/bindings/operational.gaps.yaml` | Tracks 3 gaps from VM INFRA work |
| `docs/brain/lessons/VM_INFRA_LESSONS.md` | Canonicalized Claude memory content |

### Phase Addition

Add **P6** to this loop:
- Document the "memory → spine" routing pattern
- Create guidance for agents on where to persist learnings
- Consider: should receipts have a "lessons" section?

---

## Evidence / Context

- Conversation with Opus 4.5 on 2026-02-07 (this terminal session)
- LOOP-INFRA-VM-RESTRUCTURE-20260206 work (parallel terminals)
- Agent observation: "docker.compose.targets.yaml is stale"
- Agent observation: "SERVICE_REGISTRY.yaml had no infisical entry"
- Existing gap map: `docs/core/AGENTIC_GAP_MAP.md`
- Existing doc lint: `ops/plugins/docs/bin/docs-lint`
- Claude memory file: `~/.claude/projects/.../memory/MEMORY.md`
- New artifacts:
  - `ops/bindings/operational.gaps.yaml` (created)
  - `docs/brain/lessons/VM_INFRA_LESSONS.md` (created)

---

## Key Insight

> **Observations during work are valuable. Acting on them during work is the trap.**
>
> Capture → Complete → Review → Decide → Loop (or don't)

This loop exists because the observation was captured correctly — noted but not acted on mid-stream.

---

_Scope document created by: Opus 4.5_
_Created: 2026-02-07_

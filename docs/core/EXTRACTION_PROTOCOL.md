# Extraction Protocol (Canonical)

> **Status:** authoritative
> **Last verified:** 2026-02-04

Goal: Extract capabilities from legacy repos without importing runtime smells.

## Hard Rules

1. **Authority stays in agentic-spine.** No ronny-ops runtime dependency.
2. **All capabilities must be runnable via:** `./bin/ops cap run <cap>`
3. **Any capability touching an external API MUST declare:**
   ```yaml
   requires:
     - secrets.binding
     - secrets.auth.status
     - secrets.projects.status
   ```
   (enforced by `.requires[]` framework + drift gates)
4. **Every run produces a receipt.** No exceptions.

## Move A — Doc-only Snapshot

**Use when:** The legacy implementation is tangled (state/, receipts/, launchd, caches, multiple entrypoints).

**Deliverable:**
- `docs/core/<CAPABILITY>_LEGACY_SNAPSHOT.md`

**Contains:**
- What exists in the legacy repo
- What's trusted vs what's unsafe
- What to extract later (if anything)
- No code changes beyond docs

**Example:** A complex backup system with multiple cron jobs, state files, and hardcoded paths → snapshot first, extract later.

## Move B — Wrap-only Capability

**Use when:** There is a single clean command/API surface.

**Deliverable:**
- `ops/plugins/<name>/bin/<cap-script>`
- Capability entry in `ops/capabilities.yaml`
- Receipts prove it runs

**Rules:**
- No legacy scripts copied
- No hidden runtime roots
- No shelling into ronny-ops
- No reading ronny-ops files

**Example:** `cloudflare.status` — calls Cloudflare API directly, no legacy wrapper.

## No Third Move

If it doesn't fit Move A or Move B, it's not ready to extract. Document it and wait.

## Extraction Order (Recommended)

1. `ssh.target.status` — Read-only connectivity check (no API)
2. `docker.compose.status` — Read-only container state
3. `backup.status` — Likely Move A first (doc-only)
4. `deploy.status` — Likely Move A first (doc-only)

## Trace Gate (Mandatory)

Before marking any extraction complete, run the trace gate:

1. **Path scan** — verify no conflicting path references:
   ```bash
   rg -n "(ronny-ops|~/code/workbench|workbench|infrastructure/docs)" docs ops surfaces bin \
     -g'!receipts/**' -g'!mailroom/outbox/**'
   ```
   - **Allowed:** WORKBENCH_TOOLING_INDEX.md
   - **Historical:** docs/legacy/**, docs/governance/_audits/**
   - **Conflict:** any other location (must resolve)

2. **Lint verification:**
   ```bash
   ./bin/ops cap run docs.lint
   ./bin/ops cap run spine.verify
   ```

3. **Document in mailroom** — if the extraction touches governance docs, create a mailroom item with the trace matrix.

Workbench paths live only in WORKBENCH_TOOLING_INDEX.md. All other references are conflicts.

## Drift Gate Pattern

After extraction, consider adding a drift gate (D18, D19, etc.) if the capability:
- Touches an external surface (API, remote host)
- Could leak secrets or paths
- Has legacy markers that could creep back

---

# Service Extraction (Infrastructure)

The above sections cover **capability extraction** (code/scripts). This section covers **service extraction** (containers, stacks, infrastructure).

## Classification

Before extracting any service, classify it:

| Type | Criteria | Examples |
|------|----------|----------|
| **Utility** | 1-2 containers, no dedicated docs, just runs | Vaultwarden, Pi-hole, Immich, HomeAssistant |
| **Stack** | 3-10 containers, needs lessons/runbook, has dependencies | Media-stack, Observability, Automation |
| **Pillar** | 10+ containers OR business domain OR separate lifecycle | mint-os, Finance |

## Decision Tree

```
Q1: How many services/containers?
    1-2     → UTILITY
    3-10    → STACK
    10+     → PILLAR

Q2: Does it have its own release lifecycle?
    No      → UTILITY or STACK
    Yes     → PILLAR (consider separate repo)

Q3: How much documentation needed?
    Just config         → UTILITY
    Lessons + runbook   → STACK
    Architecture docs   → PILLAR
```

## Requirements by Type

### Utility (Simple Service)

**Creates:**
- Entry in `docs/governance/SERVICE_REGISTRY.yaml`
- Entry in `docs/governance/STACK_REGISTRY.yaml` (compose location)
- Entry in `ops/bindings/services.health.yaml` (health check)
- Entry in `ops/bindings/backup.inventory.yaml` (if stateful)

**Does NOT create:**
- Dedicated folder under `docs/`
- Dedicated binding file
- Separate documentation

**Rationale:** Simple services don't need sprawl. Registry entries are sufficient.

### Stack (Multi-Service)

**Creates:**
- All utility requirements (registry entries)
- `ops/bindings/<stack>.binding.yaml` — stack-specific config
- `docs/brain/lessons/<STACK>_LESSONS.md` — hard-won knowledge
- Loop in `mailroom/state/loop-scopes/` — extraction tracking

**Does NOT create:**
- Dedicated folder under `docs/governance/`
- Multiple binding files for same stack

**Rationale:** Stacks need some documentation but shouldn't sprawl into dedicated folders.

### Pillar (Business Domain)

**Creates:**
- All stack requirements
- `docs/pillars/<pillar>/README.md` — overview
- `docs/pillars/<pillar>/ARCHITECTURE.md` — technical design
- `docs/pillars/<pillar>/EXTRACTION_STATUS.md` — progress tracking
- Multiple loops for phased extraction

**Consider:**
- Separate repo if >50 files or independent release cycle

**Rationale:** Pillars are complex enough to warrant dedicated structure.

## Admission Checklists

### Utility Checklist

Before marking extraction complete:

- [ ] Entry in SERVICE_REGISTRY.yaml
- [ ] Entry in STACK_REGISTRY.yaml (compose location)
- [ ] Health check defined
- [ ] Backup target defined (if stateful)
- [ ] No dedicated folder created
- [ ] `./bin/ops cap run spine.verify` passes

### Stack Checklist

Before marking extraction complete:

- [ ] All services in SERVICE_REGISTRY.yaml
- [ ] Compose files in STACK_REGISTRY.yaml
- [ ] Binding file: `ops/bindings/<stack>.binding.yaml`
- [ ] Lessons file: `docs/brain/lessons/<STACK>_LESSONS.md`
- [ ] Loop scope in `mailroom/state/loop-scopes/`
- [ ] No `docs/<stack>/` folder (use brain/lessons)
- [ ] `./bin/ops cap run spine.verify` passes

### Pillar Checklist

Before marking extraction complete:

- [ ] Dedicated folder: `docs/pillars/<pillar>/`
- [ ] README.md with overview
- [ ] ARCHITECTURE.md with technical design
- [ ] EXTRACTION_STATUS.md tracking progress
- [ ] All services in registries
- [ ] All binding files created
- [ ] All loops documented
- [ ] Consider: separate repo needed?
- [ ] `./bin/ops cap run spine.verify` passes

## Anti-Patterns

| Don't | Why | Instead |
|-------|-----|---------|
| Create `docs/<service>/` for utilities | Sprawl | Use registries only |
| Create multiple binding files per stack | Fragmentation | One `<stack>.binding.yaml` |
| Skip registry entries | Invisible to agents | Always update registries first |
| Extract without classification | No pattern | Ask: utility, stack, or pillar? |
| Create folder before classifying | Premature structure | Classify first, structure second |

## Cross-References

| Document | Purpose |
|----------|---------|
| `docs/core/AGENTIC_GAP_MAP.md` | Tracks extraction coverage |
| `docs/governance/SERVICE_REGISTRY.yaml` | Service locations |
| `docs/governance/STACK_REGISTRY.yaml` | Compose file authority |
| `mailroom/state/INFRA_MASTER_PLAN.md` | VM architecture roadmap |

# L1/L2/L3 Product Authority Classification Audit

- **Date:** 2026-04-08
- **Loop:** LOOP-ONE-WAY-20260408
- **Type:** research (read-only)
- **Posture:** no mutations performed
- **Revision:** v2 — corrected after quantitative review

---

## Situation

The operator membrane is converged (entry, state, health, dispatch all work through `ops`). File count is no longer the problem. The remaining monolith is **authority concentration**: spine surfaces still encode product-specific verification topology, gate definitions, domain metadata, and product code/contracts.

The spine-lite pass 2 (commit `113da10b`, 2026-04-07) deleted `agents.registry.yaml`, `terminal.worker.catalog.yaml`, and the dispatch generator — but left `routing.dispatch.yaml` in place as a 734-route **orphaned projection**. This means the dispatch file is no longer regenerable from living sources and must be treated as stale, not as evidence of live authority.

The actual governed authority that still carries product truth is smaller and more specific than the dispatch file suggests.

---

## Decision Rule

For each file or file family, apply mechanically:

1. If Mint disappeared tomorrow, would the spine still need this? If no -> not L1.
2. If media/home/finance/communications disappeared tomorrow, would the spine still need this? If no -> not L1.
3. Is this generic orchestration infrastructure, or product/domain truth wearing infra clothes? If the latter -> not L1.

---

## Working Definitions

### L1 — Spine Authority
Generic control-plane truth only: wave/dispatch/ack/collect/close, loop/gap lifecycle, run keys, receipts, evidence plumbing, terminal/session/context identity, generic scheduler plumbing, generic transport/SSH/secrets exec/runtime paths, generic recovery/retry, generic verify engine and gate runner, generic observability/telemetry.

L1 must NOT: name product scripts, encode product topology, encode product policy, encode product workflows, gate on product-specific success criteria.

### L2 — Shared Adapters
Reusable cross-product adapters. A file is L2 only if at least 2 products depend on it, or it models an external system boundary reused across products. If only one product uses it, it is L3.

### L3 — Product
Product commands, workflows, routing truth, verify suites, scheduler/intake logic, bindings/policies/topology, data/entity/business truth.

---

## Three-Class Distinction

This audit distinguishes three kinds of surfaces. Previous pass conflated them.

### 1. Governed Registry Truth (live root authority)
Files that are hand-maintained, authoritative, and drive spine behavior:
- `ops/capabilities.yaml` — **63 total entries** (8 product-domain, 6 compat aliases, 49 core/infra/shared)
- `ops/bindings/gate.execution.topology.yaml` — domain_metadata + gate_assignments + release_sequence
- `ops/bindings/gate.registry.yaml` — gate definitions

### 2. Orphaned Projections (stale, generated from deleted sources)
- `ops/bindings/routing.dispatch.yaml` — **734 routes**, generated from `capabilities.yaml` + `agents.registry.yaml` + `terminal.worker.catalog.yaml`. Generator (`gen-terminal-worker-runtime-v2.py`) and 2 of 3 sources deleted in spine-lite pass 2 (2026-04-07). This file is **not regenerable** and its route counts are not evidence of live authority.

### 3. Product Code and Contracts (live, but product-owned truth in spine tree)
- `ops/plugins/domains/` — product scripts and runtime libraries
- `ops/bindings/domains/` — product-specific contract YAML files

---

## Inventory Summary

### capabilities.yaml — Exact Breakdown (63 entries)

| Classification | Count | Entries |
|---|---|---|
| L1 core engine | 8 | session.v3.attach, spine.verify, stability.control.snapshot, verify.engine.run, verify.engine.honesty, verify.pack.list, verify.pack.run, verify.run |
| L1/L2 infra | 21 | infra.hypervisor.identity, infra.placement.policy, infra.proxmox.guest.{control,status}, infra.proxmox.host.{control,status}, infra.proxmox.node_path.migrate, infra.proxmox.power.{control,status}, infra.proxmox.storage.{bootpair.status,slot.inventory}, infra.relocation.{parity,preflight}, infra.storage.audit.snapshot, infra.vm.{bootstrap,intake.scaffold,provision,ready.status}, operator.storage.surface.sync, services.health.status, ssh.target.status, host.claude.entrypoint.status |
| L2 secrets | 3 | secrets.auth.status, secrets.binding, secrets.projects.status |
| L2 observability | 4 | automation.stack.latency.status, gitea.status, infra.core.slo.status, observability.stack.status |
| L2 network | 4 | cloudflare.inventory.sync, network.home.unifi.clients.snapshot, network.unifi.clients.snapshot, tailscale.acl.validate |
| L2 backup | 1 | backup.status |
| L2 microsoft adapter | 6 | microsoft.mail.{send,draft.create,draft.update}, microsoft.calendar.{create,update,rsvp} |
| **L3 product** | **8** | calendar.external.secrets.status, calendar.ha.snapshot.build, finance.stack.status, immich.ingest.watch, immich.status, media.api.resolve, media.content.snapshot.refresh, n8n.infra.health.quick |
| Compat aliases | 2 | verify.core.run, verify.fast (nodes.status + infra.proxmox.maintenance.{precheck,shutdown,startup} subtracted 2026-04-26) |
| **Mint entries** | **0** | All mint routes in routing.dispatch.yaml came from the now-deleted agents.registry.yaml |

**Key finding:** capabilities.yaml is 87% L1/L2 infrastructure. Only 8 of 63 entries are product-domain. Mint has zero entries. The "~120 product capabilities" claim from the v1 audit was wrong — it counted generated dispatch routes, not governed registry entries.

### routing.dispatch.yaml — Orphaned Projection (734 routes)

| Metric | Value |
|---|---|
| Total routes | 734 |
| Routes from capabilities.yaml (live) | 63 |
| Routes from deleted agents.registry.yaml | ~400+ |
| Routes from deleted terminal.worker.catalog.yaml | ~270+ |
| Generator script | deleted (gen-terminal-worker-runtime-v2.py) |
| Regenerable | **no** |

**This file is stale. It is not a reliable indicator of authority concentration.** It should be handled as cleanup, not as an extraction target. The product routes it contains are ghosts of authority that was already deleted.

### gate.execution.topology.yaml — Product Domain Metadata (live authority)

| Domain | Layer declared | gate_count | Primary gates | Secondary mentions |
|---|---|---|---|---|
| mint | L3_product_runtime | 8 | D225,D226,D236,D382,D390,D393,D394,D395 | D235,D260,D290,D389,D391,D399 |
| communications | L3_product_runtime | 13 | D147,D197,D199,D203,D204,D206,D209,D216,D218,D219,D233,D260,D383 | D148,D290,D399 |
| media | L3_product_runtime | 6 | D106,D224,D408,D409,D417,D419 | D384 |
| home | L3_product_runtime | 3 | (secondary only) | D139,D199,D206 |
| finance | L3_product_runtime | 1 | D380 | — |
| immich | L3_product_runtime | 0 | — | D148 |
| n8n | L3_product_runtime | 0 | — | D148 |
| surveillance | L3_product_runtime | 1 | D351 | — |
| tax-legal | L3_product_runtime | 1 | D379 | — |

**Product domain_metadata blocks in gate.execution.topology.yaml are live authority encoding product topology inside spine.** This is the real authority concentration for verification governance.

### Product Code and Contracts in Spine Tree

| Surface | Files | Products |
|---|---|---|
| `ops/plugins/domains/mint/` | 28 bin + 15 lib + 1 contract | mint |
| `ops/plugins/domains/communications/` | 3 bin + 1 lib | communications |
| `ops/plugins/domains/calendar/` | 4 bin + 1 lib | calendar (comms) |
| `ops/plugins/domains/media/` | 20+ bin | media |
| `ops/plugins/domains/home/` | 5 bin | home |
| `ops/plugins/domains/finance/` | 2 bin | finance |
| `ops/plugins/domains/immich/` | 5 bin | immich |
| `ops/plugins/domains/n8n/` | 2 bin | n8n |
| `ops/plugins/domains/inbox-shield/` | — | communications |
| `ops/plugins/domains/surveillance/` | — | surveillance |
| `ops/plugins/domains/taxlegal/` | — | tax-legal |
| `ops/bindings/domains/media/` | 23 contracts | media |
| `ops/bindings/domains/communications/` | 13 contracts | communications |
| `ops/bindings/domains/mint.bundle.yaml` | 1 bundle | mint |

**This is the bulk of the product truth in spine** — not capabilities.yaml, and not routing.dispatch.yaml.

### Product Verify Surfaces in Spine

| Product | Verify surfaces on disk |
|---|---|
| mint/comms | d216 (mintprints DNS), d218 (mintprints.co DNS), d219 (hantash DNS), d222 (quote alert boundary), d233 (mail archiver storage), d392 (mail policy), d399 (customer mailbox) |
| media | d107 (NFS mount), d257 (capacity guard) |
| mint (referenced but missing) | d225-, d226-, d227-, d241-d250 (topology references, no scripts on disk) |

---

## File-by-File Classification

### Governed Registries (need splitting)

| Path | Current state | Product truth embedded | Action | Rationale |
|---|---|---|---|---|
| `ops/capabilities.yaml` | 63 entries, 8 product | 8 L3 caps (calendar, media, finance, immich, n8n) | split — extract 8 product entries | Small extraction. 0 mint entries — mint is already gone from capabilities. |
| `ops/bindings/gate.execution.topology.yaml` | 20 domain_metadata blocks | 9 L3 product domains (mint, comms, media, home, finance, immich, n8n, surveillance, tax-legal) | split — extract product domain_metadata | This is where product topology lives. |
| `ops/bindings/gate.registry.yaml` | ~115 gate definitions | ~50 product-primary gates | split — extract product gate definitions | Product gates carry product health policy. |

### Orphaned Projection (cleanup, not extraction)

| Path | Current state | Action | Rationale |
|---|---|---|---|
| `ops/bindings/routing.dispatch.yaml` | 734 stale routes, no generator | regenerate or retire | Generator and 2/3 sources deleted. Cannot be regenerated from living sources. Must either be rebuilt against current capabilities.yaml only (would shrink to ~63 routes) or retired as a dead artifact. |

### Product Code in Spine (move to L3)

| Path | Product | Truth type | Action |
|---|---|---|---|
| `ops/plugins/domains/mint/bin/*` (28 scripts) | mint | product workflows | extract to mint-modules |
| `ops/plugins/domains/mint/lib/*` (15 Python modules) | mint | product runtime | extract to mint-modules |
| `ops/plugins/domains/mint/contracts/mint.runtime.boundary.yaml` | mint | product contract | extract |
| `ops/plugins/domains/communications/bin/*` (3 scripts) | comms | product workflows | extract |
| `ops/plugins/domains/communications/lib/eml_import.py` | comms | product runtime | extract |
| `ops/plugins/domains/calendar/bin/*` (4 scripts) | calendar | product workflows | extract |
| `ops/plugins/domains/calendar/lib/calendar_runtime_paths.py` | calendar | product runtime | extract |
| `ops/plugins/domains/media/bin/*` (20+ scripts) | media | product workflows | extract |
| `ops/plugins/domains/home/bin/*` (5 scripts) | home | product workflows | extract |
| `ops/plugins/domains/finance/bin/*` (2 scripts) | finance | product workflows | extract |
| `ops/plugins/domains/immich/bin/*` (5 scripts) | immich | product workflows | extract |
| `ops/plugins/domains/n8n/bin/*` (2 scripts) | n8n | product workflows | extract |
| `ops/plugins/domains/inbox-shield/` | comms | product workflows | extract |
| `ops/plugins/domains/surveillance/` | surveillance | product workflows | extract |
| `ops/plugins/domains/taxlegal/` | tax-legal | product workflows | extract |

### Product Contracts in Spine (move to L3)

| Path | Product | Files | Action |
|---|---|---|---|
| `ops/bindings/domains/media/*` | media | 23 contracts | extract |
| `ops/bindings/domains/communications/*` | comms | 13 contracts | extract |
| `ops/bindings/domains/mint.bundle.yaml` | mint | 1 bundle | extract |
| `ops/bindings/vpn.provider.yaml` | media | 1 binding (single-product) | extract |

### Product Verify Surfaces (move to L3)

| Surface | Product | Action |
|---|---|---|
| `surfaces/verify/d216-mintprints-mail-dns-parity-lock.sh` | mint/comms | extract |
| `surfaces/verify/d218-mintprints-co-mail-dns-parity-lock.sh` | mint/comms | extract |
| `surfaces/verify/d219-hantash-mail-dns-parity-lock.sh` | comms | extract |
| `surfaces/verify/d222-quote-alert-provider-boundary-lock.sh` | mint | extract |
| `surfaces/verify/d233-communications-mail-archiver-nonboot-storage-lock.sh` | comms | extract |
| `surfaces/verify/d392-domain-mail-policy-hygiene-lock.sh` | mint/comms | extract |
| `surfaces/verify/d399-microsoft-mint-customer-mailbox-canonical-lock.sh` | mint | extract |
| `surfaces/verify/d107-media-nfs-mount-lock.sh` | media | extract |
| `surfaces/verify/d257-media-capacity-guard-lock.sh` | media | extract |

### L2 Shared Adapters (keep in spine)

| Path | Products served | Rationale |
|---|---|---|
| `ops/plugins/providers/microsoft/` | comms + mint + calendar | Genuinely multi-product Microsoft Graph adapter |
| `ops/plugins/infra/secrets/` | ALL | Shared secrets infrastructure |
| `ops/plugins/infra/ssh/` | ALL | Shared SSH transport |
| `ops/plugins/infra/backup/` | ALL | Shared backup infra |
| `ops/plugins/infra/services/` | ALL | Shared service health probing |
| `ops/plugins/providers/cloudflare/` | network + multiple domains | Shared Cloudflare adapter |
| `ops/plugins/providers/tailscale/` | ALL | Shared VPN adapter |
| `ops/plugins/infra/observability/` (generic caps) | ALL | Shared observability (except product-specific scripts) |

### L1 Core Engine (stays in spine)

- `ops/plugins/core/*` — lifecycle, orchestration, authority, verify engine, evidence, proposals, alerting, session
- `surfaces/verify/g1-*.sh` through `g17-*.sh` — infrastructure gates
- `surfaces/verify/d3-*`, `d34-*`, `d62-*`, `d63-*`, `d67-*`, `d75-*`, `d91-*`, `d93-*`, `d121-*`, `d124-*`, `d127-*`, `d140-*`, `d150-*`, `d153-*`, `d274-*`, `d275-*`, `d331-*`, `d338-*`-`d350-*`, `d377-*`, `d396-*`-`d398-*`, `d400-*`-`d402-*`, `d406-*`, `d410-*`, `d416-*`, `d422-*`-`d430-*` — core/aof governance gates
- `surfaces/verify/drift-gate.sh`, `surfaces/verify/lib/`
- `ops/bindings/` top-level generic contracts (wave, worktree, terminal, fabric, spine schema, etc.)

### Dead Residue (delete later)

| Surface | Rationale |
|---|---|
| Topology `path_triggers` for d225- through d250- | Referenced in mint domain_metadata but no scripts exist on disk |
| Compat alias capabilities (6 entries) | Have canonical replacements |
| Retired gates in gate.registry.yaml (D151, D195, D200, D201, D202, D215, etc.) | Marked `retired: true` |
| `routing.dispatch.yaml` stale routes (~671 from deleted sources) | Generator and sources deleted, not regenerable |
| `single.authority.contract.yaml` reference to agents.registry.yaml | Points to deleted file |

---

## Boundary Rules

### 1. Keep in L1
- `ops/plugins/core/*` — all core engine plugins
- `surfaces/verify/g*` — infrastructure gate scripts
- Core/aof governance gate scripts (d3-, d34-, d62-, d63-, d67-, d75-, etc.)
- `surfaces/verify/drift-gate.sh`, `surfaces/verify/lib/`
- `ops/bindings/` top-level generic contracts
- `ops/capabilities.yaml` core/infra/shared section (55 of 63 entries)
- `ops/bindings/gate.execution.topology.yaml` L1/L2 domain_metadata only
- `ops/bindings/gate.registry.yaml` core/infra gates only

### 2. Keep as L2
- `ops/plugins/providers/microsoft/` — shared Microsoft Graph adapter
- `ops/plugins/infra/secrets/`, `ops/plugins/infra/ssh/`, `ops/plugins/infra/backup/`
- `ops/plugins/infra/services/`, `ops/plugins/providers/cloudflare/`, `ops/plugins/providers/tailscale/`
- `ops/plugins/infra/observability/` (generic observability caps, not product-specific scripts)
- `ops/bindings/services.health.yaml`
- Microsoft adapter capabilities in capabilities.yaml (6 entries)

### 3. Move to L3
- `ops/plugins/domains/*` — all product plugin trees (mint, comms, calendar, media, home, finance, immich, n8n, inbox-shield, surveillance, taxlegal)
- `ops/bindings/domains/*` — all product contracts (media 23, comms 13, mint 1)
- `ops/bindings/vpn.provider.yaml` — media-only
- 8 product capabilities in capabilities.yaml
- Product domain_metadata blocks in gate.execution.topology.yaml (9 L3 domains)
- Product gate definitions in gate.registry.yaml (~50 product-primary gates)
- Product verify surfaces (d107, d216, d218, d219, d222, d233, d257, d392, d399)
- `ops/plugins/infra/observability/bin/finance-stack-status` — finance-specific
- `ops/plugins/infra/observability/bin/immich-*` — immich-specific

### 4. Delete Later
- Stale routing.dispatch.yaml routes from deleted sources
- Topology path_triggers pointing to non-existent verify surfaces
- Compat alias capabilities (6 entries)
- Retired gates
- Stale references to deleted files (agents.registry.yaml in single.authority.contract.yaml)

### 5. Anti-Cheat Rules
- **Do not relabel product truth as adapter code to avoid extraction.** If a script names a product entity (quote, customer, inbox, media pipeline), it is L3 regardless of where it lives.
- **If a route names a product capability, it is not L1.** `mint.quote.render` is not spine infrastructure.
- **If a verify gate encodes product health policy, it is not L1.** D225 (mint module health) is not generic verification. D257 (media capacity guard) is not generic infrastructure.
- **If scheduler or intake logic is product-specific, it is not L1.** `mint.loop.daily`, `mint.intake.validate` are product scheduling.
- **If only one product uses it, it is not L2.** `vpn.provider.yaml` is used only by media. It is L3, not L2.
- **Generated projections are not root authority.** Do not count dispatch route counts as evidence of governed authority. Count the actual governed registry entries.
- **Stale projections are not extraction targets.** `routing.dispatch.yaml` is cleanup, not extraction.
- **File location is not proof of correct ownership.** A file under `ops/plugins/domains/mint/` living in spine is product truth that hasn't left yet.

---

## Mint-First Extraction Tranche

### What Mint Actually Has in Spine (corrected)

| Surface | Entries | Notes |
|---|---|---|
| capabilities.yaml | **0** | All mint caps came from deleted agents.registry.yaml |
| gate.execution.topology.yaml | 1 domain_metadata block (8 gates) | Live authority |
| gate.registry.yaml | 8 primary gates + 6 secondary refs | Live authority |
| ops/plugins/domains/mint/ | 28 bin + 15 lib + 1 contract | Product code, live |
| ops/bindings/domains/mint.bundle.yaml | 1 file | Product contract, live |
| routing.dispatch.yaml | ~58 stale routes | Orphaned projection, not live authority |
| verify surfaces | d222, d399 (+ d392 shared with comms) | Product verify, live |
| topology path_triggers | d225-d250 references | Dead — no scripts on disk |

### Tranche 1 Targets

| # | Target | Why tranche 1 | Expected effect |
|---|---|---|---|
| 1 | **Mint `domain_metadata` block in `gate.execution.topology.yaml`** | Live authority defining mint's gate topology, path_triggers, capability_prefixes. This is the root of mint's presence in spine verification governance. | Removes mint's topology footprint. |
| 2 | **Mint gate definitions in `gate.registry.yaml`** (D225,D226,D236,D382,D390,D393-D395) | Product-specific gate definitions encoding mint health policy. | Recovers 8 gate budget slots. |
| 3 | **`ops/plugins/domains/mint/bin/*`** (28 scripts) | Product commands: quote pipeline, production packages, customer inbox, auth deploy, intake, morpheus, money trace. | Moves all mint business logic out of spine. |
| 4 | **`ops/plugins/domains/mint/lib/*`** (15 Python modules) | Product runtime: quote_packet_*, production_*, mint_runtime_paths, customer_inbox_common. | Moves mint runtime code out of spine. |
| 5 | **`ops/plugins/domains/mint/contracts/mint.runtime.boundary.yaml`** | Mint's own boundary contract. | Moves product contract to product repo. |
| 6 | **`ops/bindings/domains/mint.bundle.yaml`** | Mint capability bundle definition. | Moves product bundle declaration to product repo. |
| 7 | **Mint verify surfaces** (d222-quote-alert-provider-boundary, d399-microsoft-mint-customer-mailbox-canonical) | Product-specific verification scripts. | Removes 2 mint product gates from spine verify surface. |
| 8 | **Dead topology path_triggers** (d225- through d250-) | References to non-existent verify scripts. | Cleans dead references from topology. |

### Why This Order
- Items 1-2 are **authority**: they define what mint IS in spine's verification governance. Remove these first to prevent new mint truth from accumulating.
- Items 3-5 are **implementation**: the scripts, libs, and contracts that execute mint product logic.
- Item 6 is **declaration**: the bundle that ties capability to domain.
- Item 7 is **verification**: product gates that should run from the product side.
- Item 8 is **dead residue**: references to things that don't exist.

### Expected Effect
- Spine loses 1 domain_metadata block, 8 gates, 28 scripts, 15 Python modules, 1 contract, 1 bundle, 2 verify surfaces
- Gate budget recovers 8 slots
- routing.dispatch.yaml stale mint routes become obviously orphaned (should be cleaned separately)
- Mint product truth moves to mint-modules repo

### What NOT to Touch in Tranche 1
- **capabilities.yaml** — mint has 0 entries there already. No work needed.
- **routing.dispatch.yaml** — orphaned projection. Handle as separate cleanup, not mint extraction.
- **Microsoft adapter** (`ops/plugins/providers/microsoft/`) — shared L2
- **Core verify engine** (`ops/plugins/core/verify/`) — generic L1
- **Generic infra gates** (g1-g17) — L1
- **Other product domains** — later tranches
- **Spine-level bindings** (wave, worktree, terminal contracts) — L1

---

## Follow-On Extraction Order

After Mint tranche 1:

1. **routing.dispatch.yaml cleanup** — regenerate from capabilities.yaml only (shrinks from 734 to ~63 routes) or retire the file. This is not product extraction; it's stale projection cleanup.
2. **Communications** (13 gate refs, 13 binding files, 7 verify surfaces, 3+4 plugin scripts) — second largest gate footprint
3. **Media** (7 gate refs, 23 binding files, 2 verify surfaces, 20+ plugin scripts) — largest binding surface
4. **Calendar** (subset of communications, but distinct plugin tree)
5. **Home** (3 gate refs, 5 scripts)
6. **Finance** (1 gate, 2 scripts)
7. **Immich** (0 direct gates but referenced, 5 scripts)
8. **n8n** (0 direct gates but referenced, 2 scripts)

Each tranche follows: authority first (topology + gates), then implementation (plugins/domains/), then contracts (bindings/domains/), then verify surfaces.

---

## Non-Goals

- This audit does not propose a new architecture or middle layer
- This audit does not rename, move, or delete any file
- This audit does not design how extracted products register capabilities back into spine
- This audit does not solve how routing.dispatch.yaml should be rebuilt or retired
- This audit does not define the target repo structure for extracted products
- This audit does not touch the operator membrane (entry, status, verify, dispatch all continue to work as-is)

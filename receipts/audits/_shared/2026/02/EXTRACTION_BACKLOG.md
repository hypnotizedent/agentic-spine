---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-17
scope: ronny-ops-final-extraction-backlog
parent_loop: LOOP-RONNY-OPS-FINAL-EXTRACTION-SWEEP-20260217
---

# Extraction Backlog (Execution Order)

Source merge: `L1_LEGACY_CENSUS.md`, `L2_RUNTIME_INFRA_DIFF.md`, `L3_DOMAIN_DOCS_DIFF.md`, `L4_PROXMOX_ALIGNMENT_DIFF.md`

Execution contract:
1. Execute top-to-bottom.
2. Do not start `P1` until `P0` is complete.
3. Do not start `P2` until `P1` extraction receipts exist.

---

## P0 - Runtime Authority (Execute First)

| Order | ID | Work Item | Primary Source(s) | Target Repo | Delivery Path | Done Check |
|------:|----|-----------|-------------------|-------------|---------------|------------|
| 1 | P0-01 | Register extraction work items as governed gaps/loop tasks before mutation | all L1-L4 | `agentic-spine` | `ops/bindings/operational.gaps.yaml`, `mailroom/state/loop-scopes/` | Each backlog item has a tracking gap or scoped task |
| 2 | P0-02 | Capture runtime baseline and route verify lanes | L4 | `agentic-spine` | `receipts/sessions/` | Receipts for `stability.control.snapshot`, `verify.core.run`, `verify.route.recommend`, `verify.domain.run` |
| 3 | P0-03 | Reconcile VM inventory parity to spine canonical truth | L4 | `workbench` | `infra/data/CONTAINER_INVENTORY.yaml` | Decommissioned VMs removed, active VMs added, host naming aligns to spine |
| 4 | P0-04 | Reconcile SSH target inventory parity to spine canonical truth | L4 | `workbench` | `dotfiles/ssh/config.d/tailscale.conf` | Missing active targets added, stale targets removed, immich user aligned with spine |
| 5 | P0-05 | Extract active media compose authority from legacy | L1, L2 | `workbench` | `infra/compose/media-stack/docker-compose.yml` | Compose exists in workbench and reflects current split-host runtime reality |
| 6 | P0-06 | Extract active finance compose authority (core + mail-archiver) | L1, L2 | `workbench` | `infra/compose/finance/docker-compose.yml`, `infra/compose/finance/mail-archiver/docker-compose.yml` | Finance compose definitions no longer legacy-only |
| 7 | P0-07 | Reconcile additional active runtime compose gaps (monitoring, pihole) | L2 | `workbench` | `infra/compose/monitoring/`, `infra/compose/pihole/` | Active services have canonical compose definitions in workbench with current host/IP assumptions |
| 8 | P0-08 | Merge service registry and runtime inventory deltas from legacy into canonical bindings/data | L1, L4 | `agentic-spine` + `workbench` | `ops/bindings/`, `workbench/infra/data/` | No active service/runtime dependency exists only in legacy |
| 9 | P0-09 | Resolve active shell/runtime references to legacy root | L1 | `workbench` | `dotfiles` source of truth for shell config | No active `LEGACY_ROOT="/Users/ronnyworks/ronny-ops"` reference remains in runtime shell profile |
| 10 | P0-10 | Canonicalize `infisical-agent.sh` usage to spine-governed version | L1 | `agentic-spine` + `workbench` | `ops/tools/infisical-agent.sh` and calling scripts | Script parity/usage confirms spine version is authoritative |
| 11 | P0-11 | Mark legacy cloudflare/old runtime copies as non-authoritative | L1, L2 | `archive/drop` | Legacy runtime compose/docs manifest | Legacy runtime files carry explicit archive/drop disposition |
| 12 | P0-12 | Run post-P0 verification and receipt closeout | all L1-L4 | `agentic-spine` | `receipts/sessions/`, impact notes | Verify lanes pass for touched domains and closeout note exists |

---

## P1 - Extraction Debt (Execute Second)

| Order | ID | Work Item | Primary Source(s) | Target Repo | Delivery Path | Done Check |
|------:|----|-----------|-------------------|-------------|---------------|------------|
| 13 | P1-01 | Extract HA dashboard brand/pattern authority | L3 | `workbench` | `docs/brain-lessons/HA_DASHBOARD_BRAND.md` | Style guide + dashboard patterns merged into one maintained doc |
| 14 | P1-02 | Extract HA device registry with verified device/integration metadata | L3 | `workbench` | `docs/brain-lessons/HA_DEVICE_REGISTRY.md` | Device state/inventory data no longer stranded in legacy |
| 15 | P1-03 | Extract HA incident runbooks (Zigbee, CalDAV, WoL) | L3 | `workbench` | `docs/brain-lessons/HA_RUNBOOKS.md` | Recovery-ready procedures captured with tested settings/identifiers |
| 16 | P1-04 | Extract HA CLI cookbook and deployment/resync/network/streamdeck deltas | L2, L3 | `workbench` | `docs/brain-lessons/HA_CLI_PATTERNS.md` (+ merges) | Operational gotchas and command patterns represented in current docs |
| 17 | P1-05 | Extract media pipeline architecture and Tdarr safety runbook | L3 | `workbench` | `docs/brain-lessons/MEDIA_PIPELINE_ARCHITECTURE.md`, `docs/brain-lessons/MEDIA_TDARR_RUNBOOK.md` | Ports/workflow IDs/NFS-safe guardrails documented |
| 18 | P1-06 | Merge media recovery order, critical rules delta, download architecture, Navidrome integration | L3 | `workbench` | media brain-lessons docs (existing + new) | Existing media docs updated with missing rules and startup dependencies |
| 19 | P1-07 | Extract finance account topology + category mapping authority | L3 | `workbench` | `docs/brain-lessons/FINANCE_ACCOUNT_TOPOLOGY.md` | Account IDs, mappings, and vendor/tax logic preserved |
| 20 | P1-08 | Extract finance import configs, receipt SOP, and Firefly-Mint sync runbook | L3 | `workbench` | finance brain-lessons docs (new/merged) | End-to-end finance ingest and sync procedures are fully represented |
| 21 | P1-09 | Merge finance partial deltas (SimpleFIN UUID map, troubleshooting edge cases) | L3 | `workbench` | existing finance docs | Partial coverage gaps explicitly closed |
| 22 | P1-10 | Extract infra governance debt (Cloudflare governance, incidents log, service update tiers) | L2, L3 | `workbench` | infra brain-lessons/governance docs | Cross-domain governance knowledge no longer legacy-only |
| 23 | P1-11 | Extract MCPJungle recovery and n8n operational docs/scripts | L2, L3 | `workbench` | `infra/compose/mcpjungle/`, `infra/compose/n8n/` | Recovery runbook, contract docs, and credentials tooling present |
| 24 | P1-12 | Extract Immich import rules + context and install deltas | L3 | `workbench` | Immich brain-lessons docs | Photo keeper policy and migration context preserved |
| 25 | P1-13 | Extract Dakota embroidery inventory/business asset registry | L3 | `workbench` | `docs/brain-lessons/EMBROIDERY_LIBRARY.md` | High-value asset inventory has maintained home |
| 26 | P1-14 | Extract missing operational scripts/config bundles (media, HA, finance, bootstrap, RAG, agents) | L1, L2 | `workbench` | `infra/compose/**/scripts`, `infra/scripts/` | Legacy-only scripts required for operations are migrated or formally deprecated |
| 27 | P1-15 | Reconcile governance parity deltas (backup gate, reboot gate, SSOT registry) | L1, L3 | `agentic-spine` | `docs/governance/`, `ops/bindings/` | Legacy-specific governance details merged or intentionally rejected with note |
| 28 | P1-16 | Merge legacy session memory learnings into spine memory | L1, L3 | `agentic-spine` | `docs/brain/memory.md` | Legacy operational lessons are preserved in spine memory surface |
| 29 | P1-17 | Run domain-scoped verify and impact notes for each touched domain | all L1-L4 | `agentic-spine` | receipts + docs impact notes | Domain lanes verified and impact notes linked to receipt keys |

---

## P2 - Archive/Drop Cleanup (Execute Last)

| Order | ID | Work Item | Primary Source(s) | Target Repo | Delivery Path | Done Check |
|------:|----|-----------|-------------------|-------------|---------------|------------|
| 30 | P2-01 | Archive `mint-os/` wholesale as application source history | L1, L3 | `archive/drop` | external archive target or dedicated app repo path | Legacy monorepo no longer treated as runtime extraction debt |
| 31 | P2-02 | Archive `modules/files-api` as superseded extraction | L1, L2 | `archive/drop` | archive manifest | Module marked superseded with traceable archive location |
| 32 | P2-03 | Drop superseded legacy control surfaces (`.agent`, `.claude`, `.opencode`, deprecated root docs/config) | L1 | `archive/drop` | legacy cleanup manifest | No active workflow references superseded agent/control files |
| 33 | P2-04 | Drop stale legacy archive surfaces after P1 extraction confirms capture | L1, L2 | `archive/drop` | `.archive/` cleanup manifest | Archived legacy docs/workflows removed or tombstoned with retention note |
| 34 | P2-05 | Drop stale legacy runtime snapshots (old compose variants, stale Proxmox audit artifacts) | L1, L4 | `archive/drop` | runtime drop manifest | Stale files retained only as explicit archive artifacts, not active references |
| 35 | P2-06 | Final legacy retirement pass and loop close evidence | all L1-L4 | `agentic-spine` | closeout receipt and loop note | Legacy is read-only archive with no runtime authority; loop close criteria met |


---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-23
scope: w20-normalization-strategy-only
---

# W20 Normalization Strategy (2026-02-23)

- Task: `WORKBENCH-BUILD-W20-STRATEGY-ONLY-20260223`
- Mode: strategy/inventory only (no runtime or normalization behavior changes)
- Generated at (UTC): `2026-02-23T07:58:56Z`
- Repo scope: `/Users/ronnyworks/code/agentic-spine` + `/Users/ronnyworks/code/workbench`

## Guardrails Applied During Inventory

- Excluded from scanning: `.git/`, `.worktrees/`, `node_modules/`, `.venv/`, spine `receipts/`, spine `mailroom/outbox/`, spine `mailroom/state/loop-scopes/`, workbench `archive/`.
- Explicit no-touch boundaries retained:
  - `/Users/ronnyworks/code/workbench/.spine-link.yaml`
  - `/Users/ronnyworks/code/workbench/bin/ops`
  - `/Users/ronnyworks/code/workbench/bin/verify`
  - `/Users/ronnyworks/code/workbench/bin/mint`
  - `/Users/ronnyworks/code/agentic-spine/ops/bindings/agents.registry.yaml` `project_binding.repo_path`

## Inventory Summary

- Frontmatter gaps in `ops/bindings`: **152**
  - Class A (generator-managed/contract-sensitive): **135**
  - Class B (safe candidates): **17**
- Hardcoded path usage (`/Users/ronnyworks/code`) in active-surface scan: **784** occurrences across **318** files
  - Contract-sensitive: **469** occurrences / **190** files
  - Docs/examples safe-normalization candidates: **315** occurrences / **128** files
  - Generated surfaces (requires source/gen change first): **0** occurrences / **0** files
- Temporal field usage:
  - `updated_at`: **83** occurrences across **83** files
  - `updated`: **75** occurrences across **66** files
  - `last_verified`: **489** occurrences across **467** files
- MCP registry sources defining server config/policy: **4**

## Phase A.1 Frontmatter Gap Inventory (`ops/bindings`)

| Path | First line | Risk class | Reason |
|---|---|---|---|
| `ops/bindings/agent.entrypoint.lock.yaml` | `# Agent Entrypoint Lock Binding` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/agent.fact.lock.yaml` | `# Agent Fact Lock Binding (SSOT)` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/agent.read.surface.yaml` | `# Agent Read Surface Binding (SSOT)` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/agents.registry.yaml` | `# ═══════════════════════════════════════════════════════════════════════════` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/alerting.rules.yaml` | `# Alerting Rules Contract` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/audit.suppressions.policy.yaml` | `# Audit Suppressions Policy Binding` | `B` | safe candidate for frontmatter introduction (manual, bounded rollout) |
| `ops/bindings/audits.migration.plan.yaml` | `version: '1.0'` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/authority.exemptions.yaml` | `# Authority Project Exemptions` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/automation.stack.latency.slo.yaml` | `# Automation Stack Latency SLO Contract` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/backup.calendar.yaml` | `# Status: authoritative` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/backup.inventory.yaml` | `# Seeded from workbench SSOT: ~/code/workbench/infra/data/backup_inventory.json` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/binding.freshness.exemptions.yaml` | `# Binding Freshness Exemptions` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/briefing.config.yaml` | `# Daily Briefing Contract` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/calendar.global.schema.yaml` | `# Calendar Global SSOT Schema` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/calendar.global.yaml` | `# Status: authoritative` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/capability_map.yaml` | `# Capability Map — cap -> plugin -> script` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/change.intake.policy.yaml` | `# Change Intake Policy Binding` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/cli.tools.inventory.yaml` | `# ═══════════════════════════════════════════════════════════════════════════` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/cloudflare.inventory.yaml` | `{` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/communications.alerts.escalation.contract.yaml` | `# Status: authoritative` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/communications.alerts.queue.contract.yaml` | `# Status: authoritative` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/communications.delivery.contract.yaml` | `# Status: authoritative` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/communications.policy.contract.yaml` | `# Status: authoritative` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/communications.providers.contract.yaml` | `# Status: authoritative` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/communications.stack.contract.yaml` | `# Status: authoritative` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/communications.templates.catalog.yaml` | `# Status: authoritative` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/cross-repo.authority.yaml` | `# Cross-Repo Authority Contract` | `B` | safe candidate for frontmatter introduction (manual, bounded rollout) |
| `ops/bindings/cutover.sequencing.yaml` | `# Cutover Sequencing Rules` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/deploy.dependencies.yaml` | `# Deploy Dependencies Binding` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/deploy.method.contract.yaml` | `# Status: authoritative` | `B` | safe candidate for frontmatter introduction (manual, bounded rollout) |
| `ops/bindings/deprecated-project-allowlist.yaml` | `# Deprecated Project Reference Allowlist` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/deprecated.terms.yaml` | `# Deprecated Terms Registry` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/docker.compose.targets.yaml` | `# Docker Compose Targets Binding (SSOT)` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/docs.impact.contract.yaml` | `# Docs Impact Contract` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/docs.johnny_decimal.yaml` | `# Johnny Decimal Taxonomy for Agentic Spine Documentation` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/domain.docs.routes.yaml` | `# Domain Docs Route Binding` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/drift-gates.scoped.yaml` | `version: "1.0"` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/entry.surface.contract.yaml` | `# Entry Surface Contract` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/environment.contract.schema.yaml` | `version: "1.0"` | `B` | safe candidate for frontmatter introduction (manual, bounded rollout) |
| `ops/bindings/evidence.retention.policy.yaml` | `# Evidence Retention Policy` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/extraction.mode.yaml` | `# Status: authoritative` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/extraction.queue.yaml` | `# Extraction Queue Binding (archive runway)` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/fabric.boundary.contract.yaml` | `# Fabric Boundary Contract` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/gap.schema.yaml` | `# Gap Entry Schema` | `B` | safe candidate for frontmatter introduction (manual, bounded rollout) |
| `ops/bindings/gate.agent.profiles.yaml` | `# Agent Verify Pack Profiles` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/gate.execution.topology.yaml` | `version: "1.0"` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/gate.registry.yaml` | `schema_version: '1.0'` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/governance.parity.reconcile.20260217.yaml` | `schema_version: "1.0"` | `B` | safe candidate for frontmatter introduction (manual, bounded rollout) |
| `ops/bindings/ha.addons.yaml` | `schema_version: '1.0'` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/ha.areas.yaml` | `# HA Areas — Canonical area definitions` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/ha.automations.yaml` | `# HA Automation Snapshot (SSOT)` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/ha.dashboards.yaml` | `# HA Dashboard Snapshot (SSOT)` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/ha.device.map.overrides.yaml` | `# Device Map Manual Overrides` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/ha.device.map.yaml` | `# HA Device Map (SSOT)` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/ha.entity.state.baseline.yaml` | `# HA Entity State Baseline (SSOT)` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/ha.entity.state.expected-unavailable.yaml` | `# HA Entity State — Expected Unavailable Allowlist` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/ha.entity.state.expected-unknown.yaml` | `# HA Entity State — Expected Unknown Allowlist` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/ha.environments.yaml` | `# HA Environments Contract (SSOT)` | `B` | safe candidate for frontmatter introduction (manual, bounded rollout) |
| `ops/bindings/ha.hacs.yaml` | `# HA HACS Snapshot (SSOT)` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/ha.helpers.yaml` | `# HA Helper Entity Snapshot (SSOT)` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/ha.identity.mutation.contract.yaml` | `# ═══════════════════════════════════════════════════════════════════════════` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/ha.integrations.yaml` | `# HA Integration Snapshot (SSOT)` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/ha.naming.convention.yaml` | `# HA Naming Convention (SSOT)` | `B` | safe candidate for frontmatter introduction (manual, bounded rollout) |
| `ops/bindings/ha.orphan.classification.yaml` | `# HA Orphan Device Classification` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/ha.scenes.yaml` | `# HA Scene Snapshot (SSOT)` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/ha.scripts.yaml` | `# HA Script Snapshot (SSOT)` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/ha.ssot.baseline.yaml` | `# HA SSOT Unified Baseline` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/ha.sync.config.yaml` | `# HA Sync Agent Configuration` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/handoff.config.yaml` | `# Session Handoff Contract` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/home-surface.allowlist.yaml` | `# home-surface.allowlist.yaml — Canonical home directory governance binding` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/home.device.registry.yaml` | `# Home Device Registry (SSOT)` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/home.dhcp.audit.yaml` | `# Auto-generated by network.home.dhcp.audit — do not edit manually` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/home.output.sinks.yaml` | `# Status: authoritative` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/host.audit.allowlist.yaml` | `# Status: authoritative` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/identity.contract.schema.yaml` | `version: "1.0"` | `B` | safe candidate for frontmatter introduction (manual, bounded rollout) |
| `ops/bindings/immich.ingest.watch.contract.yaml` | `# Immich Ingest Watch Contract` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/infra.core.slo.yaml` | `# Infra Core Service-Level SLO Contract` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/infra.placement.policy.yaml` | `# Status: authoritative` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/infra.relocation.plan.yaml` | `# Status: authoritative` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/infra.vm.profiles.yaml` | `# Status: authoritative` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/launchd.runtime.contract.yaml` | `version: "1.0"` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/legacy.entrypoint.exceptions.yaml` | `# Status: authoritative` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/lifecycle.rules.schema.yaml` | `# Lifecycle Rules Schema — Validates lifecycle.rules.yaml` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/lifecycle.rules.yaml` | `# Lifecycle Rules — Authoritative SSOT for gap/loop lifecycle defaults` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/lifecycle.standards.yaml` | `# Lifecycle Standards Binding` | `B` | safe candidate for frontmatter introduction (manual, bounded rollout) |
| `ops/bindings/mailroom.bridge.yaml` | `# Status: authoritative` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/maker.tools.inventory.yaml` | `# ═══════════════════════════════════════════════════════════════════════════` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/mcp.runtime.contract.yaml` | `# MCP Runtime Contract` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/media.services.yaml` | `# Media Services Binding (SSOT)` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/mint.rank5plus.cutover.contract.yaml` | `# Mint Rank5+ Cutover Orchestration Contract` | `B` | safe candidate for frontmatter introduction (manual, bounded rollout) |
| `ops/bindings/n8n.infra.reliability.contract.yaml` | `# n8n Infrastructure Reliability Contract` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/naming.policy.yaml` | `# Naming Policy SSOT` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/network.home.baseline.yaml` | `# Home Network Baseline Binding` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/operational.gaps.yaml` | `# Operational Gaps - Runtime SSOT Discoveries` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/operator.smoothness.contract.yaml` | `# Status: authoritative` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/plugin-test-exemptions.yaml` | `# Plugin Test Exemptions` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/plugin.migration.bulk.plan.yaml` | `# NO EXECUTION IN THIS WAVE: PLAN ONLY` | `B` | safe candidate for frontmatter introduction (manual, bounded rollout) |
| `ops/bindings/plugin.migration.inventory.yaml` | `version: '1.0'` | `B` | safe candidate for frontmatter introduction (manual, bounded rollout) |
| `ops/bindings/plugin.migration.pilot.plan.yaml` | `version: "1.0"` | `B` | safe candidate for frontmatter introduction (manual, bounded rollout) |
| `ops/bindings/plugin.ownership.map.yaml` | `version: "1.0"` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/policy.autotune.contract.yaml` | `# Policy Autotune Weekly Contract` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/policy.autotune.rules.yaml` | `# Policy Autotune Rules` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/policy.presets.yaml` | `# Policy Presets` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/policy.runtime.contract.yaml` | `# Policy Runtime Contract` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/proposals.lifecycle.yaml` | `# Proposal Lifecycle Contract` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/rag.embedding.backend.yaml` | `# RAG Embedding Backend Selection Contract` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/rag.metrics.normalization.yaml` | `# Status: authoritative` | `B` | safe candidate for frontmatter introduction (manual, bounded rollout) |
| `ops/bindings/rag.pipeline.contract.yaml` | `# Status: authoritative` | `B` | safe candidate for frontmatter introduction (manual, bounded rollout) |
| `ops/bindings/rag.reindex.quality.yaml` | `# RAG Reindex Quality Contract` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/rag.remote.runner.yaml` | `# RAG Remote Reindex Runner Contract` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/rag.workspace.contract.yaml` | `# RAG Workspace Contract` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/receipts.archival.policy.yaml` | `version: "1.0"` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/receipts.index.schema.yaml` | `# Receipts Index Schema Contract` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/registry.ownership.yaml` | `version: "1.2"` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/runtime.manifest.yaml` | `status: authoritative` | `B` | safe candidate for frontmatter introduction (manual, bounded rollout) |
| `ops/bindings/secrets.binding.yaml` | `# Status: authoritative` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/secrets.bundle.contract.yaml` | `# Status: authoritative` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/secrets.credentials.parity.yaml` | `# Status: authoritative` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/secrets.inventory.yaml` | `# Secrets Inventory - SSOT parity binding` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/secrets.namespace.policy.yaml` | `# Status: authoritative` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/secrets.runway.contract.yaml` | `# Status: authoritative` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/services.health.yaml` | `# Services Health Binding` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/share.publish.allowlist.yaml` | `# Share Publish Allowlist` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/share.publish.denylist.yaml` | `# Share Publish Denylist` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/share.publish.remote.yaml` | `# Share Publish Remote Contract` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/spine.verify.runtime.yaml` | `version: 2` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/ssh.targets.yaml` | `# SSH Targets Binding (SSOT)` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/stability.control.contract.yaml` | `# Stability Control Contract` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/startup.sequencing.yaml` | `# Startup Sequencing Binding (SSOT)` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/surface.readonly.contract.yaml` | `# Surface Readonly Contract` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/tenant.profile.schema.yaml` | `# Tenant Profile Schema` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/tenant.profile.yaml` | `# Active tenant profile for AOF runtime policy resolution` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/tenant.storage.contract.yaml` | `# Tenant Storage Contract` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/tenants/media-stack.yaml` | `# Tenant Profile: media-stack` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/verify.ring.policy.yaml` | `version: "1.0"` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/version.compat.matrix.yaml` | `# Version Compatibility Matrix` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/vertical.integration.admission.contract.yaml` | `# Vertical Integration Admission Contract` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/vm.lifecycle.contract.yaml` | `# VM Lifecycle Authority Contract` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/vm.lifecycle.derived.yaml` | `# Generated from vm.lifecycle.contract.yaml` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/vm.lifecycle.yaml` | `# VM Lifecycle Binding (SSOT)` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/vm.operating.profile.yaml` | `# VM Operating Profile Binding (SSOT)` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/weekly.execution.telemetry.contract.yaml` | `version: "1.0"` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/workbench.deploy.method.surface.contract.yaml` | `status: authoritative` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/workbench.operator.surface.contract.yaml` | `status: authoritative` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/workbench.script.allowlist.yaml` | `# workbench.script.allowlist.yaml — Governed script surfaces in workbench` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/workbench.secrets.onboarding.contract.yaml` | `status: authoritative` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/workbench.ssh.attach.contract.yaml` | `status: authoritative` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/workbench.ssh.runtime.surface.contract.yaml` | `status: authoritative` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/worktree.session.isolation.yaml` | `# Worktree Session Isolation Contract` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/z2m.devices.yaml` | `# Z2M Device Registry (SSOT)` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/z2m.naming.yaml` | `# Z2M Naming Parity Binding (SSOT)` | `A` | generator-managed or contract-sensitive binding |
| `ops/bindings/zwave.devices.yaml` | `# Z-Wave Device Registry (SSOT)` | `A` | generator-managed or contract-sensitive binding |

## Phase A.2 Hardcoded Path Inventory (`/Users/ronnyworks/code`)

### Category totals by repo

| Repo | Category | Occurrences | Files |
|---|---|---:|---:|
| `agentic-spine` | contract-sensitive | 430 | 163 |
| `agentic-spine` | docs/examples | 264 | 104 |
| `workbench` | contract-sensitive | 39 | 27 |
| `workbench` | docs/examples | 51 | 24 |

### File lists by category

#### `spine` / `contract-sensitive`

- `./ops/capabilities.yaml` (127)
- `./ops/bindings/operational.gaps.yaml` (17)
- `./ops/bindings/plugin.migration.inventory.yaml` (15)
- `./ops/bindings/capability.domain.catalog.yaml` (11)
- `./ops/bindings/spine.boundary.baseline.yaml` (11)
- `./ops/bindings/plugin.ownership.map.yaml` (9)
- `./docs/governance/SSOT_REGISTRY.yaml` (8)
- `./ops/bindings/plugin.migration.bulk.plan.yaml` (8)
- `./surfaces/verify/d74-billing-provider-lane-lock.sh` (6)
- `./ops/runtime/launchd/com.ronny.alerting-probe-cycle.plist` (5)
- `./ops/runtime/launchd/com.ronny.finance-action-queue-monthly.plist` (5)
- `./ops/runtime/launchd/com.ronny.immich-reconcile-weekly.plist` (5)
- `./ops/runtime/launchd/com.ronny.mcp-runtime-anti-drift-cycle.plist` (5)
- `./ops/runtime/launchd/com.ronny.n8n-snapshot-daily.plist` (5)
- `./ops/runtime/launchd/com.ronny.policy-autotune-weekly.plist` (5)
- `./ops/runtime/launchd/com.ronny.slo-evidence-daily.plist` (5)
- `./ops/runtime/launchd/com.ronny.spine-briefing-email-daily.plist` (5)
- `./ops/runtime/launchd/com.ronny.spine-daily-briefing.plist` (5)
- `./bin/generators/gen-project-attach.sh` (3)
- `./docs/governance/schemas/agents.registry.v2-fields.schema.yaml` (3)
- `./ops/bindings/extraction.queue.yaml` (3)
- `./ops/bindings/host.audit.allowlist.yaml` (3)
- `./ops/bindings/mcp.runtime.contract.yaml` (3)
- `./ops/bindings/stabilization.mode.yaml` (3)
- `./surfaces/verify/d72-macbook-hotkey-ssot-lock.sh` (3)
- `./fixtures/tenant.sample.yaml` (2)
- `./ops/bindings/agent.read.surface.yaml` (2)
- `./ops/bindings/agents.registry.yaml` (2)
- `./ops/bindings/fabric.boundary.contract.yaml` (2)
- `./ops/bindings/gate.execution.topology.yaml` (2)
- `./ops/bindings/mailroom.runtime.contract.yaml` (2)
- `./ops/bindings/tenant.profile.yaml` (2)
- `./ops/bindings/vertical.integration.admission.contract.yaml` (2)
- `./ops/bindings/wave.lifecycle.yaml` (2)
- `./ops/hooks/session-entry-hook.sh` (2)
- `./ops/plugins/ops/bin/worktree-session-status` (2)
- `./surfaces/verify/d153-project-attach-parity.sh` (2)
- `./surfaces/verify/d170-workbench-proposals-preflight-lock.sh` (2)
- `./surfaces/verify/d73-opencode-governed-entry-lock.sh` (2)
- `./docs/governance/DOMAIN_ROUTING_REGISTRY.yaml` (1)
- `./docs/governance/_index.yaml` (1)
- `./ops/bindings/agent.entrypoint.lock.yaml` (1)
- `./ops/bindings/authority.exemptions.yaml` (1)
- `./ops/bindings/docs.impact.contract.yaml` (1)
- `./ops/bindings/gate.domain.profiles.yaml` (1)
- `./ops/bindings/gate.registry.yaml` (1)
- `./ops/bindings/home-surface.allowlist.yaml` (1)
- `./ops/bindings/home.output.sinks.yaml` (1)
- `./ops/bindings/launchd.runtime.contract.yaml` (1)
- `./ops/bindings/plugin.migration.pilot.plan.yaml` (1)
- `./ops/bindings/registry.ownership.yaml` (1)
- `./ops/bindings/runtime.manifest.yaml` (1)
- `./ops/bindings/secrets.bundle.contract.yaml` (1)
- `./ops/bindings/workbench.deploy.method.surface.contract.yaml` (1)
- `./ops/bindings/workbench.operator.surface.contract.yaml` (1)
- `./ops/bindings/workbench.secrets.onboarding.contract.yaml` (1)
- `./ops/bindings/workbench.ssh.attach.contract.yaml` (1)
- `./ops/bindings/workbench.ssh.runtime.surface.contract.yaml` (1)
- `./ops/bindings/worktree.session.isolation.yaml` (1)
- `./ops/plugins/backup/bin/backup-calendar-generate` (1)
- `./ops/plugins/backup/bin/backup-status` (1)
- `./ops/plugins/backup/bin/backup-vzdump-prune` (1)
- `./ops/plugins/backup/bin/backup-vzdump-run` (1)
- `./ops/plugins/backup/bin/backup-vzdump-status` (1)
- `./ops/plugins/backup/bin/backup-vzdump-vmid-set` (1)
- `./ops/plugins/ha/bin/ha-addon-restart` (1)
- `./ops/plugins/ha/bin/ha-addons-snapshot` (1)
- `./ops/plugins/ha/bin/ha-automation-create` (1)
- `./ops/plugins/ha/bin/ha-automation-trigger` (1)
- `./ops/plugins/ha/bin/ha-automations-snapshot` (1)
- `./ops/plugins/ha/bin/ha-backup-create` (1)
- `./ops/plugins/ha/bin/ha-config-extract` (1)
- `./ops/plugins/ha/bin/ha-dashboard-backup` (1)
- `./ops/plugins/ha/bin/ha-dashboard-snapshot` (1)
- `./ops/plugins/ha/bin/ha-device-map-build` (1)
- `./ops/plugins/ha/bin/ha-device-rename` (1)
- `./ops/plugins/ha/bin/ha-entity-state-baseline` (1)
- `./ops/plugins/ha/bin/ha-entity-status` (1)
- `./ops/plugins/ha/bin/ha-hacs-snapshot` (1)
- `./ops/plugins/ha/bin/ha-hacs-updates-check` (1)
- `./ops/plugins/ha/bin/ha-health-status` (1)
- `./ops/plugins/ha/bin/ha-helpers-snapshot` (1)
- `./ops/plugins/ha/bin/ha-integrations-snapshot` (1)
- `./ops/plugins/ha/bin/ha-light-toggle` (1)
- `./ops/plugins/ha/bin/ha-lock-control` (1)
- `./ops/plugins/ha/bin/ha-mcp-status` (1)
- `./ops/plugins/ha/bin/ha-refresh` (1)
- `./ops/plugins/ha/bin/ha-scene-activate` (1)
- `./ops/plugins/ha/bin/ha-scenes-snapshot` (1)
- `./ops/plugins/ha/bin/ha-script-run` (1)
- `./ops/plugins/ha/bin/ha-scripts-snapshot` (1)
- `./ops/plugins/ha/bin/ha-service-call` (1)
- `./ops/plugins/ha/bin/ha-ssot-apply` (1)
- `./ops/plugins/ha/bin/ha-ssot-baseline-build` (1)
- `./ops/plugins/ha/bin/ha-ssot-propose` (1)
- `./ops/plugins/ha/bin/ha-status` (1)
- `./ops/plugins/ha/bin/ha-sync-agent` (1)
- `./ops/plugins/ha/bin/ha-sync-start` (1)
- `./ops/plugins/ha/bin/ha-sync-status` (1)
- `./ops/plugins/ha/bin/ha-sync-stop` (1)
- `./ops/plugins/ha/bin/ha-z2m-devices-snapshot` (1)
- `./ops/plugins/ha/bin/ha-z2m-health` (1)
- `./ops/plugins/ha/bin/ha-zwave-devices-snapshot` (1)
- `./ops/plugins/home/bin/ha-identity-mutation-contract-status` (1)
- `./ops/plugins/home/bin/home-backup-status` (1)
- `./ops/plugins/home/bin/home-health-alert` (1)
- `./ops/plugins/home/bin/home-health-check` (1)
- `./ops/plugins/home/bin/home-vm-status` (1)
- `./ops/plugins/host/bin/host-claude-entrypoint-lock` (1)
- `./ops/plugins/host/bin/host-streamdeck-status` (1)
- `./ops/plugins/immich/bin/immich-reconcile-apply` (1)
- `./ops/plugins/immich/bin/immich-reconcile-plan` (1)
- `./ops/plugins/immich/bin/immich-reconcile-review` (1)
- `./ops/plugins/immich/bin/immich-reconcile-rollback` (1)
- `./ops/plugins/immich/bin/immich-reconcile-scan` (1)
- `./ops/plugins/media/bin/media-backup-create` (1)
- `./ops/plugins/media/bin/media-health-check` (1)
- `./ops/plugins/media/bin/media-metrics-today` (1)
- `./ops/plugins/media/bin/media-nfs-verify` (1)
- `./ops/plugins/media/bin/media-service-status` (1)
- `./ops/plugins/media/bin/media-stack-restart` (1)
- `./ops/plugins/media/bin/media-status` (1)
- `./ops/plugins/mint/bin/deploy-sync-from-main` (1)
- `./ops/plugins/mint/bin/migrate-dryrun` (1)
- `./ops/plugins/ms-graph/bin/graph-cap-exec` (1)
- `./ops/plugins/ms-graph/bin/graph-cap-exec.legacy` (1)
- `./ops/plugins/ms-graph/bin/graph-decode-roles` (1)
- `./ops/plugins/ms-graph/bin/graph-token-exec` (1)
- `./ops/plugins/n8n/bin/n8n-infra-health` (1)
- `./ops/plugins/n8n/bin/n8n-snapshot-cron` (1)
- `./ops/plugins/n8n/bin/n8n-snapshot-status` (1)
- `./ops/plugins/n8n/bin/n8n-workflows` (1)
- `./ops/plugins/network/bin/network-ap-facts-capture` (1)
- `./ops/plugins/network/bin/network-cutover-preflight` (1)
- `./ops/plugins/network/bin/network-home-dhcp-audit` (1)
- `./ops/plugins/network/bin/network-home-dhcp-dns-set` (1)
- `./ops/plugins/network/bin/network-home-dhcp-reservation-create` (1)
- `./ops/plugins/network/bin/network-home-unifi-clients-snapshot` (1)
- `./ops/plugins/network/bin/network-home-wifi-create` (1)
- `./ops/plugins/network/bin/network-lan-device-status` (1)
- `./ops/plugins/network/bin/network-lan-host-identify` (1)
- `./ops/plugins/network/bin/network-md1400-bind-test` (1)
- `./ops/plugins/network/bin/network-md1400-pm8072-stage` (1)
- `./ops/plugins/network/bin/network-nvr-reip-canonical` (1)
- `./ops/plugins/network/bin/network-oob-guard-status` (1)
- `./ops/plugins/network/bin/network-pihole-blocklist-sync` (1)
- `./ops/plugins/network/bin/network-pve-post-cutover-harden` (1)
- `./ops/plugins/network/bin/network-shop-audit-canonical` (1)
- `./ops/plugins/network/bin/network-shop-audit-status` (1)
- `./ops/plugins/network/bin/network-shop-pihole-normalize` (1)
- `./ops/plugins/network/bin/network-unifi-clients-snapshot` (1)
- `./ops/plugins/observability/bin/immich-ingest-watch` (1)
- `./ops/plugins/observability/tests/immich-ingest-watch-test.sh` (1)
- `./ops/plugins/verify/bin/surface-audit-full` (1)
- `./ops/tools/infisical-agent.sh` (1)
- `./surfaces/verify/d130-boundary-authority-lock.sh` (1)
- `./surfaces/verify/d169-workbench-operator-smoke-lock.sh` (1)
- `./surfaces/verify/d48-codex-worktree-hygiene.sh` (1)
- `./surfaces/verify/d77-workbench-contract-lock.sh` (1)
- `./surfaces/verify/d78-workbench-path-lock.sh` (1)
- `./surfaces/verify/d79-workbench-script-allowlist-lock.sh` (1)
- `./surfaces/verify/d80-workbench-authority-trace-lock.sh` (1)
- `./surfaces/verify/tests/d78-test.sh` (1)

#### `spine` / `docs-examples`

- `./docs/planning/WORKBENCH_AOF_HARDENING_V2.md` (24)
- `./docs/governance/COMPOSE_AUTHORITY.md` (12)
- `./docs/governance/MACBOOK_SSOT.md` (12)
- `./docs/planning/MINT_PRINTS_FLOW_REPLACEMENT_ROADMAP_20260222.md` (10)
- `./docs/governance/GOVERNANCE_INDEX.md` (7)
- `./docs/governance/domains/communications/RUNBOOK.md` (6)
- `./README.md` (5)
- `./docs/governance/OPENCODE_GOVERNED_ENTRY.md` (5)
- `./docs/governance/PROPOSAL_FLOW_QUICKSTART.md` (5)
- `./docs/governance/SPINE_SCHEMA_CONVENTIONS.md` (5)
- `./docs/planning/MINT_SECRETS_BOOTSTRAP_PLAN.md` (4)
- `./docs/planning/WORKBENCH_AOF_NORMALIZATION_V1.md` (4)
- `./docs/governance/HOST_DRIFT_POLICY.md` (3)
- `./docs/governance/TERMINAL_C_DAILY_RUNBOOK.md` (3)
- `./docs/planning/MINT_TABLE_OWNERSHIP_MAP.md` (3)
- `./docs/brain/rules.md` (2)
- `./docs/core/EXTRACTION_PROTOCOL.md` (2)
- `./docs/governance/BACKUP_CALENDAR.md` (2)
- `./docs/governance/BACKUP_GOVERNANCE.md` (2)
- `./docs/governance/DR_RUNBOOK.md` (2)
- `./docs/governance/FINANCE_LEGACY_EXTRACTION_MATRIX.md` (2)
- `./docs/governance/GRAPH_BOUNDARY.md` (2)
- `./docs/governance/GRAPH_INDEX.md` (2)
- `./docs/governance/GRAPH_RUNBOOK.md` (2)
- `./docs/governance/HASS_AGENT_GOTCHAS.md` (2)
- `./docs/governance/HASS_INDEX.md` (2)
- `./docs/governance/HASS_LEGACY_EXTRACTION_MATRIX.md` (2)
- `./docs/governance/HASS_MCP_INTEGRATION.md` (2)
- `./docs/governance/HASS_OPERATIONAL_RUNBOOK.md` (2)
- `./docs/governance/HASS_SSOT_BASELINE.md` (2)
- `./docs/governance/HOME_BACKUP_STRATEGY.md` (2)
- `./docs/governance/HOME_NETWORK_AUDIT_RUNBOOK.md` (2)
- `./docs/governance/HOME_NETWORK_DEVICE_ONBOARDING.md` (2)
- `./docs/governance/IMMICH_LEGACY_EXTRACTION_MATRIX.md` (2)
- `./docs/governance/INFRASTRUCTURE_MAP.md` (2)
- `./docs/governance/N8N_RECOVERY_RUNBOOK.md` (2)
- `./docs/governance/NETWORK_POLICIES.md` (2)
- `./docs/governance/NETWORK_RUNBOOK.md` (2)
- `./docs/governance/ORCHESTRATION_CAPABILITY.md` (2)
- `./docs/governance/RTO_RPO.md` (2)
- `./docs/governance/SHOP_NETWORK_AUDIT_RUNBOOK.md` (2)
- `./docs/governance/SHOP_NETWORK_DEVICE_ONBOARDING.md` (2)
- `./docs/governance/SHOP_NETWORK_NORMALIZATION.md` (2)
- `./docs/governance/SHOP_SERVER_SSOT.md` (2)
- `./docs/governance/SHOP_VM_ARCHITECTURE.md` (2)
- `./docs/governance/domains/backup/BACKUP_CALENDAR.md` (2)
- `./docs/governance/domains/backup/BACKUP_GOVERNANCE.md` (2)
- `./docs/governance/domains/finance/FINANCE_LEGACY_EXTRACTION_MATRIX.md` (2)
- `./docs/governance/domains/finance/FINANCE_PILLAR_ARCHITECTURE.md` (2)
- `./docs/governance/domains/finance/FINANCE_PILLAR_EXTRACTION_STATUS.md` (2)
- `./docs/governance/domains/finance/FINANCE_PILLAR_README.md` (2)
- `./docs/governance/domains/home-assistant/HASS_AGENT_GOTCHAS.md` (2)
- `./docs/governance/domains/home-assistant/HASS_INDEX.md` (2)
- `./docs/governance/domains/home-assistant/HASS_LEGACY_EXTRACTION_MATRIX.md` (2)
- `./docs/governance/domains/home-assistant/HASS_MCP_INTEGRATION.md` (2)
- `./docs/governance/domains/home-assistant/HASS_OPERATIONAL_RUNBOOK.md` (2)
- `./docs/governance/domains/home-assistant/HASS_SSOT_BASELINE.md` (2)
- `./docs/governance/domains/home/HOME_BACKUP_STRATEGY.md` (2)
- `./docs/governance/domains/home/HOME_NETWORK_AUDIT_RUNBOOK.md` (2)
- `./docs/governance/domains/home/HOME_NETWORK_DEVICE_ONBOARDING.md` (2)
- `./docs/governance/domains/immich/IMMICH_LEGACY_EXTRACTION_MATRIX.md` (2)
- `./docs/governance/domains/ms-graph/GRAPH_BOUNDARY.md` (2)
- `./docs/governance/domains/ms-graph/GRAPH_INDEX.md` (2)
- `./docs/governance/domains/ms-graph/GRAPH_RUNBOOK.md` (2)
- `./docs/governance/domains/n8n/N8N_RECOVERY_RUNBOOK.md` (2)
- `./docs/governance/domains/network/NETWORK_POLICIES.md` (2)
- `./docs/governance/domains/network/NETWORK_RUNBOOK.md` (2)
- `./docs/governance/domains/recovery/DR_RUNBOOK.md` (2)
- `./docs/governance/domains/recovery/RTO_RPO.md` (2)
- `./docs/governance/domains/shop/SHOP_NETWORK_AUDIT_RUNBOOK.md` (2)
- `./docs/governance/domains/shop/SHOP_NETWORK_DEVICE_ONBOARDING.md` (2)
- `./docs/governance/domains/shop/SHOP_NETWORK_NORMALIZATION.md` (2)
- `./docs/governance/domains/shop/SHOP_SERVER_SSOT.md` (2)
- `./docs/governance/domains/shop/SHOP_VM_ARCHITECTURE.md` (2)
- `./docs/pillars/finance/ARCHITECTURE.md` (2)
- `./docs/pillars/finance/EXTRACTION_STATUS.md` (2)
- `./docs/pillars/finance/README.md` (2)
- `./docs/planning/AOF_STANDARDS_PACK_V1.md` (2)
- `./docs/planning/MINT_AUTH_CONTRACT_V1.md` (2)
- `./docs/planning/MINT_ORDER_LIFECYCLE_CONTRACT_V1.md` (2)
- `./docs/planning/RONNY_OPS_FINAL_EXTRACTION_SWEEP_V1.md` (2)
- `./fixtures/n8n/README.md` (2)
- `./docs/brain/README.md` (1)
- `./docs/governance/BUILD_MODE_CHECKLIST.md` (1)
- `./docs/governance/CLAUDE_ENTRYPOINT_SHIM.md` (1)
- `./docs/governance/CORE_AGENTIC_SCOPE.md` (1)
- `./docs/governance/MAILROOM_BRIDGE.md` (1)
- `./docs/governance/MINT_AGENT_GOLDEN_LOOP.md` (1)
- `./docs/governance/ONBOARDING_PLAYBOOK.md` (1)
- `./docs/governance/PHASE4_OBSERVABILITY_RUNBOOK.md` (1)
- `./docs/governance/POST_GAP_OPERATING_MODEL.md` (1)
- `./docs/governance/RELEASE_PROTOCOL.md` (1)
- `./docs/governance/SCRIPTS_AUTHORITY.md` (1)
- `./docs/governance/SPINE_CONTROL_LOOP.md` (1)
- `./docs/governance/SPINE_INDEX.md` (1)
- `./docs/governance/STACK_AUTHORITY.md` (1)
- `./docs/governance/WORKBENCH_SHARE_PROTOCOL.md` (1)
- `./docs/legacy/brain-lessons/README.md` (1)
- `./docs/planning/AOF_WORKBENCH_NORMALIZATION_IMPLEMENTATION_PLAN_20260217.md` (1)
- `./docs/planning/CODEBASE_CLEANUP_EXEC_QUEUE_20260222.md` (1)
- `./docs/planning/MINT_RUNTIME_STANDARD_20260222.md` (1)
- `./docs/planning/MINT_TUNNEL_MIGRATION_PLAN.md` (1)
- `./docs/product/AOF_V1_1_SURFACE_UNIFICATION.md` (1)
- `./docs/product/MINT_AOF_CONTRACT_V1.md` (1)

#### `workbench` / `contract-sensitive`

- `./dotfiles/macbook/launchd/com.ronny.agent-inbox.plist` (9)
- `./dotfiles/raycast/spine-attach-loop.sh` (3)
- `./dotfiles/raycast/spine-launcher.sh` (2)
- `./scripts/agents/sync-domain-capability-catalogs.sh` (2)
- `./agents/communications/tools/.env.example` (1)
- `./agents/communications/tools/src/index.ts` (1)
- `./agents/immich/tools/immich_ingest_watchdog.py` (1)
- `./agents/ms-graph/tools/spine-plugin-ms-graph/bin/graph-cap-exec` (1)
- `./dotfiles/opencode/opencode.json` (1)
- `./dotfiles/raycast/claude-code.sh` (1)
- `./dotfiles/raycast/codex.sh` (1)
- `./dotfiles/raycast/opencode.sh` (1)
- `./dotfiles/raycast/spine-audit.sh` (1)
- `./dotfiles/raycast/spine-calendar-today.sh` (1)
- `./dotfiles/raycast/spine-comms-flush.sh` (1)
- `./dotfiles/raycast/spine-control.sh` (1)
- `./dotfiles/raycast/spine-execution.sh` (1)
- `./dotfiles/raycast/spine-proposals-preflight.sh` (1)
- `./dotfiles/raycast/spine-start.sh` (1)
- `./dotfiles/raycast/spine-watcher.sh` (1)
- `./infra/compose/finance/scripts/simplefin-daily-sync.sh` (1)
- `./infra/contracts/workbench.aof.contract.yaml` (1)
- `./infra/scripts/home-assistant/ha-cli.sh` (1)
- `./scripts/agents/cloudflare-agent.sh` (1)
- `./scripts/root/operator/proposals-preflight.sh` (1)
- `./scripts/root/spine_terminal_entry.sh` (1)
- `./scripts/root/sync_laptop_hotkeys_docs.sh` (1)

#### `workbench` / `docs-examples`

- `./dotfiles/macbook/README.md` (14)
- `./dotfiles/opencode/OPENCODE.md` (8)
- `./agents/finance/docs/RUNBOOK.md` (4)
- `./agents/finance/docs/CONTEXT_LOCK.md` (2)
- `./agents/mint-agent/docs/RUNBOOK.md` (2)
- `./agents/n8n/playbooks/receipt_hooks.md` (2)
- `./dotfiles/macbook/launchd/LAUNCHD_RETIREMENT_2026-02-06.md` (2)
- `./agents/finance/docs/CAPABILITIES.md` (1)
- `./agents/home-assistant/docs/CAPABILITIES.md` (1)
- `./agents/immich/docs/CAPABILITIES.md` (1)
- `./agents/media/docs/notes/20260216__CAP-20260216-073454__docs.impact.status__Rotgi1720.md` (1)
- `./agents/mint-agent/docs/CAPABILITIES.md` (1)
- `./agents/mint-agent/tools/README.md` (1)
- `./agents/ms-graph/docs/BOUNDARY.md` (1)
- `./agents/ms-graph/docs/CAPABILITIES.md` (1)
- `./agents/n8n/docs/CAPABILITIES.md` (1)
- `./agents/n8n/docs/INFRA_RELIABILITY.md` (1)
- `./agents/n8n/docs/notes/20260216__CAP-20260216-072745__verify.pack.list__Rydqx61858.md` (1)
- `./docs/CAPABILITY_DOMAIN_INDEX.md` (1)
- `./docs/infrastructure/domains/backup/CAPABILITIES.md` (1)
- `./docs/infrastructure/domains/home/CAPABILITIES.md` (1)
- `./docs/infrastructure/domains/network/CAPABILITIES.md` (1)
- `./dotfiles/opencode/commands/ralph-loop.md` (1)
- `./dotfiles/opencode/commands/ulw.md` (1)

## Phase A.3 Temporal Field Inventory

### Totals by key

| Field | Occurrences | Files |
|---|---:|---:|
| `updated_at` | 83 | 83 |
| `updated` | 75 | 66 |
| `last_verified` | 489 | 467 |

### Totals by key + file class

| Field | Class | Occurrences |
|---|---|---:|
| `last_verified` | `binding` | 27 |
| `last_verified` | `doc` | 408 |
| `last_verified` | `generated` | 20 |
| `last_verified` | `other` | 34 |
| `updated` | `binding` | 42 |
| `updated` | `doc` | 12 |
| `updated` | `generated` | 1 |
| `updated` | `other` | 20 |
| `updated_at` | `binding` | 78 |
| `updated_at` | `generated` | 1 |
| `updated_at` | `other` | 4 |

<details><summary><code>updated_at</code> file list (83)</summary>

- `/Users/ronnyworks/code/agentic-spine/docs/governance/generated/W20_NORMALIZATION_PATCH_PLAN_20260223.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/agent.entrypoint.lock.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/agents.registry.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/alerting.rules.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/audit.suppressions.policy.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/backup.calendar.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/binding.freshness.exemptions.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/briefing.config.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/calendar.global.schema.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/calendar.global.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/calendar.sync.contract.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/capability.domain.catalog.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/change.intake.policy.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/cli.tools.inventory.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/communications.alerts.escalation.contract.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/communications.alerts.queue.contract.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/communications.delivery.contract.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/communications.policy.contract.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/communications.providers.contract.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/communications.stack.contract.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/communications.templates.catalog.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/cross-repo.authority.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/cutover.sequencing.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/deploy.dependencies.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/deprecated-project-allowlist.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/deprecated.terms.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/docs.impact.contract.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/docs.johnny_decimal.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/domain.docs.routes.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/drift-gates.scoped.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/entry.surface.contract.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/environment.contract.schema.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/evidence.retention.policy.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/extraction.mode.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/fabric.boundary.contract.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/gate.agent.profiles.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/gate.domain.profiles.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/governance.parity.reconcile.20260217.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/ha.identity.mutation.contract.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/handoff.config.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/home.output.sinks.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/host.audit.allowlist.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/identity.contract.schema.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/immich.ingest.watch.contract.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/infra.placement.policy.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/infra.relocation.plan.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/infra.vm.profiles.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/launchd.runtime.contract.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/legacy.entrypoint.exceptions.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/lifecycle.rules.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/lifecycle.standards.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/mailroom.bridge.consumers.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/mailroom.bridge.endpoints.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/mailroom.bridge.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/mailroom.runtime.contract.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/maker.tools.inventory.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/mcp.runtime.contract.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/media.services.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/n8n.infra.reliability.contract.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/naming.policy.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/policy.autotune.contract.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/policy.autotune.rules.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/policy.presets.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/policy.runtime.contract.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/proactive.guard.policy.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/proposals.lifecycle.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/rag.embedding.backend.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/rag.metrics.normalization.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/rag.pipeline.contract.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/rag.reindex.quality.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/rag.remote.runner.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/rag.workspace.contract.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/receipts.index.schema.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/spine.execution.graph.schema.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/spine.execution.graph.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/spine.schema.conventions.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/spine.timeline.event.schema.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/stabilization.mode.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/terminal.role.contract.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/plugins/communications/tests/test-communications-live-pilot.sh` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/plugins/evidence/tests/spine-timeline-report-test.sh` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/plugins/orchestration/bin/orchestration-loop-open` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/plugins/orchestration/manifest.schema.yaml` (1)

</details>

<details><summary><code>updated</code> file list (66)</summary>

- `/Users/ronnyworks/code/agentic-spine/SPINE_SCAFFOLD.md` (1)
- `/Users/ronnyworks/code/agentic-spine/bin/generate-scaffold.sh` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/brain/generate-context.sh` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/core/INFISICAL_PROJECTS.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/ISSUE_CLOSURE_SOP.md` (2)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/SSOT_REGISTRY.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/generated/W20_NORMALIZATION_PATCH_PLAN_20260223.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/automation.stack.latency.slo.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/capability.domain.catalog.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/d128-gate-mutation-policy.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/deploy.method.contract.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/gate.execution.topology.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/gate.registry.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/infra.core.slo.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/lifecycle.rules.schema.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/lifecycle.rules.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/mint.rank5plus.cutover.contract.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/operational.gaps.yaml` (3)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/operator.smoothness.contract.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/plugin.migration.bulk.plan.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/plugin.migration.inventory.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/plugin.migration.pilot.plan.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/plugin.ownership.map.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/receipts.archival.policy.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/secrets.bundle.contract.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/secrets.credentials.parity.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/secrets.namespace.policy.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/secrets.runway.contract.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/share.publish.allowlist.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/share.publish.denylist.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/share.publish.remote.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/spine.boundary.baseline.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/stability.control.contract.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/startup.sequencing.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/surface.readonly.contract.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/tenant.profile.schema.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/tenant.storage.contract.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/tenants/media-stack.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/verify.ring.policy.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/version.compat.matrix.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/vertical.integration.admission.contract.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/vm.lifecycle.contract.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/vm.lifecycle.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/vm.operating.profile.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/weekly.execution.telemetry.contract.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/worktree.session.isolation.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/capabilities.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/plugins/calendar/tests/test-calendar-sync-execute.sh` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/staged/evidence/GITEA_SSO_BROWSER_TEST_20260209.md` (1)
- `/Users/ronnyworks/code/agentic-spine/surfaces/verify/d58-ssot-freshness-lock.sh` (2)
- `/Users/ronnyworks/code/agentic-spine/surfaces/verify/tests/d58-test.sh` (1)
- `/Users/ronnyworks/code/agentic-spine/surfaces/verify/tests/d93-test.sh` (1)
- `/Users/ronnyworks/code/agentic-spine/surfaces/verify/tests/d94-test.sh` (1)
- `/Users/ronnyworks/code/agentic-spine/surfaces/verify/tests/d95-test.sh` (1)
- `/Users/ronnyworks/code/agentic-spine/surfaces/verify/tests/d96-test.sh` (1)
- `/Users/ronnyworks/code/agentic-spine/surfaces/verify/tests/d97-test.sh` (1)
- `/Users/ronnyworks/code/agentic-spine/surfaces/verify/tests/proposals-apply-admission-test.sh` (6)
- `/Users/ronnyworks/code/workbench/docs/legacy/guides/20-terminal-workflow.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/REF_N8N_CREDENTIALS.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/top-level/INDEX.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/top-level/RUNBOOK_INDEX.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/runbooks/RUNBOOK_INCIDENT.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/runbooks/RUNBOOK_REPO_DOC_RULES.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/runbooks/TEST_COVERAGE_MATRIX.md` (1)
- `/Users/ronnyworks/code/workbench/infra/contracts/workbench.aof.contract.yaml` (1)
- `/Users/ronnyworks/code/workbench/scripts/root/cf-tunnel-ingress.sh` (1)

</details>

<details><summary><code>last_verified</code> file list (467)</summary>

- `/Users/ronnyworks/code/agentic-spine/AGENTS.md` (1)
- `/Users/ronnyworks/code/agentic-spine/README.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/CONTRIBUTING.md` (2)
- `/Users/ronnyworks/code/agentic-spine/docs/brain/memory.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/core/PROJECT_GOVERNANCE_CONTRACT.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/core/PROPOSAL_FORMAT.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/core/REPLAY_FIXTURES.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/core/STACK_LIFECYCLE.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/core/VM_CREATION_CONTRACT.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/AGENTS_GOVERNANCE.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/AGENTS_LOCATION.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/AGENT_BOUNDARIES.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/AGENT_GOVERNANCE_BRIEF.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/AGENT_TERMINOLOGY_GLOSSARY.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/ARCHIVE_POLICY.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/AUDITS_MIGRATION_TARGETS_V1.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/AUDIT_VERIFICATION.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/AUTHENTIK_BACKUP_RESTORE.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/BACKUP_CALENDAR.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/BACKUP_GOVERNANCE.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/BUILD_MODE_CHECKLIST.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/CAMERA_SSOT.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/CHANGE_PACK_TEMPLATE.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/CLAUDE_ENTRYPOINT_SHIM.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/COMPOSE_AUTHORITY.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/CORE_AGENTIC_SCOPE.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/DEVICE_IDENTITY_SSOT.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/DR_RUNBOOK.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/EXCLUDED_SURFACES.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/FINANCE_LEGACY_EXTRACTION_MATRIX.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/GAP_LIFECYCLE.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/GATE_AUTHORING_GUIDE.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/GITEA_BACKUP_RESTORE.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/GIT_REMOTE_AUTHORITY.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/GOVERNANCE_INDEX.md` (2)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/GRAPH_BOUNDARY.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/GRAPH_INDEX.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/GRAPH_RUNBOOK.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/HASS_AGENT_GOTCHAS.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/HASS_INDEX.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/HASS_LEGACY_EXTRACTION_MATRIX.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/HASS_MCP_INTEGRATION.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/HASS_OPERATIONAL_RUNBOOK.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/HASS_SSOT_BASELINE.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/HEALTH_TIMELINE_POLICY.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/HOME_BACKUP_STRATEGY.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/HOME_NETWORK_AUDIT_RUNBOOK.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/HOME_NETWORK_DEVICE_ONBOARDING.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/HOST_DRIFT_POLICY.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/HYGIENE_WEEKLY_CADENCE_RUNBOOK.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/IMMICH_LEGACY_EXTRACTION_MATRIX.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/INFISICAL_BACKUP_RESTORE.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/INFISICAL_RESTORE_DRILL.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/[deprecated-authority-doc].md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/INFRASTRUCTURE_MAP.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/INFRA_RELOCATION_PROTOCOL.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/INGRESS_AUTHORITY.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/IPHONE_MCP_SETUP.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/ISSUE_CLOSURE_SOP.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/LEGACY_DEPRECATION.md` (2)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/MACBOOK_BOOTSTRAP_CONTRACT.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/MACBOOK_SSOT.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/MAILROOM_BRIDGE.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/MAILROOM_RUNBOOK.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/MAKER_TOOLS_GOVERNANCE.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/MINILAB_SSOT.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/MINT_AGENT_GOLDEN_LOOP.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/MINT_PRODUCT_GOVERNANCE.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/MINT_RANK5PLUS_EXECUTION_RUNBOOK.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/N8N_RECOVERY_RUNBOOK.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/NETWORK_POLICIES.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/NETWORK_RUNBOOK.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/ONBOARDING_PLAYBOOK.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/OPENCODE_GOVERNED_ENTRY.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/OPS_PATCH_HISTORY.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/ORCHESTRATION_CAPABILITY.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/OUTPUT_CONTRACTS.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/P1_GOVERNANCE_PARITY_RECONCILIATION_20260217.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/PATCH_CADENCE.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/PHASE4_OBSERVABILITY_RUNBOOK.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/PORTABILITY_ASSUMPTIONS.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/POST_GAP_OPERATING_MODEL.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/PROPOSAL_FLOW_QUICKSTART.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/PROPOSAL_LIFECYCLE_REFERENCE.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/RAG_INDEXING_RULES.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/RAG_PASSIVE_PIPELINE_PROTOCOL.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/RAG_QUERY_PATTERNS.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/RAG_REINDEX_RUNBOOK.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/REBOOT_HEALTH_GATE.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/RECEIPTS_ARCHIVAL_POLICY_V1.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/RELEASE_PROTOCOL.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/REPO_STRUCTURE_AUTHORITY.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/RTO_RPO.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/RUNWAY_TOOLING_PRODUCT_OPERATING_CONTRACT_V1.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/SCRIPTS_AUTHORITY.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/SCRIPTS_REGISTRY.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/SEARCH_EXCLUSIONS.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/SECRETS_POLICY.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/SECURITY_POLICIES.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/SESSION_PROTOCOL.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/SHOP_NETWORK_AUDIT_RUNBOOK.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/SHOP_NETWORK_DEVICE_ONBOARDING.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/SHOP_NETWORK_NORMALIZATION.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/SHOP_SERVER_SSOT.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/SHOP_VM_ARCHITECTURE.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/SPINE_BASELINE_FREEZE_V1.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/SPINE_BASELINE_LOCK_V1.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/SPINE_CONTROL_LOOP.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/SPINE_EXECUTION_GRAPH.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/SPINE_INDEX.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/SPINE_SCHEMA_CONVENTIONS.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/SPINE_TIMELINE_RUNBOOK.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/SSOT_REGISTRY.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/SSOT_UPDATE_TEMPLATE.md` (2)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/STACK_AUTHORITY.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/TERMINAL_C_DAILY_RUNBOOK.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/TERMINAL_WORKER_RUNTIME_CONTRACT_V2.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/VAULTWARDEN_BACKUP_RESTORE.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/VERIFY_SURFACE_INDEX.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/WAVE_ORCHESTRATION_V1_RUNBOOK.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/WORKBENCH_D164_SCOPE_EXPANSION_PLAN.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/WORKBENCH_SHARE_PROTOCOL.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/WORKBENCH_TOOLING_INDEX.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/WORKER_LANE_TEMPLATE_PACK.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/_index.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/domains/CAPABILITIES_INDEX.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/domains/FABRIC_BOUNDARY_CONTRACT.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/domains/README.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/domains/backup/BACKUP_CALENDAR.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/domains/backup/BACKUP_GOVERNANCE.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/domains/backup/CAPABILITIES.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/domains/communications/CAPABILITIES.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/domains/communications/RUNBOOK.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/domains/finance/CAPABILITIES.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/domains/finance/FINANCE_LEGACY_EXTRACTION_MATRIX.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/domains/finance/FINANCE_PILLAR_ARCHITECTURE.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/domains/finance/FINANCE_PILLAR_EXTRACTION_STATUS.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/domains/finance/FINANCE_PILLAR_README.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/domains/home-assistant/CAPABILITIES.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/domains/home-assistant/HASS_AGENT_GOTCHAS.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/domains/home-assistant/HASS_INDEX.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/domains/home-assistant/HASS_LEGACY_EXTRACTION_MATRIX.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/domains/home-assistant/HASS_MCP_INTEGRATION.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/domains/home-assistant/HASS_OPERATIONAL_RUNBOOK.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/domains/home-assistant/HASS_SSOT_BASELINE.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/domains/home/CAPABILITIES.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/domains/home/HOME_BACKUP_STRATEGY.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/domains/home/HOME_NETWORK_AUDIT_RUNBOOK.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/domains/home/HOME_NETWORK_DEVICE_ONBOARDING.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/domains/immich/CAPABILITIES.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/domains/immich/IMMICH_LEGACY_EXTRACTION_MATRIX.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/domains/immich/IMMICH_MAINTAINER_AGENT_PROPOSAL.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/domains/immich/IMMICH_POST_INGEST_RECON_AGENT_PROPOSAL.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/domains/media/CAPABILITIES.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/domains/mint/CAPABILITIES.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/domains/ms-graph/CAPABILITIES.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/domains/ms-graph/GRAPH_BOUNDARY.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/domains/ms-graph/GRAPH_INDEX.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/domains/ms-graph/GRAPH_RUNBOOK.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/domains/n8n/CAPABILITIES.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/domains/n8n/N8N_RECOVERY_RUNBOOK.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/domains/network/CAPABILITIES.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/domains/network/NETWORK_POLICIES.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/domains/network/NETWORK_RUNBOOK.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/domains/recovery/DR_RUNBOOK.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/domains/recovery/RTO_RPO.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/domains/shop/SHOP_NETWORK_AUDIT_RUNBOOK.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/domains/shop/SHOP_NETWORK_DEVICE_ONBOARDING.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/domains/shop/SHOP_NETWORK_NORMALIZATION.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/domains/shop/SHOP_SERVER_SSOT.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/domains/shop/SHOP_VM_ARCHITECTURE.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/generated/SPINE_WEEKLY_HYGIENE_RUNBOOK.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/generated/W20_NORMALIZATION_PATCH_PLAN_20260223.yaml` (2)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/generated/W20_NORMALIZATION_STRATEGY_20260223.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/generated/worker-usage/DEPLOY-MINT-01.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/generated/worker-usage/DEPLOY-MINTOS-01.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/generated/worker-usage/DOMAIN-COMMS-01.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/generated/worker-usage/DOMAIN-FINANCE-01.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/generated/worker-usage/DOMAIN-FIREFLY-01.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/generated/worker-usage/DOMAIN-HA-01.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/generated/worker-usage/DOMAIN-MEDIA-01.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/generated/worker-usage/DOMAIN-MSGRAPH-01.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/generated/worker-usage/DOMAIN-N8N-01.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/generated/worker-usage/DOMAIN-PAPERLESS-01.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/generated/worker-usage/README.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/generated/worker-usage/RUNTIME-IMMICH-01.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/generated/worker-usage/SPINE-AUDIT-01.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/generated/worker-usage/SPINE-CONTROL-01.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/generated/worker-usage/SPINE-EXECUTION-01.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/generated/worker-usage/SPINE-WATCHER-01.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/schemas/agents.registry.v2-fields.schema.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/schemas/routing.dispatch.schema.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/schemas/terminal.launcher.view.schema.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/schemas/terminal.worker.catalog.schema.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/governance/schemas/worker-usage.doc.schema.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/jd/00.00-index.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/jd/README.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/pillars/finance/ARCHITECTURE.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/pillars/finance/EXTRACTION_STATUS.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/pillars/finance/README.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/planning/AOF_WORKBENCH_NORMALIZATION_IMPLEMENTATION_PLAN_20260217.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/planning/MINT_FRESH_SLATE_INFRA_BOOTSTRAP_RUNBOOK.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/planning/RONNY_OPS_FINAL_EXTRACTION_SWEEP_V1.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/planning/WORKBENCH_AOF_HARDENING_V2.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/planning/WORKBENCH_AOF_NORMALIZATION_V1.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/product/AOF_ACCEPTANCE_GATES.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/product/AOF_DEPLOYMENT_PLAYBOOK.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/product/AOF_EVIDENCE_RETENTION_EXPORT.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/product/AOF_POLICY_RUNTIME_ENFORCEMENT.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/product/AOF_PRODUCT_CONTRACT.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/product/AOF_SUPPORT_SLO.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/product/AOF_SURFACE_READONLY_CONTRACT.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/product/AOF_TENANT_STORAGE_MODEL.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/product/AOF_V1_1_SURFACE_UNIFICATION.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/product/AOF_VERSION_COMPATIBILITY.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/product/MINT_AOF_ACCEPTANCE_V1.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/product/MINT_AOF_CONTRACT_V1.md` (1)
- `/Users/ronnyworks/code/agentic-spine/docs/product/MINT_AOF_ENFORCEMENT_V1.md` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/agents/workbench-agent.contract.md` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/calendar.sync.contract.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/capability.domain.catalog.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/ha.sync.config.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/lane.profiles.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/mailroom.bridge.consumers.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/mailroom.bridge.endpoints.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/mailroom.runtime.contract.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/mailroom.task.worker.contract.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/registry.ownership.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/routing.dispatch.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/runtime.manifest.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/spine.boundary.baseline.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/spine.execution.graph.schema.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/spine.execution.graph.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/spine.schema.conventions.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/spine.timeline.event.schema.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/stabilization.mode.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/terminal.launcher.view.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/terminal.role.contract.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/terminal.worker.catalog.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/wave.lifecycle.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/wave.lock.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/workbench.deploy.method.surface.contract.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/workbench.operator.surface.contract.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/workbench.secrets.onboarding.contract.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/workbench.ssh.attach.contract.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/workbench.ssh.runtime.surface.contract.yaml` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/commands/start.sh` (3)
- `/Users/ronnyworks/code/agentic-spine/ops/plugins/aof/bin/aof-version.sh` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/plugins/docs/bin/docs-impact-note` (1)
- `/Users/ronnyworks/code/agentic-spine/ops/plugins/evidence/tests/spine-timeline-report-test.sh` (1)
- `/Users/ronnyworks/code/agentic-spine/surfaces/commands/check.md` (1)
- `/Users/ronnyworks/code/agentic-spine/surfaces/commands/ctx.md` (1)
- `/Users/ronnyworks/code/agentic-spine/surfaces/commands/fix.md` (1)
- `/Users/ronnyworks/code/agentic-spine/surfaces/commands/gaps.md` (1)
- `/Users/ronnyworks/code/agentic-spine/surfaces/commands/gates.md` (1)
- `/Users/ronnyworks/code/agentic-spine/surfaces/commands/howto.md` (1)
- `/Users/ronnyworks/code/agentic-spine/surfaces/commands/loop.md` (2)
- `/Users/ronnyworks/code/agentic-spine/surfaces/commands/propose.md` (1)
- `/Users/ronnyworks/code/agentic-spine/surfaces/commands/triage.md` (1)
- `/Users/ronnyworks/code/agentic-spine/surfaces/commands/verify.md` (1)
- `/Users/ronnyworks/code/agentic-spine/surfaces/verify/d156-governance-freshness-and-receipts-policy-lock.sh` (1)
- `/Users/ronnyworks/code/agentic-spine/surfaces/verify/tests/d91-test.sh` (1)
- `/Users/ronnyworks/code/agentic-spine/surfaces/verify/tests/d93-test.sh` (1)
- `/Users/ronnyworks/code/agentic-spine/surfaces/verify/tests/d94-test.sh` (1)
- `/Users/ronnyworks/code/agentic-spine/surfaces/verify/tests/d95-test.sh` (1)
- `/Users/ronnyworks/code/agentic-spine/surfaces/verify/tests/d96-test.sh` (1)
- `/Users/ronnyworks/code/agentic-spine/surfaces/verify/tests/d97-test.sh` (1)
- `/Users/ronnyworks/code/workbench/agents/finance/docs/FINANCE_LEGACY_EXTRACTION_MATRIX.md` (1)
- `/Users/ronnyworks/code/workbench/agents/finance/docs/FINANCE_PILLAR_ARCHITECTURE.md` (1)
- `/Users/ronnyworks/code/workbench/agents/finance/docs/FINANCE_PILLAR_EXTRACTION_STATUS.md` (1)
- `/Users/ronnyworks/code/workbench/agents/finance/docs/FINANCE_PILLAR_README.md` (1)
- `/Users/ronnyworks/code/workbench/agents/home-assistant/docs/HASS_AGENT_GOTCHAS.md` (1)
- `/Users/ronnyworks/code/workbench/agents/home-assistant/docs/HASS_INDEX.md` (1)
- `/Users/ronnyworks/code/workbench/agents/home-assistant/docs/HASS_LEGACY_EXTRACTION_MATRIX.md` (1)
- `/Users/ronnyworks/code/workbench/agents/home-assistant/docs/HASS_OPERATIONAL_RUNBOOK.md` (1)
- `/Users/ronnyworks/code/workbench/agents/home-assistant/docs/HASS_SSOT_BASELINE.md` (1)
- `/Users/ronnyworks/code/workbench/agents/immich/docs/IMMICH_LEGACY_EXTRACTION_MATRIX.md` (1)
- `/Users/ronnyworks/code/workbench/agents/media/docs/notes/20260216__CAP-20260216-073454__docs.impact.status__Rotgi1720.md` (1)
- `/Users/ronnyworks/code/workbench/agents/n8n/docs/N8N_RECOVERY_RUNBOOK.md` (1)
- `/Users/ronnyworks/code/workbench/agents/n8n/docs/notes/20260216__CAP-20260216-072745__verify.pack.list__Rydqx61858.md` (1)
- `/Users/ronnyworks/code/workbench/archive/[deprecated-archive-label]-retirement-20260217/ARCHIVE_INDEX.md` (1)
- `/Users/ronnyworks/code/workbench/docs/brain-lessons/CLOUDFLARE_GOVERNANCE.md` (1)
- `/Users/ronnyworks/code/workbench/docs/brain-lessons/DOWNLOAD_HOME_NOTES.md` (1)
- `/Users/ronnyworks/code/workbench/docs/brain-lessons/EMBROIDERY_LIBRARY.md` (1)
- `/Users/ronnyworks/code/workbench/docs/brain-lessons/FINANCE_ACCOUNT_TOPOLOGY.md` (1)
- `/Users/ronnyworks/code/workbench/docs/brain-lessons/FINANCE_BACKUP_RESTORE.md` (1)
- `/Users/ronnyworks/code/workbench/docs/brain-lessons/FINANCE_DEPLOY_RUNBOOK.md` (1)
- `/Users/ronnyworks/code/workbench/docs/brain-lessons/FINANCE_IMPORT_CONFIGS.md` (1)
- `/Users/ronnyworks/code/workbench/docs/brain-lessons/FINANCE_N8N_WORKFLOWS.md` (1)
- `/Users/ronnyworks/code/workbench/docs/brain-lessons/FINANCE_RECEIPT_SCANNING.md` (1)
- `/Users/ronnyworks/code/workbench/docs/brain-lessons/FINANCE_RECONCILIATION.md` (1)
- `/Users/ronnyworks/code/workbench/docs/brain-lessons/FINANCE_SIMPLEFIN_PIPELINE.md` (1)
- `/Users/ronnyworks/code/workbench/docs/brain-lessons/FINANCE_STACK_ARCHITECTURE.md` (1)
- `/Users/ronnyworks/code/workbench/docs/brain-lessons/FINANCE_TROUBLESHOOTING.md` (1)
- `/Users/ronnyworks/code/workbench/docs/brain-lessons/HA_CLI_PATTERNS.md` (1)
- `/Users/ronnyworks/code/workbench/docs/brain-lessons/HA_DASHBOARD_BRAND.md` (1)
- `/Users/ronnyworks/code/workbench/docs/brain-lessons/HA_DEVICE_REGISTRY.md` (1)
- `/Users/ronnyworks/code/workbench/docs/brain-lessons/HA_RUNBOOKS.md` (1)
- `/Users/ronnyworks/code/workbench/docs/brain-lessons/HOME_ASSISTANT_LESSONS.md` (1)
- `/Users/ronnyworks/code/workbench/docs/brain-lessons/IMMICH_BACKUP_RESTORE.md` (1)
- `/Users/ronnyworks/code/workbench/docs/brain-lessons/IMMICH_OPERATIONS_LESSONS.md` (1)
- `/Users/ronnyworks/code/workbench/docs/brain-lessons/IMMICH_PHOTO_RULES.md` (1)
- `/Users/ronnyworks/code/workbench/docs/brain-lessons/INCIDENTS_LOG.md` (1)
- `/Users/ronnyworks/code/workbench/docs/brain-lessons/MCPJUNGLE_RECOVERY.md` (1)
- `/Users/ronnyworks/code/workbench/docs/brain-lessons/MEDIA_CRITICAL_RULES.md` (1)
- `/Users/ronnyworks/code/workbench/docs/brain-lessons/MEDIA_DOWNLOAD_ARCHITECTURE.md` (1)
- `/Users/ronnyworks/code/workbench/docs/brain-lessons/MEDIA_PIPELINE_ARCHITECTURE.md` (1)
- `/Users/ronnyworks/code/workbench/docs/brain-lessons/MEDIA_TDARR_RUNBOOK.md` (1)
- `/Users/ronnyworks/code/workbench/docs/brain-lessons/N8N_OPERATIONS.md` (1)
- `/Users/ronnyworks/code/workbench/docs/brain-lessons/NAVIDROME_INTEGRATION.md` (1)
- `/Users/ronnyworks/code/workbench/docs/brain-lessons/PIHOLE_HOME_LESSONS.md` (1)
- `/Users/ronnyworks/code/workbench/docs/brain-lessons/RECEIPT_DEBT_APPENDIX.md` (1)
- `/Users/ronnyworks/code/workbench/docs/brain-lessons/SERVICE_UPDATE_TIERS.md` (1)
- `/Users/ronnyworks/code/workbench/docs/brain-lessons/VAULTWARDEN_HOME_RUNBOOK.md` (1)
- `/Users/ronnyworks/code/workbench/docs/governance/WORKBENCH_ACTIVE_SURFACE_OWNERSHIP_REGISTRY.md` (1)
- `/Users/ronnyworks/code/workbench/docs/governance/WORKBENCH_BASELINE_FREEZE_V1.md` (1)
- `/Users/ronnyworks/code/workbench/docs/governance/WORKBENCH_COMMUNICATIONS_OPERATIONS_CONTRACT.md` (1)
- `/Users/ronnyworks/code/workbench/docs/governance/WORKBENCH_DEPLOYMENT_METHOD_CONTRACT.md` (1)
- `/Users/ronnyworks/code/workbench/docs/governance/WORKBENCH_IDENTITY_SECRETS_ONBOARDING_CONTRACT.md` (1)
- `/Users/ronnyworks/code/workbench/docs/governance/WORKBENCH_MINT_MODULES_OPERATIONS_CONTRACT.md` (1)
- `/Users/ronnyworks/code/workbench/docs/governance/WORKBENCH_OPERATOR_CALENDAR_SURFACE.md` (1)
- `/Users/ronnyworks/code/workbench/docs/governance/WORKBENCH_SHELL_SCRIPT_CONVENTION.md` (1)
- `/Users/ronnyworks/code/workbench/docs/infrastructure/AUTHORITY_INDEX.md` (1)
- `/Users/ronnyworks/code/workbench/docs/infrastructure/CONTAINER_INVENTORY.md` (1)
- `/Users/ronnyworks/code/workbench/docs/infrastructure/LEGACY_SCRIPT_BUNDLE_PARITY_20260217.md` (1)
- `/Users/ronnyworks/code/workbench/docs/infrastructure/MCP_AUTHORITY.md` (1)
- `/Users/ronnyworks/code/workbench/docs/infrastructure/WORKBENCH_AOF_BASELINE.md` (1)
- `/Users/ronnyworks/code/workbench/docs/infrastructure/domains/backup/BACKUP_CALENDAR.md` (1)
- `/Users/ronnyworks/code/workbench/docs/infrastructure/domains/backup/BACKUP_GOVERNANCE.md` (1)
- `/Users/ronnyworks/code/workbench/docs/infrastructure/domains/communications/COMMUNICATIONS_RUNBOOK.md` (1)
- `/Users/ronnyworks/code/workbench/docs/infrastructure/domains/home/HOME_NETWORK_AUDIT_RUNBOOK.md` (1)
- `/Users/ronnyworks/code/workbench/docs/infrastructure/domains/home/HOME_NETWORK_DEVICE_ONBOARDING.md` (1)
- `/Users/ronnyworks/code/workbench/docs/infrastructure/domains/mint/MINT_MODULES_OPERATIONS_RUNBOOK.md` (1)
- `/Users/ronnyworks/code/workbench/docs/infrastructure/domains/network/NETWORK_POLICIES.md` (1)
- `/Users/ronnyworks/code/workbench/docs/infrastructure/domains/network/NETWORK_RUNBOOK.md` (1)
- `/Users/ronnyworks/code/workbench/docs/infrastructure/domains/recovery/DR_RUNBOOK.md` (1)
- `/Users/ronnyworks/code/workbench/docs/infrastructure/domains/recovery/RTO_RPO.md` (1)
- `/Users/ronnyworks/code/workbench/docs/infrastructure/domains/shop/SHOP_NETWORK_AUDIT_RUNBOOK.md` (1)
- `/Users/ronnyworks/code/workbench/docs/infrastructure/domains/shop/SHOP_NETWORK_DEVICE_ONBOARDING.md` (1)
- `/Users/ronnyworks/code/workbench/docs/infrastructure/domains/shop/SHOP_NETWORK_NORMALIZATION.md` (1)
- `/Users/ronnyworks/code/workbench/docs/infrastructure/domains/shop/SHOP_SERVER_SSOT.md` (1)
- `/Users/ronnyworks/code/workbench/docs/infrastructure/domains/shop/SHOP_VM_ARCHITECTURE.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/AUTOMATION_STACK.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/CLEANUP_AUDIT.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/CONNECTION_MATRIX.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/GITHUB_ACTIONS.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/KEY_INVENTORY.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/KEY_MANAGEMENT_PLAN.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/LEGACY_TIES.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/MCP_ACTIVE.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/MCP_PULL_PLAN.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/PLANNED_REFERENCES.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/README.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/REF_N8N_CREDENTIALS.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/SSH_ACCESS.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/STANDARDS_DATABASE.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/STANDARDS_DOCKER_STACK.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/STANDARDS_VM_LXC.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/TAILSCALE.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/architecture/AGENTS_PLANNED.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/architecture/AGENT_ARCHITECTURE.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/architecture/PILLAR_INTEGRATION.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/architecture/UNIFIED_BRAIN.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/audits/2026-01-11-730XD-PERFORMANCE-AUDIT.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/audits/2026-01-11-PROXMOX-HOME-AUDIT.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/audits/AUDIT_2025-12-29_undeployed_infrastructure.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/audits/HOME_INFRASTRUCTURE_AUDIT.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/audits/NAS_INVENTORY.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/cloudflare/2026-01-24-cloudflare-audit-summary.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/cloudflare/CLOUDFLARE_GOVERNANCE.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/cloudflare/CLOUDFLARE_MAP.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/domains/DOMAIN_REGISTRY.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/domains/DOMAIN_STRATEGY.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/guides/AGENT_SOP.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/guides/AI_ASSISTANT_DIAGNOSIS.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/guides/AI_CAPABILITIES.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/guides/AUTOMATION_CAPABILITIES.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/guides/CONTEXT_PERSISTENCE.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/guides/MAIL_ARCHIVER.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/homelab/INFRASTRUCTURE_AUDIT.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/homelab/NEXT_VISIT_CHECKLIST.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/homelab/SECURITY_BACKLOG.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/locations/LAPTOP.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/locations/LOCATIONS_INDEX.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/mcp/DISASTER_RECOVERY.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/mcp/MCP_TROUBLESHOOTING.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/mcp/RECOVERY_RUNBOOK.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/microsoft/CONTRACT.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/microsoft/runbooks/OUTLOOK_V1_SPAM_TRIAGE.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/n8n/CONTRACT.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/n8n/QUICKSTART.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/n8n/README.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/n8n/runbooks/INFISICAL_SECRETS_SYNC.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/plans/HYPNO_DESIGNS_REORGANIZATION_FINAL.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/plans/PLAN_AGENTS_2026-01-25.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/plans/PLAN_MINTPRINTS_CO.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/plans/PLAN_UPDATES_2026-01-25.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/proxmox-gitops-evaluation.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/rag/ANYTHINGLLM_GOVERNANCE.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/rag/RAG_ISSUE_CLOSURE_CHECKLIST.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/rag/RAG_SYNC_GOVERNANCE.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/rag/REINDEX_POLICY.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/rag/WORKSPACE_PROMPT.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/secrets/SECRETS_REFERENCE.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/secrets/SECRET_ROTATION.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/shopify/SHOPIFY_SSOT.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/storage/MINIO_STANDALONE_SSOT.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/top-level/AGENT_CONTEXT_PACK.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/top-level/AUDIT_REPORT_2026-01-21.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/top-level/AUDIT_RESOLUTION_2026-01-21.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/top-level/BACKUP.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/top-level/DISCOVERY_2026-01-21.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/top-level/DRIFT_LOG.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/top-level/EMAIL_CONFIGURATION.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/top-level/INCIDENTS_LOG.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/top-level/INDEX.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/top-level/INFRASTRUCTURE_CONTEXT.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/top-level/MCP_TROUBLESHOOTING.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/top-level/MISTAKES_LOG.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/top-level/RAG_ARCHITECTURE.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/top-level/README.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/top-level/RUNBOOK_INDEX.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/top-level/STATUS.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/vaultwarden/README.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/runbooks/API_STANDARDS.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/runbooks/BACKUP_PROTOCOL.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/runbooks/COLD_START_RECOVERY.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/runbooks/CONFIGS_GOVERNANCE.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/runbooks/CRON_GOVERNANCE.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/runbooks/CRON_REGISTRY.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/runbooks/DISASTER_RECOVERY.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/runbooks/ENV_GOVERNANCE.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/runbooks/GITHUB_CLEANUP_ACTIONS.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/runbooks/GITHUB_GOVERNANCE.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/runbooks/GIT_SYNC.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/runbooks/INFISICAL_GOVERNANCE.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/runbooks/INFISICAL_RESTORE_DRILL.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/runbooks/MAC_FINDER_MOUNTS.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/runbooks/MOBILE_IDEA_CAPTURE.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/runbooks/MONITORING_GOVERNANCE.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/runbooks/N8N_GOVERNANCE.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/runbooks/RESEND_EMAIL.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/runbooks/RESEND_GOVERNANCE.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/runbooks/RUNBOOK_CLIENT_ONBOARDING.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/runbooks/RUNBOOK_CLOUDFLARE.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/runbooks/RUNBOOK_CLOUDFLARE_CLI.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/runbooks/RUNBOOK_INCIDENT.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/runbooks/RUNBOOK_N8N_CLI.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/runbooks/RUNBOOK_REPO_DOC_RULES.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/runbooks/RUNBOOK_TERMINAL_DEFINITIONS.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/runbooks/SCRIPTS_REGISTRY.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/runbooks/TAILSCALE_GOVERNANCE.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/runbooks/TEST_COVERAGE_MATRIX.md` (1)
- `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/runbooks/TWILIO_GOVERNANCE.md` (1)
- `/Users/ronnyworks/code/workbench/dotfiles/opencode/commands/check.md` (1)
- `/Users/ronnyworks/code/workbench/dotfiles/opencode/commands/ctx.md` (1)
- `/Users/ronnyworks/code/workbench/dotfiles/opencode/commands/fix.md` (1)
- `/Users/ronnyworks/code/workbench/dotfiles/opencode/commands/gaps.md` (1)
- `/Users/ronnyworks/code/workbench/dotfiles/opencode/commands/gates.md` (1)
- `/Users/ronnyworks/code/workbench/dotfiles/opencode/commands/howto.md` (1)
- `/Users/ronnyworks/code/workbench/dotfiles/opencode/commands/loop.md` (2)
- `/Users/ronnyworks/code/workbench/dotfiles/opencode/commands/propose.md` (1)
- `/Users/ronnyworks/code/workbench/dotfiles/opencode/commands/triage.md` (1)
- `/Users/ronnyworks/code/workbench/dotfiles/opencode/commands/verify.md` (1)
- `/Users/ronnyworks/code/workbench/infra/data/CONTAINER_INVENTORY.yaml` (14)
- `/Users/ronnyworks/code/workbench/infra/data/MCP_INVENTORY.yaml` (1)
- `/Users/ronnyworks/code/workbench/infra/data/rag/workspace_prompt.md` (1)

</details>

### Recommended canonical policy by file class

- `binding` (contract/registry YAML): keep `updated_at` as canonical freshness field; retain `updated` only where schema/gate already requires it.
- `doc` (Markdown/text): use `last_verified` as canonical field.
- `generated`: preserve generator output format; do not normalize by hand.
- `other` (scripts/tests/data): no broad normalization in W21; only touch when behavior work requires it.

## Phase A.4 MCP Registry Inventory

| Source | Type | Server key | Servers |
|---|---|---|---|
| `/Users/ronnyworks/code/agentic-spine/.mcp.json` | runtime config | `mcpServers` | `finance-agent,mint-pricing mint-suppliers,spine` |
| `/Users/ronnyworks/code/workbench/.mcp.json` | runtime config | `mcpServers` | `finance-agent,media-agent` |
| `/Users/ronnyworks/code/workbench/dotfiles/opencode/opencode.json` | runtime config | `mcp` | `playwright,spine` |
| `/Users/ronnyworks/code/agentic-spine/ops/bindings/mcp.runtime.contract.yaml` | contract authority | `required_servers_by_surface` | `codex: spine`, `claude_desktop: spine, immich-photos, communications-agent`, `opencode: spine` |

### Proposed SSOT and migration map (no execution in W20)

- Proposed SSOT: `/Users/ronnyworks/code/agentic-spine/ops/bindings/mcp.runtime.contract.yaml`
- Canonical read order (for deterministic preflight and operator review):
  1. `/Users/ronnyworks/code/agentic-spine/ops/bindings/mcp.runtime.contract.yaml` (contract authority)
  2. `/Users/ronnyworks/code/agentic-spine/.mcp.json` (Codex runtime surface)
  3. `/Users/ronnyworks/code/workbench/.mcp.json` (Claude Desktop runtime surface)
  4. `/Users/ronnyworks/code/workbench/dotfiles/opencode/opencode.json` (OpenCode runtime surface)
- Phase 1 (W21 docs-only): publish explicit precedence order (contract first, runtime configs second) in governance docs.
- Phase 2 (later wave): add contract-vs-runtime diff report command, no auto-mutation.
- Phase 3 (later wave): evaluate removing redundant config-local declarations only after parity gate update.

## Confirmed Safe Targets for W21

- Class-B frontmatter candidates in `ops/bindings` only (bounded batch size, pre-verified by inventory).
- Docs/examples path normalization (`/Users/ronnyworks/code` -> `~/code`) in non-generated docs and examples only.
- Temporal field normalization on touched docs (`last_verified`) and bounded binding candidates (`updated_at`) where schema allows.
- MCP inventory/documentation alignment only (no runtime config edits).

## Blocked Targets (Do Not Execute in W21)

- Mass frontmatter rewrite across `ops/bindings/*` (high regression risk).
- Any symlink mutation in `/Users/ronnyworks/code/workbench/bin/*`.
- Any edit to `/Users/ronnyworks/code/workbench/.spine-link.yaml`.
- Any repo_path normalization in `/Users/ronnyworks/code/agentic-spine/ops/bindings/agents.registry.yaml`.
- Any normalization on generated surfaces unless generator/source is updated first.

## Sequence of Operations for W21 (smallest-risk first)

1. Apply docs/examples path normalization in approved non-generated files.
2. Re-run verify packs; stop on any D60/D72/D77/D79/D85/D125/D153 regressions.
3. Apply bounded Class-B frontmatter batch (<=10 files) with immediate verify.
4. Apply temporal-field normalization only on files touched in steps 1-3.
5. Publish MCP precedence doc adjustments only.

## Rollback Plan

- Use one commit per micro-batch (docs paths, frontmatter batch, temporal metadata, MCP docs).
- If any verify regression appears, revert only the failing batch commit.
- Keep W21 changes strictly non-runtime and non-generator unless separately approved.

## Expected Gate Impact

- `D153`: must remain stable by preserving absolute repo path contracts.
- `D125` / `D148`: unaffected in W20; W21 must remain docs-only for MCP.
- `D85`: avoid metadata or script-header regressions while editing docs.
- `D60`: avoid introducing deprecated terminology in strategy and follow-up docs.

## Explicitly Excluded Surfaces

- `/Users/ronnyworks/code/workbench/.spine-link.yaml`
- `/Users/ronnyworks/code/workbench/bin/ops`
- `/Users/ronnyworks/code/workbench/bin/verify`
- `/Users/ronnyworks/code/workbench/bin/mint`
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/agents.registry.yaml` (`project_binding.repo_path`)
- Generator-managed outputs unless source/generator is part of an approved wave

# Agentic Spine — Docs Index

> **Purpose:** Single landing page for every agent. Points to canonical contracts,
> governance SSOTs, extraction guides, and the gap map. Start here, reach any
> doc in two hops, never leave `/Code`.
>
> **Status:** authoritative
> **Last verified:** 2026-02-05

---

## Core Contracts

The invariants. If a drift gate fails, one of these was violated.

| Doc | What It Governs |
|-----|----------------|
| [AGENT_CONTRACT.md](core/AGENT_CONTRACT.md) | Allowable agent behavior — the rules every agent follows |
| [AGENT_OUTPUT_CONTRACT.md](core/AGENT_OUTPUT_CONTRACT.md) | Required output block structure |
| [RECEIPTS_CONTRACT.md](core/RECEIPTS_CONTRACT.md) | Receipt format, proof rules, ledger entries |
| [CORE_LOCK.md](core/CORE_LOCK.md) | Spine health invariants + drift gate definitions (D1–D24) |
| [SPINE.md](core/SPINE.md) | Spine architecture and design principles |
| [SPINE_SESSION_HEADER.md](core/SPINE_SESSION_HEADER.md) | Session header format for agent context |
| [SPINE_STATE.md](core/SPINE_STATE.md) | Canonical spine state — what lives here, no legacy deps |
| [SESSION_PROTOCOL.md](governance/SESSION_PROTOCOL.md) | Spine-native session protocol (entry point) |

---

## Bindings (Non-Secret Configuration)

| Doc | What It Binds |
|-----|--------------|
| [SECRETS_BINDING.md](core/SECRETS_BINDING.md) | Infisical provider binding (no secrets, just structure) |
| [CLOUD_FLARE_BINDING.md](core/CLOUD_FLARE_BINDING.md) | Cloudflare zone/tunnel binding |
| [INFISICAL_PROJECTS.md](core/INFISICAL_PROJECTS.md) | Infisical project inventory (names + counts) |
| [DEVICE_IDENTITY_SSOT.md](governance/DEVICE_IDENTITY_SSOT.md) | Device/VM identity (hostnames, Tailscale IPs) |
| [SHOP_SERVER_SSOT.md](governance/SHOP_SERVER_SSOT.md) | Shop rack infrastructure (R730XD, VMs, storage, cameras) |
| [MACBOOK_SSOT.md](governance/MACBOOK_SSOT.md) | Workstation infrastructure (RAG stack, dev tooling) |
| [MINILAB_SSOT.md](governance/MINILAB_SSOT.md) | Home minilab (Beelink, NAS, home VMs/LXCs) |

---

## Governance / SSOTs

The authority chain. When in doubt, these are the source of truth.

| Doc | Scope |
|-----|-------|
| [GOVERNANCE_INDEX.md](governance/GOVERNANCE_INDEX.md) | Entry point — rules, authority chain, general governance |
| [SESSION_PROTOCOL.md](governance/SESSION_PROTOCOL.md) | Entry point for every agent inside the spine |
| [STACK_REGISTRY.yaml](governance/STACK_REGISTRY.yaml) | What stacks exist, where they run |
| [SERVICE_REGISTRY.yaml](governance/SERVICE_REGISTRY.yaml) | Service-level inventory (ports, health URLs) |
| [SSOT_REGISTRY.yaml](governance/SSOT_REGISTRY.yaml) | Priority list of truth sources agents follow |
| [REPO_STRUCTURE_AUTHORITY.md](governance/REPO_STRUCTURE_AUTHORITY.md) | Where files and directories belong |
| [COMPOSE_AUTHORITY.md](governance/COMPOSE_AUTHORITY.md) | Where compose stacks belong + authority rules |
| [SCRIPTS_AUTHORITY.md](governance/SCRIPTS_AUTHORITY.md) | What scripts exist and are safe to run |
| [INFRASTRUCTURE_MAP.md](governance/INFRASTRUCTURE_MAP.md) | Historical infrastructure schema capture (workbench-owned) |
| [WORKBENCH_TOOLING_INDEX.md](governance/WORKBENCH_TOOLING_INDEX.md) | Centralized workbench entry points (read-only reference) |
| [CORE_AGENTIC_SCOPE.md](governance/CORE_AGENTIC_SCOPE.md) | What's in-scope for the spine vs external |
| [DOMAIN_ROUTING_REGISTRY.yaml](governance/DOMAIN_ROUTING_REGISTRY.yaml) | Domain routing rules |
| [AGENT_BOUNDARIES.md](governance/AGENT_BOUNDARIES.md) | Agent boundary constraints |
| [AGENTS_GOVERNANCE.md](governance/AGENTS_GOVERNANCE.md) | Agent lifecycle and verification contract |
| [AGENTS_LOCATION.md](governance/AGENTS_LOCATION.md) | Where agent scripts live |
| [AUDIT_VERIFICATION.md](governance/AUDIT_VERIFICATION.md) | Legacy import verification audit |
| [CANONICAL.md](governance/CANONICAL.md) | Canonical doc definitions |
| [EXCLUDED_SURFACES.md](governance/EXCLUDED_SURFACES.md) | Explicitly excluded from spine scope |
| [ISSUE_CLOSURE_SOP.md](governance/ISSUE_CLOSURE_SOP.md) | When and how to close GitHub issues |
| [LEGACY_DEPRECATION.md](governance/LEGACY_DEPRECATION.md) | Rules for legacy/external repository references |
| [MAILROOM_RUNBOOK.md](governance/MAILROOM_RUNBOOK.md) | Mailroom queue operations, ledger, logs, health checks |
| [RAG_INDEXING_RULES.md](governance/RAG_INDEXING_RULES.md) | What gets indexed to RAG knowledge base |
| [SEARCH_EXCLUSIONS.md](governance/SEARCH_EXCLUSIONS.md) | What directories/files are excluded from search |
| [SECRETS_POLICY.md](governance/SECRETS_POLICY.md) | Governance-grade secrets management rules |
| [SSOT_UPDATE_TEMPLATE.md](governance/SSOT_UPDATE_TEMPLATE.md) | Receipt-driven SSOT update workflow |
| [BACKUP_GOVERNANCE.md](governance/BACKUP_GOVERNANCE.md) | Backup strategy, verification, freshness rules |
| [REBOOT_HEALTH_GATE.md](governance/REBOOT_HEALTH_GATE.md) | Safe reboot procedures and health gates |
| [INFRASTRUCTURE_AUTHORITY.md](governance/INFRASTRUCTURE_AUTHORITY.md) | Infrastructure authority rules |
| [INGRESS_AUTHORITY.md](governance/INGRESS_AUTHORITY.md) | Ingress/routing authority |
| [OPS_PATCH_HISTORY.md](governance/OPS_PATCH_HISTORY.md) | Critical ops path hardening log |
| [SCRIPTS_REGISTRY.md](governance/SCRIPTS_REGISTRY.md) | Script inventory and locations |
| [SPINE_INDEX.md](governance/SPINE_INDEX.md) | Spine documentation index |
| [STACK_AUTHORITY.md](governance/STACK_AUTHORITY.md) | Stack authority rules |

---

## Audits

Gap scans, runtime audits, and triage reports.

| Doc | What It Covers |
|-----|---------------|
| [AGENT_DISPATCH_PIPELINE_GAP_SCAN.md](governance/_audits/AGENT_DISPATCH_PIPELINE_GAP_SCAN.md) | Agent dispatch pipeline gap analysis |
| [AGENT_RUNTIME_AUDIT.md](governance/_audits/AGENT_RUNTIME_AUDIT.md) | Agent runtime behavior audit |
| [AUTHORITY_CLAIMS_TRIAGE.md](governance/_audits/AUTHORITY_CLAIMS_TRIAGE.md) | Authority claims triage and resolution |
| [RAG_INTEGRATION_RATIONALE.md](governance/_audits/RAG_INTEGRATION_RATIONALE.md) | RAG integration design rationale |
| [STATE_OF_THE_UNION_SUMMARY.md](governance/_audits/STATE_OF_THE_UNION_SUMMARY.md) | Overall spine state summary |

---

## Verify Surface

| Doc | What It Covers |
|-----|---------------|
| [VERIFY_SURFACE_INDEX.md](governance/VERIFY_SURFACE_INDEX.md) | Catalog of all 31 scripts in `surfaces/verify/` |

---

## Capabilities & Agents

| Doc | What It Covers |
|-----|---------------|
| [CAPABILITIES_OVERVIEW.md](core/CAPABILITIES_OVERVIEW.md) | What capabilities replace legacy scripts |
| [GOVERNANCE_MINIMUM.md](core/GOVERNANCE_MINIMUM.md) | Minimum governance every capability must satisfy |
| [CANONICAL_DOCS.md](core/CANONICAL_DOCS.md) | Which docs are canonical vs derived |
| [PLAN_SCHEMA.md](core/PLAN_SCHEMA.md) | Plan file format for structured work |

---

## Extraction & Alignment

How assets move from the workbench monolith into the spine.

| Doc | What It Tracks |
|-----|---------------|
| [AGENTIC_GAP_MAP.md](core/AGENTIC_GAP_MAP.md) | What has moved, what remains — 23 asset groups at 100% coverage |
| [EXTRACTION_PROTOCOL.md](core/EXTRACTION_PROTOCOL.md) | Step-by-step extraction procedure + drift gate expectations |
| [STACK_ALIGNMENT.md](core/STACK_ALIGNMENT.md) | Stack docs mapped to spine references + workbench infrastructure index |

---

## Operational Helpers

| Doc | Purpose |
|-----|---------|
| [OPERATOR_CHEAT_SHEET.md](OPERATOR_CHEAT_SHEET.md) | Quick commands and governance rituals |
| [brain/README.md](brain/README.md) | Agent memory, context injection, hotkey reference |
| [core/REPLAY_FIXTURES.md](core/REPLAY_FIXTURES.md) | Replay fixtures guide for deterministic tests |

---

## Subdirectory Map

| Directory | Contents |
|-----------|----------|
| `docs/core/` | Spine invariants — contracts, locks, bindings, gap map |
| `docs/governance/` | SSOTs, authority pages, audits, canonical indexes |
| `docs/brain/` | Agent memory system + imported context |
| `docs/legacy/` | Archived legacy imports (quarantined by D16/D17, reference only) |

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for rules on folder placement, metadata
headers, and README registration. New docs must live in a named folder and
appear in this index.

---

## Proof of Health

After editing any doc in this tree:

```bash
# Lint: folder placement, metadata headers, README registration, legacy isolation
./bin/ops cap run docs.lint

# Verify drift gates still pass (D1–D24)
./bin/ops cap run spine.verify

# Verify workbench infrastructure docs intact (120 files, 19 dirs)
./bin/ops cap run docs.status

# Verify extraction coverage (23 asset groups)
./bin/ops cap run infra.extraction.status
```

Each command produces a receipt under `receipts/sessions/` so agents can prove
the doc snapshot they operated against.

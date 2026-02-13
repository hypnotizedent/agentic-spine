---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-13
scope: governance-documentation-index
---

# Active Docs Index

Authoritative governance documentation organized by category. All docs in `docs/governance/`.

> **NOT AUTHORITATIVE:** Docs in `_audits/` and `_imported/` are historical reference only.
> Extraction matrices (FINANCE/HASS/IMMICH_LEGACY_EXTRACTION_MATRIX.md) are evidence
> documents for completed extractions, not operational sources of truth.

---

## 1. Core Governance (Session & Authority)

| Document | SSOT Priority | Purpose |
|----------|--------------|---------|
| SESSION_PROTOCOL.md | P1 | Agent session entry point and startup checklist |
| SSOT_REGISTRY.yaml | P1 | Machine-readable registry of all SSOTs |
| REPO_STRUCTURE_AUTHORITY.md | P1 | File/folder placement rules |
| GOVERNANCE_INDEX.md | P4 | Human-readable governance guide |
| AGENT_GOVERNANCE_BRIEF.md | -- | Agent discipline and work policy |
| AGENTS_GOVERNANCE.md | -- | Agent execution and session lifecycle rules |
| AGENT_BOUNDARIES.md | P2 | Agent capability constraints |
| CORE_AGENTIC_SCOPE.md | -- | Scope boundaries for agentic operations |
| CANONICAL.md | -- | Canonical form rules |

## 2. Infrastructure SSOTs

| Document | SSOT Priority | Scope |
|----------|--------------|-------|
| SHOP_SERVER_SSOT.md | P1 | R730XD, VMs 200-210, ZFS, network |
| MINILAB_SSOT.md | P1 | Home site: Beelink, NAS, VMs 100-105 |
| MACBOOK_SSOT.md | P1 | Workstation hardware and tooling |
| CAMERA_SSOT.md | P1 | NVR, camera channels, RTSP |
| DEVICE_IDENTITY_SSOT.md | P1 | Naming, Tailscale IPs, tier classification |
| INFRASTRUCTURE_AUTHORITY.md | -- | Infrastructure claim ownership |
| INFRASTRUCTURE_MAP.md | -- | High-level topology reference |
| SHOP_VM_ARCHITECTURE.md | P4 | VM role overview |
| SHOP_NETWORK_NORMALIZATION.md | P3 | Target IP structure (192.168.1.0/24) |

## 3. Operational Runbooks

| Document | SSOT Priority | Purpose |
|----------|--------------|---------|
| DR_RUNBOOK.md | P2 | Disaster recovery procedures and priority order |
| BACKUP_GOVERNANCE.md | P2 | Vzdump strategy, retention rules |
| HOME_BACKUP_STRATEGY.md | -- | Home site backup tiers |
| AUTHENTIK_BACKUP_RESTORE.md | -- | Authentik backup/restore procedure |
| GITEA_BACKUP_RESTORE.md | -- | Gitea backup/restore procedure |
| INFISICAL_BACKUP_RESTORE.md | -- | Infisical backup/restore + break-glass |
| VAULTWARDEN_BACKUP_RESTORE.md | -- | Vaultwarden backup/restore procedure |
| BACKUP_CALENDAR.md | -- | Backup schedule calendar |
| RTO_RPO.md | -- | Recovery time/point objectives |
| REBOOT_HEALTH_GATE.md | P2 | Pre/post-reboot validation |
| MAILROOM_RUNBOOK.md | P2 | Mailroom queue operations |
| MAILROOM_BRIDGE.md | -- | Remote API bridge |
| TERMINAL_C_DAILY_RUNBOOK.md | -- | Control-plane orchestration runbook for parallel lane execution |
| HASS_OPERATIONAL_RUNBOOK.md | -- | Home Assistant operations |
| PHASE4_OBSERVABILITY_RUNBOOK.md | -- | Observability stack procedures |
| NETWORK_RUNBOOK.md | -- | Network troubleshooting |
| SHOP_NETWORK_DEVICE_ONBOARDING.md | P2 | Device onboarding workflow |
| SHOP_NETWORK_AUDIT_RUNBOOK.md | P2 | Shop network audit workflow |
| INFRA_RELOCATION_PROTOCOL.md | P2 | Service relocation procedures |
| INFISICAL_RESTORE_DRILL.md | -- | Quarterly Infisical restore drill validation procedure |
| SSOT_UPDATE_TEMPLATE.md | P3 | Receipt-driven SSOT update workflow |
| ISSUE_CLOSURE_SOP.md | P3 | Issue closure checklist |

## 4. Security & Secrets

| Document | SSOT Priority | Purpose |
|----------|--------------|---------|
| SECRETS_POLICY.md | P2 | Infisical binding, pre-commit enforcement |
| SECURITY_POLICIES.md | -- | SSH, firewall, NFS, Tailscale audit |
| NETWORK_POLICIES.md | P2 | Subnet allocation, DNS/DHCP, NFS mount policy |
| HOST_DRIFT_POLICY.md | -- | Host-level drift detection |
| PORTABILITY_ASSUMPTIONS.md | P2 | Required tooling and platform prerequisites |

## 5. Development & CI/CD

| Document | SSOT Priority | Purpose |
|----------|--------------|---------|
| GIT_REMOTE_AUTHORITY.md | -- | Gitea primary + GitHub mirror |
| COMPOSE_AUTHORITY.md | -- | Canonical compose file per stack |
| STACK_AUTHORITY.md | -- | Stack placement rules |
| SCRIPTS_AUTHORITY.md | P2 | Script placement and naming |
| SCRIPTS_REGISTRY.md | P4 | Canonical scripts index |
| CHANGE_PACK_TEMPLATE.md | -- | Commit change pack structure |
| PATCH_CADENCE.md | -- | OS/container update schedules |
| OPS_PATCH_HISTORY.md | -- | Historical patch log |
| RELEASE_PROTOCOL.md | -- | Release promotion workflow |

## 6. Agent & Routing

| Document | SSOT Priority | Purpose |
|----------|--------------|---------|
| AGENTS_LOCATION.md | -- | Agent source code locations |
| WORKBENCH_TOOLING_INDEX.md | -- | Approved external workbench entry points |
| INGRESS_AUTHORITY.md | P2 | DNS vs tunnel vs stacks boundary |
| CLAUDE_ENTRYPOINT_SHIM.md | -- | Agent entry point redirect |
| OPENCODE_GOVERNED_ENTRY.md | -- | Governed OpenCode entry/model/provider contract |
| WORKER_LANE_TEMPLATE_PACK.md | -- | Canonical worker-lane prompt and handoff templates |
| EXCLUDED_SURFACES.md | -- | Explicitly excluded surfaces |

## 7. Search & RAG

| Document | SSOT Priority | Purpose |
|----------|--------------|---------|
| RAG_INDEXING_RULES.md | P3 | What gets indexed, quality gates |
| SEARCH_EXCLUSIONS.md | P3 | Excluded directories and patterns |

## 8. Governance Metadata

| Document | Purpose |
|----------|---------|
| VERIFY_SURFACE_INDEX.md | Verification surface index |
| SPINE_INDEX.md | Spine documentation index |
| AUDIT_VERIFICATION.md | Audit evidence linking |
| LEGACY_DEPRECATION.md | Legacy reference migration rules |
| MAKER_TOOLS_GOVERNANCE.md | Maker tool governance |

## 9. Pillars & Planning

| Directory | Purpose |
|-----------|---------|
| `docs/pillars/` | Domain pillar documentation (finance, etc.) |
| `docs/planning/` | Planning and roadmap surfaces |

## 10. Historical / Evidence Only (NOT Authoritative)

| Document | Context |
|----------|---------|
| FINANCE_LEGACY_EXTRACTION_MATRIX.md | Completed extraction evidence |
| HASS_LEGACY_EXTRACTION_MATRIX.md | Completed extraction evidence |
| IMMICH_LEGACY_EXTRACTION_MATRIX.md | Completed extraction evidence |
| `_audits/*.md` (11 files) | Historical audit snapshots |
| `_imported/` subdirectories | Quarantined legacy captures |

---

## Priority Legend

| Level | Meaning |
|-------|---------|
| P1 | Foundational SSOT -- defines infrastructure reality |
| P2 | Domain-specific authority |
| P3 | Operational -- procedures and quality gates |
| P4 | Index/reference -- pointers to SSOTs |
| -- | Authoritative but not registered as domain-level SSOT |

---

_70 governance docs + 11 audit docs indexed. Last updated: 2026-02-13._

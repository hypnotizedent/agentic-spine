---
status: reference
owner: "@ronny"
last_verified: 2026-02-05
scope: migration-planning
---

# Workbench Infrastructure Migration Queue

> **Purpose:** Catalog of 123 workbench docs with migration priorities.
> **Policy:** See [LEGACY_DEPRECATION.md](../governance/LEGACY_DEPRECATION.md) for migration protocol.

---

## Summary

| Category | Count | Treatment |
|----------|-------|-----------|
| **Authoritative** | 5 | Evaluate for spine migration |
| **Reference** | 102 | Leave in workbench with disclaimers |
| **Legacy-Reference** | 16 | Historical only, no action needed |

---

## P1: Evaluate for Spine Migration (5 docs)

These are marked `status: authoritative` in workbench. Evaluate whether they define
spine invariants or are workbench-scoped.

| Doc | Current Purpose | Spine Relevance |
|-----|-----------------|-----------------|
| `SERVICE_REGISTRY.md` | What services run where | **HIGH** — spine has `STACK_REGISTRY.yaml` partial coverage |
| `CONTAINER_INVENTORY.md` | Observed container state | **MEDIUM** — runtime state, not invariant |
| `MCP_AUTHORITY.md` | MCP server registry | **HIGH** — spine has `mcp.inventory.status` capability |
| `AUTHORITY_INDEX.md` | SSOT index | **LOW** — spine has `SSOT_REGISTRY.yaml` |
| `SSOT.md` | SSOT pointer doc | **LOW** — spine has `GOVERNANCE_INDEX.md` |

### Recommendation

| Doc | Action |
|-----|--------|
| `SERVICE_REGISTRY.md` | Keep in workbench; spine references via `ops/bindings/services.health.yaml` |
| `CONTAINER_INVENTORY.md` | Keep in workbench; runtime state, not governance |
| `MCP_AUTHORITY.md` | Keep in workbench; spine has capability that verifies against it |
| `AUTHORITY_INDEX.md` | Keep in workbench; superseded by spine `GOVERNANCE_INDEX.md` |
| `SSOT.md` | Keep in workbench; superseded by spine `SSOT_REGISTRY.yaml` |

**Verdict:** No migration needed. Spine already has equivalent governance. Workbench
docs serve as the external SSOT for service/container details.

---

## P2: Runbooks (30 docs)

Operational procedures. Most are workbench-scoped (n8n, Cloudflare CLI, etc.).

| Runbook | Spine Relevance |
|---------|-----------------|
| `BACKUP_PROTOCOL.md` | LOW — spine has `BACKUP_GOVERNANCE.md` |
| `DISASTER_RECOVERY.md` | LOW — workbench-scoped recovery |
| `INFISICAL_GOVERNANCE.md` | MEDIUM — spine has `SECRETS_POLICY.md` |
| `GITHUB_GOVERNANCE.md` | LOW — workbench repo rules |
| `N8N_GOVERNANCE.md` | NONE — n8n is workbench stack |
| `CLOUDFLARE_CLI.md` | NONE — tooling reference |
| `TAILSCALE_GOVERNANCE.md` | LOW — spine has device identity |
| ... (23 more) | Reference only |

**Verdict:** Leave all in workbench. Spine has its own governance docs for overlapping areas.

---

## P3: Reference Docs (102 docs by subdirectory)

### reference/top-level (16)
Index docs, context packs, status summaries. Superseded by spine docs.

| Doc | Status |
|-----|--------|
| `INDEX.md` | Superseded by spine `docs/README.md` |
| `AGENT_CONTEXT_PACK.md` | Superseded by spine `CORE_LOCK.md` |
| `INFRASTRUCTURE_CONTEXT.md` | Reference only |
| `INCIDENTS_LOG.md` | Keep in workbench (operational history) |
| `MISTAKES_LOG.md` | Keep in workbench (learnings) |
| ... | Reference only |

### reference/audits (7)
Historical snapshots. Already marked `legacy-reference`.

### reference/architecture (4)
Agent architecture docs. Superseded by spine `AGENTS_GOVERNANCE.md`.

### reference/cloudflare (3)
Cloudflare governance. Spine has `INGRESS_AUTHORITY.md` for routing.

### reference/guides (6)
How-to guides. Keep in workbench as tooling reference.

### reference/rag (5)
RAG configuration. Workbench-scoped (AnythingLLM, workspace prompts).

### reference/locations (4)
Physical location docs (HOME, LAPTOP, SHOP). Workbench reference only.

### Other subdirectories
All reference-only. No spine migration needed.

---

## P4: Legacy-Reference (16 docs)

Historical audits and plans. No action needed.

```
2026-01-01-holistic-infrastructure-audit.md
2026-01-01-infrastructure-audit-findings.md
2026-01-11-730XD-PERFORMANCE-AUDIT.md
2026-01-11-PROXMOX-HOME-AUDIT.md
2026-01-24-cloudflare-audit-summary.md
AUDIT_2025-12-29_undeployed_infrastructure.md
AUDIT_REPORT_2026-01-21.md
AUDIT_RESOLUTION_2026-01-21.md
DISCOVERY_2026-01-21.md
DRIFT_LOG.md
HOME_INFRASTRUCTURE_AUDIT.md
HYPNO_DESIGNS_REORGANIZATION_FINAL.md
NAS_INVENTORY.md
PLAN_AGENTS_2026-01-25.md
PLAN_MINTPRINTS_CO.md
PLAN_UPDATES_2026-01-25.md
```

---

## Migration Decisions

### Already in Spine (No Migration Needed)

| Workbench Doc | Spine Equivalent |
|---------------|------------------|
| `AUTHORITY_INDEX.md` | `GOVERNANCE_INDEX.md` |
| `SSOT.md` | `SSOT_REGISTRY.yaml` |
| `AGENT_CONTEXT_PACK.md` | `CORE_LOCK.md` + `CAPABILITIES_OVERVIEW.md` |
| `BACKUP_PROTOCOL.md` | `BACKUP_GOVERNANCE.md` |
| `INFISICAL_GOVERNANCE.md` | `SECRETS_POLICY.md` |

### Keep in Workbench (External SSOT)

| Workbench Doc | Reason |
|---------------|--------|
| `SERVICE_REGISTRY.md` | Workbench owns service topology |
| `CONTAINER_INVENTORY.md` | Runtime state observation |
| `MCP_AUTHORITY.md` | MCP server registry (spine verifies against it) |
| All runbooks | Workbench operational procedures |
| All location docs | Physical infrastructure |

### No Action (Historical)

All 16 `legacy-reference` docs — point-in-time snapshots.

---

## Conclusion

**Migration queue: 0 docs**

The workbench infrastructure tree is properly structured:
- 5 authoritative docs are workbench-scoped (services, containers, MCP)
- 102 reference docs are operational helpers
- 16 legacy-reference docs are historical snapshots

The spine already has equivalent governance for all invariant-defining areas:
- Session entry: `SESSION_PROTOCOL.md`
- SSOT registry: `SSOT_REGISTRY.yaml`
- Agent governance: `AGENTS_GOVERNANCE.md`
- Mailroom: `MAILROOM_RUNBOOK.md`
- Secrets: `SECRETS_POLICY.md`
- Backup: `BACKUP_GOVERNANCE.md`

**Recommended action:** No migration. Keep workbench as external SSOT for
service/container details. Spine references workbench via `ops/bindings/*.yaml`
and capability verification.

---

## Related Documents

| Document | Relationship |
|----------|--------------|
| [LEGACY_DEPRECATION.md](../governance/LEGACY_DEPRECATION.md) | Migration protocol |
| [GOVERNANCE_INDEX.md](../governance/GOVERNANCE_INDEX.md) | Spine entry chain |
| [AGENTIC_GAP_MAP.md](../core/AGENTIC_GAP_MAP.md) | Extraction tracking |

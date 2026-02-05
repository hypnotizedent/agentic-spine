---
status: reference
owner: "@ronny"
last_verified: 2026-02-05
scope: external-tooling
---

# Workbench Tooling Index

> **Tooling Only — Read-Only**
>
> This is the only approved place to reference workbench tooling from the spine.
> Workbench documentation is quarantined and not authoritative.
>
> **Query first (when RAG is enabled):** `cd ~/Code/workbench && ./scripts/root/mint ask "question"`

---

## Allowed External Paths (Only)

| Path | Purpose | Notes |
|------|---------|-------|
| `~/Code/workbench/infra/compose/` | Compose stacks and runtime configs | tooling only |
| `~/Code/workbench/infra/cloudflare/` | Cloudflare exports and tunnel configs | tooling only |
| `~/Code/workbench/infra/data/` | Machine-readable inventories | read-only snapshots |
| `~/Code/workbench/infra/templates/` | Templates and scaffolds | read-only |

---

## Rules

- Do not link to workbench docs from spine docs.
- Do not treat workbench content as spine authority.
- External references must flow through this index or be removed.
- To promote a workbench doc, follow [LEGACY_DEPRECATION.md](LEGACY_DEPRECATION.md).

---

## Deferred Tooling (Not Active)

| Path | Purpose | Notes |
|------|---------|-------|
| `~/Code/workbench/scripts/root/mint` | RAG CLI (`mint ask`, `mint index`) | RAG paused; future home TBD |

---

## Related Documents

| Document | Relationship |
|----------|--------------|
| [GOVERNANCE_INDEX.md](GOVERNANCE_INDEX.md) | Links here from external reference policy |
| [LEGACY_DEPRECATION.md](LEGACY_DEPRECATION.md) | Migration rules for external content |
| [SSOT_REGISTRY.yaml](SSOT_REGISTRY.yaml) | Spine-native authority registry |

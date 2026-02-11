---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-11
scope: mint-product-governance
---

# Mint Product Governance

> Canonical governance framework for mint-os module extraction and operation.
> Consumed by: all agents working on mint-modules.
> Authority: agentic-spine (this file). Code authority: mint-modules repo.

## 1. Authority Model

| Domain | Authority | Location |
|--------|-----------|----------|
| Runtime governance | agentic-spine | `docs/governance/` |
| Tooling & compose | workbench | `infra/compose/mint-os/` |
| Module source code | mint-modules | `~/code/mint-modules/<module>/` |
| Legacy reference | ronny-ops | `~/ronny-ops/` (READ-ONLY) |

**Rules:**
- Spine governs where modules run, how they're monitored, and who owns them.
- Workbench owns compose files and deploy scripts.
- mint-modules owns source code, tests, and API contracts.
- ronny-ops is dead reference. Never copy files from it. Extract knowledge only.

## 2. Module Ownership

Each module must declare ownership in its SERVICE_REGISTRY entry:

| Module | Owner | Services | Deploy Target | Secrets Namespace |
|--------|-------|----------|---------------|-------------------|
| artwork | @ronny | files-api | docker-host:~/artwork-module/ | /spine/services/artwork/ |
| quote-page | @ronny | quote-page | docker-host:~/quote-page/ | /spine/services/quote-page/ |
| order-intake | @ronny | TBD | TBD | /spine/services/order-intake/ |

**Deploy permission:** Only the module owner may deploy to production.
Agents may propose changes but must use the mailroom proposal flow.

## 3. API Contract Rules

Each module with an HTTP API must maintain an `API.md` file in its module root:

```
<module>/API.md
  - Base URL and port
  - All endpoints with method, path, request/response schema
  - Version prefix (e.g., /api/v1/)
  - Authentication requirements
  - Error response format
```

**Versioning policy:**
- All APIs use `/api/v<N>/` prefix.
- Major version bumps require: new prefix + 30-day deprecation window for old version.
- Breaking changes (field removal, type change, endpoint removal) require major bump.
- Additive changes (new endpoints, new optional fields) are minor bumps (no prefix change).

## 4. Data Ownership Boundaries

| Table | Owner Module | Read Access | Write Access |
|-------|-------------|-------------|--------------|
| job_files | artwork | artwork, quote-page, MCP | artwork only |
| orders | mint-os-api (legacy) | all modules | mint-os-api only |
| line_items | mint-os-api (legacy) | all modules | mint-os-api only |
| imprints | mint-os-api (legacy) | all modules | mint-os-api only |
| customer_artwork | artwork | artwork | artwork only |
| line_item_mockups | mint-os-api (legacy) | all modules | mint-os-api only |
| imprint_mockups | mint-os-api (legacy) | all modules | mint-os-api only |
| production_files | mint-os-api (legacy) | all modules | mint-os-api only |

**Rules:**
- A module may only write to tables it owns.
- Cross-module reads are allowed via explicit API contracts (preferred) or direct DB reads (acceptable for now).
- Schema changes require the owning module's approval.
- Legacy tables remain under mint-os-api until explicitly transferred.

## 5. Secrets Namespace

All module secrets must follow the spine secrets namespace policy:

```
/spine/services/artwork/
  MINIO_ACCESS_KEY
  MINIO_SECRET_KEY
  DATABASE_URL
  API_KEY
  PRESIGNED_UPLOAD_EXPIRY
  PRESIGNED_DOWNLOAD_EXPIRY

/spine/services/quote-page/
  MINIO_ACCESS_KEY
  MINIO_SECRET_KEY
  FILES_API_URL
```

**Rules:**
- No module may use the `mint-os-api` Infisical project for new keys.
- Shared secrets (MinIO credentials) are duplicated per namespace (not shared references).
- D43 secrets namespace lock enforces structure.

## 6. Release Gates

Before any module deployment to production:

1. `npm run typecheck` passes
2. `npm run build` succeeds
3. `npm run test` passes (if tests exist)
4. `docker compose build` succeeds
5. Health endpoint returns 200
6. SERVICE_REGISTRY entry exists with correct port
7. STACK_REGISTRY entry exists with deploy_method
8. Backup target exists in backup.inventory.yaml (if stateful)
9. Health probe exists in services.health.yaml

## 7. Legacy Extraction Rules

**Build-forward, not copy-forward.**

- Read legacy code to understand patterns, data models, and business logic.
- Write new code in mint-modules using modern TypeScript + Express patterns.
- Reference SCHEMA_TRUTH.md for all database column mappings.
- V2 API is the canonical endpoint set; ignore V1 and legacy endpoints.
- Use Infisical for secrets, not .env files.
- Document all architecture decisions in module-level SPEC.md or decision records.

**Explicitly rejected from legacy:**
- Archived directories (`_archived/`, `.archive/`)
- Lock files (pnpm-lock.yaml)
- One-off migration scripts
- Vault configurations (use Infisical)
- Diagnostic/audit reports (superseded)

## 8. Governance Gaps

| Gap | Description | Status |
|-----|-------------|--------|
| GAP-OP-105 | Mint-os secrets namespace overloaded (55 keys in monolith project) | open |
| GAP-OP-106 | No product-level module ownership model prior to this document | fixed |
| GAP-OP-107 | No API contract versioning governance prior to this document | fixed |

## 9. Enforcement

- **D43** (secrets namespace lock): Enforces `/spine/services/<module>/` namespace structure.
- **D18** (docker compose drift gate): Validates compose file references match SERVICE_REGISTRY.
- **Release gates** (section 6): Checked manually until a dedicated drift gate is added.
- **Proposal flow**: All agent-authored module changes go through `proposals.apply`.
- **This document** is the single source of truth for product-level governance.
  Infra-level governance remains under `AGENTS.md` and `AGENT_GOVERNANCE_BRIEF.md`.

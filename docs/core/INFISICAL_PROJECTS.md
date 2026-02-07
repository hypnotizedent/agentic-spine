# Infisical Projects (Canonical Map)

> **Status:** authoritative
> **Last verified:** 2026-02-04

**Purpose:** Prevent agent confusion. Agents MUST NOT guess which Infisical project to use.  
**Rule:** The spine runtime binds exactly ONE project at a time via `ops/bindings/secrets.binding.yaml`.  
**Enforcement:** All API-touching capabilities require: `[secrets.binding, secrets.auth.status]`

---

## Current Spine Binding (Runtime)

| Field | Value |
|-------|-------|
| provider | infisical |
| api_url | https://secrets.ronny.works |
| project | `01ddd93a-e0f8-4c7c-ad9f-903d76ef94d9` |
| project_name | infrastructure |
| environment | prod |
| base_path | /spine |

**Status:** ACTIVE (bound for capability work)

### Namespace Contract (Infrastructure/prod)

- Legacy keys currently exist at root path: `/` (historical debt).
- All new VM infra keys must be written under `/spine/*`.
- Caddy/Auth bootstrap namespace is fixed to:
  - `/spine/vm-infra/caddy-auth`
  - required keys: `AUTHENTIK_SECRET_KEY`, `AUTHENTIK_DB_PASSWORD`
- Enforcement capability:
  - `./bin/ops cap run secrets.namespace.status`

---

## Project Catalog (SSOT)

> **Source Attribution:** Seeded from `~/Code/workbench/infra/data/secrets_inventory.json`.
> The workbench inventory is the external SSOT for secret key counts and project lifecycle.
> This table is a snapshot for spine context.

Last updated: 2026-02-03

| lifecycle | project_name | project_id | env | keys | notes |
|---|---|---|---|---|---|
| **ACTIVE** | **infrastructure** | `01ddd93a-e0f8-4c7c-ad9f-903d76ef94d9` | prod | ~48 | **CURRENT SPINE BINDING**. Cloudflare, GitHub, Azure, NAS, system infrastructure |
| OVERLOADED | mint-os-api | `6c67b03e-ed17-4154-9a94-59837738e432` | prod | ~55 | Dashboard API, vendors, payments, Resend, Stripe. Proposed rename to 'mint-os' |
| OVERLAPS | mint-os-vault | `66d149d6-f610-4ec3-a400-3ff42ea1aa75` | prod | ~8 | Overlaps with mint-os-api; consolidation candidate |
| DELETE_CANDIDATE | mint-os-portal | `758e5db3-8d00-4ccf-8d91-aeaad0d6ed37` | prod | 0 | Empty project, delete candidate |
| CLEAN | n8n | `4b9dfc6d-13e8-43c8-bd84-9beb64eb8e16` | prod | ~8 | Automation workflows |
| CLEAN | finance-stack | `4c34714d-6d85-4aa6-b8df-5a9505f3bcef` | prod | ~14 | Firefly III, financial management |
| CLEAN | media-stack | `3807f1c4-e354-4aaf-a16f-8567d7f78a7e` | prod | ~20 | Jellyfin, *arr apps, media management |
| CLEAN_BUT_DUPED | immich | `4bf7f25e-596b-4293-9d2a-c2c7c2d0df42` | prod | ~19 | Keys duplicated in infrastructure; remove dupes from infra |
| CLEAN | home-assistant | `5df75515-7259-4c14-98b8-5adda379aade` | prod | ~7 | Smart home control |

---

## Lifecycle Definitions

| Status | Meaning | Agent Action |
|--------|---------|--------------|
| **ACTIVE** | Approved for agent capabilities | Allowed for `.requires[]` binding |
| CLEAN | Well-scoped, but not spine-bound | Use only if explicitly mapped |
| OVERLOADED | Too many keys, needs split | Do not bind; plan migration |
| OVERLAPS | Duplicated with another project | Do not bind; consolidate first |
| CLEAN_BUT_DUPED | Has duplicates in another project | Resolve before use |
| DELETE_CANDIDATE | Empty/obsolete | Do not use; schedule deletion |

---

## Spine Capability Scope

The spine-bound `infrastructure` project contains:

| Category | Key Patterns |
|----------|-------------|
| Cloudflare | `CLOUDFLARE_*` |
| Azure/Auth | `AZURE_*` |
| Infisical | `INFISICAL_*` |
| AI Services | `ANTHROPIC_*`, `OPENAI_*` (temporarily; migrate to `ai-services` project) |
| NAS/SMB | `SYNOLOGY_*`, `SMB_*` |
| Misc System | `PIHOLE_*`, `PAPERLESS_*` |

**Note:** Shopify keys (`SHOPIFY_*`) should move to mint-os project. Immich keys are duplicated.

---

## Future Taxonomy (Proposed)

When projects are cleaned up, the recommended structure is:

| Project | Scope | Current Equiv |
|---------|-------|---------------|
| spine-core | Provider/API keys for capabilities | `infrastructure` (pruned) |
| mint-os-api | Dashboard API runtime | `mint-os-api` + `mint-os-vault` (merged) |
| ai-services | AI provider keys | New (from `infrastructure`) |
| n8n | Automation | `n8n` (keep) |
| finance-stack | Firefly, Ghostfolio | `finance-stack` (keep) |
| media-stack | Jellyfin, *arr | `media-stack` (keep) |
| immich | Photos | `immich` (deduped) |
| home-assistant | Smart home | `home-assistant` (keep) |

---

## Agent Rules

1. **Never guess the project** — Check this file first
2. **Only bind ACTIVE projects** — Others are non-canonical
3. **If binding changes** — Update `ops/bindings/secrets.binding.yaml` AND this file
4. **Migration planning** — Use `proposed_restructure` section from legacy inventory

---

## Verification

To verify current binding:
```bash
./bin/ops cap run secrets.binding
```

To check if a project is ACTIVE:
```bash
grep "ACTIVE.*infrastructure" docs/core/INFISICAL_PROJECTS.md
```

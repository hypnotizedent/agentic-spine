---
status: draft
owner: "@ronny"
created: 2026-02-12
scope: pricing-secrets-namespace
loop_id: LOOP-MINT-PRICING-PHASE0-CONTRACT-20260212
---

# Pricing Module — Secrets Namespace Draft

> Planning artifact. No Infisical writes until Phase 1 sprint.

## 1. Proposed Infisical Paths

All pricing secrets live under a single dedicated namespace:

```
/spine/services/pricing/
```

This namespace is already declared in `ops/bindings/secrets.namespace.policy.yaml` (line 69).

### Infisical Project

- **Project:** `infrastructure` (project ID: `01ddd93a-e0f8-4c7c-ad9f-903d76ef94d9`)
- **Environment:** `prod`
- **Folder:** `/spine/services/pricing/`

The folder must be created via Infisical API before keys can be populated
(CLI `secrets set` silently fails if folder doesn't exist).

## 2. Required Keys

| Key | Path | Description | Example Format |
|-----|------|-------------|----------------|
| `PRICING_DATABASE_URL` | `/spine/services/pricing/` | PostgreSQL connection string | `postgresql://pricing:pass@host:5432/mint_modules` |
| `PRICING_API_KEY` | `/spine/services/pricing/` | API authentication key for external callers | 64-char hex |
| `PRICING_DB_PASSWORD` | `/spine/services/pricing/` | Standalone DB password (used in migration scripts) | random string |

### Future Keys (Phase 2+)

| Key | Path | Description | When Needed |
|-----|------|-------------|-------------|
| `PRICING_REDIS_URL` | `/spine/services/pricing/` | Redis cache connection | When caching layer added |
| `PRICING_MINIO_ACCESS_KEY` | `/spine/services/pricing/` | MinIO access (if pricing stores rate sheets) | If file storage needed |
| `PRICING_MINIO_SECRET_KEY` | `/spine/services/pricing/` | MinIO secret | If file storage needed |

## 3. Forbidden Root-Level Key Policy

Per `secrets.namespace.policy.yaml` enforcement:

- **No pricing keys at Infisical root path (`/`).** All must be under `/spine/services/pricing/`.
- The prefix `PRICING_` must be added to `forbidden_root_prefixes` in the policy file when Phase 1 begins.
- No pricing keys may be added to the deprecated `mint-os-api` Infisical project.

### Enforcement Checklist (Phase 1)

- [ ] Add `"PRICING_"` to `forbidden_root_prefixes` in `secrets.namespace.policy.yaml`
- [ ] Add all required keys to `key_path_overrides` in `secrets.namespace.policy.yaml`
- [ ] Create `/spine/services/pricing/` folder via Infisical API
- [ ] Populate keys via Infisical CLI using internal URL (`localhost:8088`)
- [ ] Verify with `infisical secrets list --path=/spine/services/pricing/`

## 4. Key Naming Conventions

All keys follow the pattern: `PRICING_<RESOURCE>_<ATTRIBUTE>`

- Prefix: `PRICING_` (module identifier, matches compose env var names)
- No generic names (`DB_URL`, `API_KEY`) — always module-prefixed
- Shared infrastructure keys (MinIO, Redis) are duplicated per namespace (not cross-referenced)
- This follows the established pattern from artwork (`ARTWORK_DATABASE_URL`) and quote-page (`QUOTE_PAGE_MINIO_ACCESS_KEY`)

## 5. Rotation Notes

### Rotation Schedule

| Key | Rotation Frequency | Method |
|-----|--------------------|--------|
| `PRICING_API_KEY` | 90 days | Generate new key, update Infisical, redeploy container |
| `PRICING_DB_PASSWORD` | 180 days | Update Infisical + PostgreSQL `ALTER ROLE`, redeploy |
| `PRICING_DATABASE_URL` | When DB password rotates | Derived from `PRICING_DB_PASSWORD`, update simultaneously |

### Rotation Procedure

1. Generate new secret value
2. Update in Infisical via CLI: `infisical secrets set PRICING_<KEY>=<value> --path=/spine/services/pricing/`
3. Redeploy pricing container: `docker compose up -d --no-deps pricing`
4. Verify health endpoint returns 200
5. Record rotation in spine receipt ledger

### Emergency Rotation

If a key is compromised:
1. Immediately rotate the key in Infisical
2. Redeploy the container
3. If `PRICING_DB_PASSWORD`: also run `ALTER ROLE pricing_user WITH PASSWORD '<new>'` on PostgreSQL
4. Audit access logs for the compromised key's usage window
5. File a GAP-OP entry if the compromise reveals a governance gap

## 6. Cross-Module Secret Sharing

- **No shared secret references.** If pricing needs MinIO access, it gets its own `PRICING_MINIO_ACCESS_KEY` (duplicated from `MINIO_ROOT_USER`, not a pointer to `/spine/storage/minio/`).
- **DATABASE_URL** connects to the same PostgreSQL instance as other modules but uses a pricing-specific database role with scoped permissions.
- This isolation ensures one module's key rotation never breaks another module.

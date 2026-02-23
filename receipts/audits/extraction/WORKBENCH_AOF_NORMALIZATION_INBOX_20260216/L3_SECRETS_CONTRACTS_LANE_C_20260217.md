# L3: Secrets/Contracts/Injection Normalization Audit (Lane C)

> **Audit Type:** Read-only lane (no fixes, no commits, no secret mutation)
> **Scope:** Workbench AOF normalization scan
> **Date:** 2026-02-17
> **Auditor:** OpenCode Terminal C (Lane C)
> **Spine Preflight:** Core-8 PASS, Secrets namespace OK_WITH_LEGACY_DEBT, Runway FAIL (6 missing mint module keys)

---

## Executive Summary

| Metric | Count |
|--------|-------|
| Deprecated Project Injection (`finance-stack`) | 6 files |
| Key-Name Drift (`FIREFLY_ACCESS_TOKEN`) | 5 locations |
| Deprecated Project Reference (`mint-os-vault`) | 12 locations |
| Injection Path Consistency Issues | 2 locations |
| **Total Findings** | **25** |

---

## Canonical Contract References

| Contract | Path | Last Verified |
|----------|------|---------------|
| secrets.namespace.policy.yaml | `ops/bindings/secrets.namespace.policy.yaml` | 2026-02-16 |
| secrets.runway.contract.yaml | `ops/bindings/secrets.runway.contract.yaml` | 2026-02-17 |
| secrets.inventory.yaml | `ops/bindings/secrets.inventory.yaml` | 2026-02-13 |

### Canonical Key Placements (Finance)

| Key | Project | Path | Source |
|-----|---------|------|--------|
| `FIREFLY_PAT` | infrastructure | `/spine/services/finance` | runway.contract:key_overrides |
| `PAPERLESS_API_TOKEN` | infrastructure | `/spine/services/paperless` | runway.contract:key_overrides |
| `SIMPLEFIN_ACCESS_URL` | infrastructure | `/spine/services/finance` | namespace.policy:key_path_overrides |
| `FIREFLY_API_URL` | infrastructure | `/spine/services/finance` | namespace.policy:key_path_overrides |

---

## Findings (Severity-Ordered)

### SEV-1: Deprecated Project Injection in Active Docs

**Category:** deprecated-reference drift

| File | Line | Issue |
|------|------|-------|
| `docs/brain-lessons/FINANCE_ACCOUNT_TOPOLOGY.md` | 100-102 | References `/finance-stack/prod/SIMPLEFIN_ACCESS_URL`, `/finance-stack/prod/FIREFLY_ACCESS_TOKEN`, `/finance-stack/prod/DATA_IMPORTER_CLIENT_ID` |
| `docs/brain-lessons/FINANCE_BACKUP_RESTORE.md` | 144 | References `/finance-stack/prod/POSTGRES_PASSWORD` |
| `docs/brain-lessons/FINANCE_SIMPLEFIN_PIPELINE.md` | 85-87 | References `/finance-stack/prod/SIMPLEFIN_ACCESS_URL`, `/finance-stack/prod/FIREFLY_ACCESS_TOKEN`, `/finance-stack/prod/TEAMS_WEBHOOK_URL` |
| `docs/brain-lessons/FINANCE_N8N_WORKFLOWS.md` | 170-171 | References `/finance-stack/prod/PAPERLESS_API_TOKEN`, `/finance-stack/prod/FIREFLY_ACCESS_TOKEN` |
| `docs/brain-lessons/FINANCE_DEPLOY_RUNBOOK.md` | 79 | References `/finance-stack/prod/FIREFLY_ACCESS_TOKEN` |

**Canonical Migration Rule:**
- `/finance-stack/prod/*` → `infrastructure prod /spine/services/finance/*` (for finance keys)
- `/finance-stack/prod/PAPERLESS_API_TOKEN` → `infrastructure prod /spine/services/paperless/PAPERLESS_API_TOKEN`

---

### SEV-2: Key-Name Drift (FIREFLY_ACCESS_TOKEN vs FIREFLY_PAT)

**Category:** key-name drift

| File | Line | Issue |
|------|------|-------|
| `docs/brain-lessons/FINANCE_ACCOUNT_TOPOLOGY.md` | 101 | Uses `FIREFLY_ACCESS_TOKEN` (legacy) not `FIREFLY_PAT` (canonical) |
| `docs/brain-lessons/FINANCE_SIMPLEFIN_PIPELINE.md` | 86 | Uses `FIREFLY_ACCESS_TOKEN` (legacy) not `FIREFLY_PAT` (canonical) |
| `docs/brain-lessons/FINANCE_N8N_WORKFLOWS.md` | 171 | Uses `FIREFLY_ACCESS_TOKEN` (legacy) not `FIREFLY_PAT` (canonical) |
| `docs/brain-lessons/FINANCE_DEPLOY_RUNBOOK.md` | 79 | Uses `FIREFLY_ACCESS_TOKEN` (legacy) not `FIREFLY_PAT` (canonical) |
| `docs/legacy/infrastructure/reference/secrets/SECRET_ROTATION.md` | 166, 176, 179 | Uses `FIREFLY_ACCESS_TOKEN` in examples |

**Canonical Migration Rule:**
- `FIREFLY_ACCESS_TOKEN` → `FIREFLY_PAT` (canonical name per namespace.policy)
- Injection command: `infisical-agent.sh get infrastructure prod FIREFLY_PAT`

---

### SEV-2: Deprecated Project Reference (mint-os-vault)

**Category:** project/path drift

| File | Line | Issue |
|------|------|-------|
| `scripts/agents/infisical-agent.sh` | 70 | Maps `mint-os-vault` project ID (read-only guard active) |
| `scripts/agents/infisical-agent.sh` | 241, 670 | Lists `mint-os-vault` as deprecated/consolidation candidate |
| `infra/data/secrets_inventory.json` | 40, 154, 367 | References `mint-os-vault` in project catalog |
| `scripts/root/backup/backup-infisical-secrets.sh` | 23 | Includes `mint-os-vault` in backup target list |
| `docs/legacy/infrastructure/reference/KEY_MANAGEMENT_PLAN.md` | 45, 292 | Documents `mint-os-vault` project details |
| `docs/legacy/infrastructure/reference/secrets/SECRETS_REFERENCE.md` | 127, 179 | References `mint-os-vault` for DB credentials |
| `docs/legacy/infrastructure/runbooks/SCRIPTS_REGISTRY.md` | 332 | Example uses `mint-os-vault prod POSTGRES_PASSWORD` |
| `docs/legacy/infrastructure/runbooks/N8N_GOVERNANCE.md` | 268 | Lists `mint-os-vault` key dependencies |
| `docs/legacy/infrastructure/runbooks/INFISICAL_GOVERNANCE.md` | 82, 106, 226 | Marks `mint-os-vault` as PENDING DELETE |

**Canonical Migration Rule:**
- `mint-os-vault` keys → `mint-os-api` (project consolidation per INFISICAL_GOVERNANCE.md)
- DB credentials: `mint-os-vault prod POSTGRES_PASSWORD` → `mint-os-api prod DB_PASSWORD`

---

### SEV-3: Injection Path Consistency (Scripts vs Docs)

**Category:** injection-path drift

**CORRECT (Active Scripts):**
| File | Line | Pattern |
|------|------|---------|
| `scripts/finance/simplefin-daily-sync.sh` | 43 | `infisical-agent get infrastructure prod FIREFLY_PAT` |
| `scripts/root/firefly/backfill-all.sh` | 29-30 | `infisical-agent get infrastructure prod FIREFLY_API_URL/FIREFLY_PAT` |
| `scripts/root/firefly/reconciliation-report.sh` | 13-14 | `infisical-agent get infrastructure prod FIREFLY_API_URL/FIREFLY_PAT` |
| `agents/finance/docs/RUNBOOK.md` | 31-32 | Canonical spine paths: `infisical-agent.sh get infrastructure prod FIREFLY_PAT` |

**DRIFT (Legacy Docs):**
| File | Line | Issue |
|------|------|-------|
| `docs/legacy/infrastructure/runbooks/SCRIPTS_REGISTRY.md` | 332 | Uses `mint-os-vault prod POSTGRES_PASSWORD` |
| `docs/legacy/infrastructure/reference/secrets/SECRET_ROTATION.md` | 175-176 | Uses `finance-stack prod FIREFLY_PAT` |

---

## Runway Status (from Preflight)

The `secrets.runway.status` capability reported **6 failures** for mint module keys:

| Missing Key | Domain | Expected Project | Expected Path |
|-------------|--------|------------------|---------------|
| `SHIPPING_API_KEY` | mint-shipping | infrastructure | `/spine/services/shipping` |
| `SHIPPING_DATABASE_URL` | mint-shipping | infrastructure | `/spine/services/shipping` |
| `PRICING_API_KEY` | mint-pricing | infrastructure | `/spine/services/pricing` |
| `PRICING_DATABASE_URL` | mint-pricing | infrastructure | `/spine/services/pricing` |
| `SUPPLIERS_API_KEY` | mint-suppliers | infrastructure | `/spine/services/suppliers` |
| `SUPPLIERS_DATABASE_URL` | mint-suppliers | infrastructure | `/spine/services/suppliers` |

**Fix Command:** `./bin/ops cap run secrets.set.interactive infrastructure prod`

---

## Recommended Canonical Migration Rules

### Rule 1: Finance Key Normalization
```bash
# BEFORE (deprecated)
infisical-agent.sh get finance-stack prod FIREFLY_ACCESS_TOKEN

# AFTER (canonical)
infisical-agent.sh get infrastructure prod FIREFLY_PAT
# Resolves to: /spine/services/finance/FIREFLY_PAT
```

### Rule 2: Paperless Key Normalization
```bash
# BEFORE (deprecated project)
/finance-stack/prod/PAPERLESS_API_TOKEN

# AFTER (canonical)
infisical-agent.sh get infrastructure prod PAPERLESS_API_TOKEN
# Resolves to: /spine/services/paperless/PAPERLESS_API_TOKEN
```

### Rule 3: Mint DB Key Normalization
```bash
# BEFORE (deprecated project)
infisical-agent.sh get mint-os-vault prod POSTGRES_PASSWORD

# AFTER (canonical)
infisical-agent.sh get mint-os-api prod DB_PASSWORD
```

---

## Appendix: Evidence Sources

- Workbench scan: `rg -n "FIREFLY_ACCESS_TOKEN|FIREFLY_PAT|PAPERLESS|INFISICAL|finance-stack|mint-os-vault"`
- Spine contracts: `ops/bindings/secrets.*.yaml`
- Preflight receipts: `RCAP-20260216-235246__*`

---

## Coverage Checklist

- [x] Secret key naming conventions and alias drift
- [x] Project/path contract consistency (Infisical)
- [x] Injection mechanism consistency (.env, runtime, CLI)
- [x] Deprecated project references and migration safety
- [x] Runway missing key detection

---

**LANE C COMPLETE**

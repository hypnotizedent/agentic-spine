# L3: Secrets/Contracts/Injection Normalization Audit (OpenCode Terminal C)

**Audit Date:** 2026-02-16
**Auditor:** OpenCode Terminal C (Lane C)
**Scope:** Workbench secrets patterns vs canonical spine contracts
**Mode:** Read-only audit (no fixes, no commits, no secret mutation)

---

## Executive Summary

| Category | Drift Count | Severity |
|----------|-------------|----------|
| Deprecated Project References | 8 | HIGH |
| Key-Name Drift | 3 | MEDIUM |
| Project/Path Drift | 4 | HIGH |
| Injection-Path Drift | 12 | HIGH |
| Stale Documentation References | 15+ | LOW |

**Overall Status:** DRIFT DETECTED

Canonical contracts:
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/secrets.namespace.policy.yaml`
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/secrets.runway.contract.yaml`
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/secrets.inventory.yaml`

---

## Findings (Severity Ordered)

### [P1] Deprecated `finance-stack` Project References

- **Surface:** workbench/docs, workbench/scripts
- **Problem:** Multiple files reference `/finance-stack/prod/*` paths that point to deprecated Infisical project.
- **Impact:** Documentation inconsistency; scripts may fail if finance-stack project is deleted.
- **Evidence:**
  - `/Users/ronnyworks/code/workbench/docs/brain-lessons/FINANCE_BACKUP_RESTORE.md:144`
  - `/Users/ronnyworks/code/workbench/docs/brain-lessons/FINANCE_N8N_WORKFLOWS.md:170-171`
  - `/Users/ronnyworks/code/workbench/docs/brain-lessons/FINANCE_ACCOUNT_TOPOLOGY.md:100-102`
  - `/Users/ronnyworks/code/workbench/docs/brain-lessons/FINANCE_SIMPLEFIN_PIPELINE.md:85-87`
  - `/Users/ronnyworks/code/workbench/docs/brain-lessons/FINANCE_DEPLOY_RUNBOOK.md:79`
  - `/Users/ronnyworks/code/workbench/scripts/root/backup/backup-infisical-secrets.sh:23`
- **Canonical rule (expected):** All finance secrets in `infrastructure` project at `/spine/services/finance/`, `/spine/services/paperless/`, `/spine/services/mail-archiver/`.
- **Recommended normalization:** Replace `/finance-stack/prod/KEY` → `infrastructure/prod` with path `/spine/services/finance/KEY`.

---

### [P1] Key-Name Drift: `FIREFLY_ACCESS_TOKEN` vs `FIREFLY_PAT`

- **Surface:** workbench/docs
- **Problem:** Documentation uses non-canonical key name `FIREFLY_ACCESS_TOKEN`.
- **Impact:** Confusion for operators; potential script failures if key lookup uses wrong name.
- **Evidence:**
  - `/Users/ronnyworks/code/workbench/docs/brain-lessons/FINANCE_N8N_WORKFLOWS.md:171`
  - `/Users/ronnyworks/code/workbench/docs/brain-lessons/FINANCE_ACCOUNT_TOPOLOGY.md:101`
  - `/Users/ronnyworks/code/workbench/docs/brain-lessons/FINANCE_DEPLOY_RUNBOOK.md:79`
  - `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/secrets/SECRET_ROTATION.md:166,176,179`
- **Canonical rule (expected):** `FIREFLY_PAT` (Personal Access Token) per `secrets.namespace.policy.yaml:134`.
- **Recommended normalization:** Global replace `FIREFLY_ACCESS_TOKEN` → `FIREFLY_PAT` in documentation.

---

### [P1] Deprecated `mint-os-vault` Project in Backup Script

- **Surface:** workbench/scripts
- **Problem:** Backup script includes deprecated `mint-os-vault` project in backup array.
- **Impact:** Backing up deprecated project; potential confusion about which projects are active.
- **Evidence:**
  - `/Users/ronnyworks/code/workbench/scripts/root/backup/backup-infisical-secrets.sh:23`
- **Canonical rule (expected):** Per `secrets.inventory.yaml:33-37`, `mint-os-vault` is deprecated (RBAC viewer-only, consolidation candidate).
- **Recommended normalization:** Remove `"mint-os-vault"` and `"finance-stack"` from backup array.

---

### [P1] Media Stack MCP Injection Path Drift

- **Surface:** workbench/infra/compose/mcpjungle
- **Problem:** MCPJungle media-stack.json uses `media-stack/prod/` for *arr keys, but runway contract routes them to `infrastructure` project.
- **Impact:** Keys may not resolve correctly if they only exist in `infrastructure` project.
- **Evidence:**
  - `/Users/ronnyworks/code/workbench/infra/compose/mcpjungle/servers/media-stack.json:14` (`RADARR_API_KEY`)
  - `/Users/ronnyworks/code/workbench/infra/compose/mcpjungle/servers/media-stack.json:16` (`SONARR_API_KEY`)
  - `/Users/ronnyworks/code/workbench/infra/compose/mcpjungle/servers/media-stack.json:18` (`LIDARR_API_KEY`)
- **Canonical rule (expected):** Per `secrets.runway.contract.yaml:105-113`, these keys route to `project: infrastructure` at `path: /spine/vm-infra/media-stack/download`.
- **Recommended normalization:** Verify key location. If in infrastructure, update injection path to `<GET_FROM_INFISICAL:infrastructure/prod/spine/vm-infra/media-stack/download/RADARR_API_KEY>`.

---

### [P2] `PAPERLESS_SECRET_KEY` Undocumented Key

- **Surface:** workbench/docs
- **Problem:** Reference to `PAPERLESS_SECRET_KEY` not in canonical namespace policy.
- **Impact:** Documentation references non-canonical key; potential confusion.
- **Evidence:**
  - `/Users/ronnyworks/code/workbench/docs/brain-lessons/FINANCE_STACK_ARCHITECTURE.md:119`
- **Canonical rule (expected):** `PAPERLESS_API_TOKEN` at `/spine/services/paperless` is the canonical key per `secrets.namespace.policy.yaml:140`.
- **Recommended normalization:** Verify if `PAPERLESS_SECRET_KEY` exists; either add to policy or update doc to use `PAPERLESS_API_TOKEN`.

---

### [P2] Unregistered Media Keys in MCP Config

- **Surface:** workbench/infra/compose/mcpjungle
- **Problem:** `BAZARR_API_KEY` used in MCP config but not registered in runway contract.
- **Impact:** Key may not be validated by secrets.runway.status capability.
- **Evidence:**
  - `/Users/ronnyworks/code/workbench/infra/compose/mcpjungle/servers/media-stack.json:26`
- **Canonical rule (expected):** All domain keys should be registered in `secrets.runway.contract.yaml` required_domain_keys or key_overrides.
- **Recommended normalization:** Add `BAZARR_API_KEY` to runway contract if actively used.

---

### [P3] Stale Brain-Lessons Paths (Documentation Only)

- **Surface:** workbench/docs/brain-lessons
- **Problem:** Finance brain-lessons still contain `/finance-stack/prod/` paths.
- **Impact:** Documentation drift from current architecture; potential confusion.
- **Evidence:**
  - Multiple files under `/Users/ronnyworks/code/workbench/docs/brain-lessons/FINANCE_*.md`
- **Canonical rule (expected):** Paths should match `infrastructure/prod/spine/services/finance/`.
- **Recommended normalization:** Batch update brain-lessons during next finance domain work.

---

## Correctly Aligned Baseline (No Action Needed)

The following patterns are already aligned with canonical contracts:

| File | Pattern | Status |
|------|---------|--------|
| `scripts/finance/simplefin-daily-sync.sh:42-43` | `get infrastructure prod SIMPLEFIN_ACCESS_URL/FIREFLY_PAT` | ALIGNED |
| `scripts/finance/simplefin-to-firefly.py:19-20` | `infrastructure/prod/spine/services/finance/*` | ALIGNED |
| `agents/finance/docs/RUNBOOK.md:24-25,31-32` | Canonical paths documented | ALIGNED |
| `agents/finance/config/services.yaml:15,36,54` | `infisical_path: /spine/services/*` | ALIGNED |
| `infra/compose/mcpjungle/servers/firefly.json:10` | Full canonical path | ALIGNED |
| `infra/compose/mcpjungle/servers/paperless.json:9` | Full canonical path | ALIGNED |
| `infra/compose/mcpjungle/servers/github.json:8` | `infrastructure/prod/GITHUB_PERSONAL_ACCESS_TOKEN` | ALIGNED |
| `infra/compose/mcpjungle/servers/home-assistant.json:9` | `home-assistant/prod/HA_API_TOKEN` | ALIGNED |
| `infra/compose/mcpjungle/servers/microsoft-graph.json:8-10` | `infrastructure/prod/AZURE_*` | ALIGNED |

---

## Missing Keys (from secrets.runway.status)

Infrastructure gaps detected by runway capability (not workbench drift):

| Key | Domain | Expected Path |
|-----|--------|---------------|
| `SHIPPING_API_KEY` | mint-shipping | `/spine/services/shipping` |
| `SHIPPING_DATABASE_URL` | mint-shipping | `/spine/services/shipping` |
| `PRICING_API_KEY` | mint-pricing | `/spine/services/pricing` |
| `PRICING_DATABASE_URL` | mint-pricing | `/spine/services/pricing` |
| `SUPPLIERS_API_KEY` | mint-suppliers | `/spine/services/suppliers` |
| `SUPPLIERS_DATABASE_URL` | mint-suppliers | `/spine/services/suppliers` |

---

## Coverage Checklist

- [x] Secret key naming conventions and alias drift
- [x] Project/path contract consistency (Infisical)
- [x] Injection mechanism consistency (.env, runtime, CLI)
- [x] Deprecated project references and migration safety

---

*Audit complete. No mutations made. Read-only lane.*

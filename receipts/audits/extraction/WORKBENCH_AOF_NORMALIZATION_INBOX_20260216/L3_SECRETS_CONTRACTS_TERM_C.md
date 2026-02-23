# Lane C — Secrets, Contracts, Injection Paths

> **Audit Date:** 2026-02-17
> **Auditor:** OpenCode Terminal C (Lane C)
> **Scope:** Workbench secrets references, injection paths, and contract alignment
> **Status:** Read-only audit (no fixes, no commits, no secret mutation)

---

## Summary

| Metric | Count |
|--------|-------|
| Key-Name Drift Issues | 7 |
| Project/Path Drift Issues | 12 |
| Injection-Path Drift Issues | 8 |
| Deprecated-Reference Issues | 15 |
| **Total Findings** | **42** |

**Critical Pattern:** Workbench contains extensive references to deprecated Infisical projects (`finance-stack`, `mint-os-vault`) and legacy key naming conventions that conflict with canonical spine contracts.

---

## Findings (Severity Ordered)

### P0-1: Deprecated `finance-stack` Project References in Active Scripts

- **Surface:** scripts/root/backup
- **Problem:** Backup script explicitly lists deprecated projects for backup operations.
- **Impact:** Backup may miss canonical secrets or backup stale deprecated keys.
- **Evidence:**
  - `/Users/ronnyworks/code/workbench/scripts/root/backup/backup-infisical-secrets.sh:23-26`
- **Canonical rule:** `finance-stack` → `infrastructure` project, path `/spine/services/finance`
- **Recommended normalization:** Replace `"finance-stack"` with `"infrastructure"` and update path references.

---

### P0-2: `infisical-agent.sh` Deprecated Project IDs Hardcoded

- **Surface:** scripts/agents
- **Problem:** Deprecated project IDs are hardcoded with read guards but still expose IDs for potential use.
- **Impact:** Scripts may still resolve to deprecated projects, returning stale or missing keys.
- **Evidence:**
  - `/Users/ronnyworks/code/workbench/scripts/agents/infisical-agent.sh:49-53`
  - `/Users/ronnyworks/code/workbench/scripts/agents/infisical-agent.sh:70-73`
- **Canonical rule:** `finance-stack` project deprecated; use `infrastructure` /spine/services/finance
- **Recommended normalization:** Remove deprecated project ID mappings or return error instead of ID.

---

### P0-3: `FIREFLY_ACCESS_TOKEN` Key-Name Drift

- **Surface:** docs/brain-lessons, infra/compose/mcpjungle
- **Problem:** References use `FIREFLY_ACCESS_TOKEN` but canonical key is `FIREFLY_PAT`.
- **Impact:** Scripts/docs referencing wrong key name will fail to resolve.
- **Evidence:**
  - `/Users/ronnyworks/code/workbench/docs/brain-lessons/FINANCE_ACCOUNT_TOPOLOGY.md:101`
  - `/Users/ronnyworks/code/workbench/docs/brain-lessons/FINANCE_SIMPLEFIN_PIPELINE.md:86`
  - `/Users/ronnyworks/code/workbench/docs/brain-lessons/FINANCE_N8N_WORKFLOWS.md:171`
  - `/Users/ronnyworks/code/workbench/docs/brain-lessons/FINANCE_DEPLOY_RUNBOOK.md:79`
- **Canonical rule:** `secrets.namespace.policy.yaml:134` defines `FIREFLY_PAT: "/spine/services/finance"`
- **Recommended normalization:** Replace `FIREFLY_ACCESS_TOKEN` → `FIREFLY_PAT` in all references.

---

### P0-4: `PAPERLESS_SECRET_KEY` Key-Name Drift

- **Surface:** docs/brain-lessons
- **Problem:** Reference uses `PAPERLESS_SECRET_KEY` but canonical is `PAPERLESS_API_TOKEN`.
- **Impact:** Documentation mismatch; operators may set wrong key.
- **Evidence:**
  - `/Users/ronnyworks/code/workbench/docs/brain-lessons/FINANCE_STACK_ARCHITECTURE.md:119`
- **Canonical rule:** `secrets.namespace.policy.yaml:140` defines `PAPERLESS_API_TOKEN: "/spine/services/paperless"`
- **Recommended normalization:** Update to `PAPERLESS_API_TOKEN` (verify Django secret is separate key).

---

### P0-5: MCP Server Placeholder Injection Path Mismatch

- **Surface:** infra/compose/mcpjungle/servers
- **Problem:** MCP config uses `media-stack/prod/` path but canonical path differs for download keys.
- **Impact:** Some keys resolve to wrong project/path, causing API failures.
- **Evidence:**
  - `/Users/ronnyworks/code/workbench/infra/compose/mcpjungle/servers/media-stack.json:14-18`
- **Canonical rule:** `RADARR_API_KEY` → `infrastructure` project, path `/spine/vm-infra/media-stack/download`
- **Recommended normalization:**
  ```json
  "RADARR_API_KEY": "<GET_FROM_INFISICAL:infrastructure/prod/spine/vm-infra/media-stack/download/RADARR_API_KEY>"
  ```

---

### P0-6: Firefly MCP Token Path Mismatch

- **Surface:** infra/compose/mcpjungle/servers
- **Problem:** Config uses `FIREFLY_III_PAT` but actual key is `FIREFLY_PAT`.
- **Impact:** Injection tool may expect wrong env var name.
- **Evidence:**
  - `/Users/ronnyworks/code/workbench/infra/compose/mcpjungle/servers/firefly.json:10`
- **Canonical rule:** `secrets.runway.contract.yaml:78-80` confirms key name is `FIREFLY_PAT`
- **Recommended normalization:** Align env var name with canonical key name or add alias.

---

### P1-1: `SABNZBD_API_KEY` vs `SABNZBD_REMOTE_API_KEY` Drift

- **Surface:** agents/media/tools
- **Problem:** Fallback pattern exists but canonical key name not defined in policy.
- **Impact:** No canonical reference; may use wrong key at runtime.
- **Evidence:**
  - `/Users/ronnyworks/code/workbench/agents/media/tools/src/index.ts:44`
- **Canonical rule:** Not defined in `secrets.namespace.policy.yaml`
- **Recommended normalization:** Add canonical definition: `SABNZBD_API_KEY: "/spine/vm-infra/media-stack/download"`

---

### P1-2: `NAVIDROME_USERNAME` vs `NAVIDROME_USER` Drift

- **Surface:** agents/media/tools
- **Problem:** Code uses `NAVIDROME_USERNAME` as primary with `NAVIDROME_USER` fallback.
- **Impact:** Inconsistent key resolution.
- **Evidence:**
  - `/Users/ronnyworks/code/workbench/agents/media/tools/src/index.ts:56`
- **Canonical rule:** `secrets.namespace.policy.yaml:47` defines `NAVIDROME_USER: "/spine/vm-infra/media-stack/streaming"`
- **Recommended normalization:** Standardize on `NAVIDROME_USER` everywhere.

---

### P1-3: `HA_TOKEN` vs `HA_API_TOKEN` Drift

- **Surface:** infra/compose/mcpjungle/servers/home-assistant
- **Problem:** MCP config uses `HA_TOKEN` env var but canonical key is `HA_API_TOKEN`.
- **Impact:** Environment variable mismatch.
- **Evidence:**
  - `/Users/ronnyworks/code/workbench/infra/compose/mcpjungle/servers/home-assistant.json:9`
  - `/Users/ronnyworks/code/workbench/infra/compose/mcpjungle/servers/home-assistant/src/index.ts:34`
- **Canonical rule:** `secrets.namespace.policy.yaml:171` defines `HA_API_TOKEN: "/spine/home/ha"`
- **Recommended normalization:** Standardize on `HA_API_TOKEN`.

---

### P1-4: `FIREFLY_TOKEN` vs `FIREFLY_PAT` in Script

- **Surface:** scripts/finance
- **Problem:** Script uses `FIREFLY_TOKEN` but canonical is `FIREFLY_PAT`.
- **Impact:** Script may fail to find env var.
- **Evidence:**
  - `/Users/ronnyworks/code/workbench/scripts/finance/import-payments-to-firefly.js:18`
- **Canonical rule:** `secrets.namespace.policy.yaml:134` defines `FIREFLY_PAT`
- **Recommended normalization:** Use `process.env.FIREFLY_PAT || process.env.FIREFLY_TOKEN`

---

### P1-5: `/finance-stack/prod/` Path References in Documentation

- **Surface:** docs/brain-lessons
- **Problem:** Docs reference deprecated `/finance-stack/prod/` path.
- **Impact:** Operators may use wrong path during manual operations.
- **Evidence:**
  - `/Users/ronnyworks/code/workbench/docs/brain-lessons/FINANCE_SIMPLEFIN_PIPELINE.md:85-87`
  - `/Users/ronnyworks/code/workbench/docs/brain-lessons/FINANCE_ACCOUNT_TOPOLOGY.md:100-101`
- **Canonical rule:** `/spine/services/finance/` in `infrastructure` project
- **Recommended normalization:** Replace `/finance-stack/prod/` → `infrastructure/prod/spine/services/finance/`

---

### P1-6: `secrets_inventory.json` Deprecated Project Entries

- **Surface:** infra/data
- **Problem:** Inventory still lists deprecated projects.
- **Impact:** Inventory drift from canonical state.
- **Evidence:**
  - `/Users/ronnyworks/code/workbench/infra/data/secrets_inventory.json:89,40`
- **Canonical rule:** `finance-stack` and `mint-os-vault` are deprecated
- **Recommended normalization:** Mark as deprecated or remove entries.

---

### P2-1: `mint-os-vault` Project References

- **Surface:** infra/data, scripts
- **Problem:** References to deprecated `mint-os-vault` project persist.
- **Impact:** Documentation inconsistency.
- **Evidence:**
  - `/Users/ronnyworks/code/workbench/infra/data/secrets_inventory.json:40`
  - `/Users/ronnyworks/code/workbench/scripts/agents/infisical-agent.sh:70`
- **Canonical rule:** `mint-os-vault` consolidated into `mint-os-api`
- **Recommended normalization:** Update references to `mint-os-api`.

---

### P2-2: `.env.example` Templates Lack Canonical Path Comments

- **Surface:** agents/*/tools/.env.example
- **Problem:** Template files use correct key names but lack canonical path comments.
- **Impact:** Operators may not know where to source keys.
- **Evidence:**
  - `/Users/ronnyworks/code/workbench/agents/finance/tools/.env.example:6`
  - `/Users/ronnyworks/code/workbench/agents/media/tools/.env.example:5`
- **Canonical rule:** Keys should document Infisical source
- **Recommended normalization:** Add Infisical path comments to templates.

---

### P2-3: Legacy `docs/legacy/` Path References

- **Surface:** docs/legacy
- **Problem:** Legacy docs contain outdated path references.
- **Impact:** Historical reference may be misleading.
- **Evidence:** Multiple files in `/Users/ronnyworks/code/workbench/docs/legacy/`
- **Canonical rule:** Legacy docs should note they are superseded
- **Recommended normalization:** Add deprecation banners with canonical alternatives.

---

## Canonical Contract Summary

### Active Projects (per `secrets.runway.contract.yaml`)

| Project | Status | Scope |
|---------|--------|-------|
| `infrastructure` | Active | Finance, platform, network |
| `n8n` | Active | Automation secrets |
| `media-stack` | Active | Media services (streaming) |
| `immich` | Active | Photo management |
| `home-assistant` | Active | HA API tokens |
| `mint-os-api` | Active | Core Mint OS keys |
| `ai-services` | Active | AI provider keys |

### Deprecated Projects

| Project | Migration Target |
|---------|-----------------|
| `finance-stack` | `infrastructure` `/spine/services/finance/` |
| `mint-os-vault` | `mint-os-api` `/` |

---

## Recommended Migration Rules

### Rule 1: Finance Key Normalization
```
FIREFLY_ACCESS_TOKEN → FIREFLY_PAT
/finance-stack/prod/* → infrastructure/prod/spine/services/finance/
```

### Rule 2: Project Reference Normalization
```
finance-stack → infrastructure
mint-os-vault → mint-os-api
```

### Rule 3: Media Download Key Path
```
media-stack/prod/RADARR_API_KEY → infrastructure/prod/spine/vm-infra/media-stack/download/RADARR_API_KEY
```

### Rule 4: Env Var Standardization
```
HA_TOKEN → HA_API_TOKEN
FIREFLY_TOKEN → FIREFLY_PAT
NAVIDROME_USERNAME → NAVIDROME_USER
```

---

## Coverage Checklist

- [x] Secret key naming conventions and alias drift
- [x] Project/path contract consistency (Infisical)
- [x] Injection mechanism consistency (.env, runtime, CLI)
- [x] Deprecated project references and migration safety

---

## Evidence File

Raw grep output available at:
`/Users/ronnyworks/code/agentic-spine/docs/governance/_audits/WORKBENCH_AOF_NORMALIZATION_INBOX_20260216/EVIDENCE_L3.txt`

---

**Lane C Audit Complete.**

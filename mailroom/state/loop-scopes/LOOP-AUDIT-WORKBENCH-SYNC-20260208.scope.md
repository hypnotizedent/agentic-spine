# LOOP-AUDIT-WORKBENCH-SYNC-20260208

> **Status:** OPEN
> **Owner:** @ronny
> **Created:** 2026-02-08
> **Severity:** high
> **Origin:** Deep cross-VM audit (Cowork session, Opus 4.6 subagents)

---

## Executive Summary

A four-subagent parallel audit of the agentic-spine and workbench identified 23 disconnects concentrated in workbench documentation that has not been updated following recent VM restructuring (LOOP-INFRA-VM-RESTRUCTURE-20260206), AI consolidation (LOOP-AI-CONSOLIDATION-20260208), and observability deployment (LOOP-OBSERVABILITY-DEPLOY-20260208).

Spine governance is correct and authoritative. Most drift was workbench-side: stale snapshots, legacy compose files, localhost references in RAG scripts, and duplicated authority claims.

### Status Update (2026-02-09)

Workbench-side P0/P1 remediation is complete in two commits:
- `92a9af9` (workbench): doc authority redirect + deprecations (stop parallel SSOT claims)
- `6ff7e16` (workbench): P0/P1 mechanical fixes (archive legacy compose, RAG defaults, doc deprecations)

Spine-side service registration for automation-stack companion services (MT-4) is already in place:
- `docs/governance/SERVICE_REGISTRY.yaml`: `open-webui`, `ollama`, `automation-postgres`, `automation-redis`
- `ops/bindings/services.health.yaml`: health probes for `n8n`, `open-webui`, `ollama`

Remaining spine-side tasks to finish this loop:
- MT-9: apply Prometheus multi-host scrape targets on observability (VM 205)
  - Staged config updated in spine: `ops/staged/observability/prometheus/prometheus.yml`
  - Still requires on-host apply + Prometheus reload/restart

---

## Scope

| VM | Audit Focus | Key Finding |
|----|-------------|-------------|
| infra-core (204) | Service parity, compose authority | Workbench pihole compose has wrong IP; legacy docs reference docker-host |
| observability (205) | Monitoring stack coherence | **CRITICAL:** Legacy docker-compose.monitoring.yml could create duplicate Prometheus/Grafana |
| ai-consolidation (207) | Migration completeness | 8 stale artifacts still point to localhost:3002/MacBook paths |
| automation-stack (202) | Registry coverage | Service registry + health probes were missing at audit time; now addressed in spine SSOT/bindings |

---

## Phases

| Phase | Scope | Status |
|-------|-------|--------|
| P0 | **Critical fixes** — archive monitoring compose, refresh CONTAINER_INVENTORY, fix RAG script defaults, register automation services | DONE (workbench commits + spine MT-4 already present) |
| P1 | **Governance sync** — deprecate RAG legacy docs, update INFRASTRUCTURE_MAP, archive stale workbench compose/configs, fix SECRET_ROTATION SSH target | DONE |
| P2 | **Completeness** — Prometheus multi-host scraping, monitoring_inventory.json, node-exporter registry, automation staged compose, CRON_REGISTRY clarification | OPEN (MT-9 is spine/host-side) |
| P3 | **Verify + closeout** — spine.verify, services.health.status, workbench parity check | READY once MT-9 complete |

---

## P0 Tasks (Critical — Do Today)

### MT-1: Archive docker-compose.monitoring.yml
- **Why:** Deploying docker-host via this file creates duplicate Prometheus/Grafana conflicting with VM 205
- **File:** `workbench/infra/compose/mint-os/docker-compose.monitoring.yml`
- **Action:** Move to `workbench/.archive/compose-legacy/`. Remove from STACK_REGISTRY.yaml mint-os `compose_files` array.
- **SSOT update:** `agentic-spine/docs/governance/STACK_REGISTRY.yaml` line ~42

### MT-2: Refresh CONTAINER_INVENTORY.md snapshot
- **Why:** Shows AnythingLLM+Qdrant running on MacBook (stopped since AI consolidation)
- **File:** `workbench/docs/infrastructure/CONTAINER_INVENTORY.md`
- **Action:** Update MacBook section (containers stopped). Add VM 207 ai-consolidation section. Update snapshot date.
- **Also update:** `workbench/infra/data/CONTAINER_INVENTORY.yaml`

### MT-3: Fix RAG script URL defaults
- **Why:** Falls back to localhost:3002 which no longer exists after MacBook→VM 207 migration
- **Files:**
  - `workbench/scripts/root/rag/index.sh` (line ~14)
  - `workbench/scripts/root/rag/health-check.sh` (line ~6)
- **Action:** Change `http://localhost:3002` to `http://100.71.17.29:3002`

### MT-4: Register automation-stack companion services
- **Why:** postgres, redis, ollama, open-webui running on VM 202 but invisible to governance
- **Files:**
  - `agentic-spine/docs/governance/SERVICE_REGISTRY.yaml` — add 4 service entries
  - `agentic-spine/ops/bindings/services.health.yaml` — add health probes
- **Action:** Register postgres (5432), redis (6379), ollama (11434), open-webui (3000) under automation-stack host

---

## P1 Tasks (High — This Week)

### MT-5: Deprecate workbench RAG governance docs
- **Files:**
  - `workbench/docs/legacy/infrastructure/reference/rag/ANYTHINGLLM_GOVERNANCE.md`
  - `workbench/docs/legacy/infrastructure/reference/rag/RAG_SYNC_GOVERNANCE.md`
  - `workbench/docs/legacy/infrastructure/reference/rag/REINDEX_POLICY.md`
- **Action:** Add DEPRECATED header, redirect to spine loop closeout + staged compose

### MT-6: Update INFRASTRUCTURE_MAP.md RAG section
- **File:** `agentic-spine/docs/governance/INFRASTRUCTURE_MAP.md`
- **Action:** Change localhost:3002 → 100.71.17.29:3002, /Users/ronnyworks/anythingllm_storage → /opt/stacks/ai-consolidation/anythingllm_storage

### MT-7: Archive workbench pihole compose
- **File:** `workbench/infra/compose/pihole/docker-compose.yml`
- **Action:** Move to `.archive/compose-legacy/`. Has FTLCONF_LOCAL_IPV4=192.168.12.191 (docker-host, not infra-core)

### MT-8: Archive or sync workbench SERVICE_REGISTRY.yaml
- **File:** `workbench/infra/data/SERVICE_REGISTRY.yaml`
- **Action:** Either archive entirely (spine is SSOT) or sync from spine SERVICE_REGISTRY.yaml

### MT-9: Add Prometheus multi-host scrape targets
- **File:** VM 205 `/opt/stacks/prometheus/prometheus.yml`
- **Action:** Add download-stack (100.107.36.76:9100) and streaming-stack (100.123.207.64:9100) node-exporter targets

### MT-10: Fix SECRET_ROTATION.md SSH target
- **File:** `workbench/docs/legacy/infrastructure/reference/SECRET_ROTATION.md` (or wherever n8n restart is referenced)
- **Action:** Change `ssh docker-host` to `ssh automation-stack` for n8n restart commands

---

## P2 Tasks (Medium — This Sprint)

### MT-11: Mark monitoring_inventory.json historical
### MT-12: Clarify node-exporter multi-host intent in SERVICE_REGISTRY
### MT-13: Create automation-stack staged compose directory (ops/staged/)
### MT-14: Archive REF_PIHOLE.md
### MT-15: Archive 2026-01-01 holistic audit
### MT-16: Document mailroom ↔ n8n non-coupling
### MT-17: Reconcile CRON_REGISTRY with n8n workflows
### MT-18: Sunset legacy-agents archive scripts
### MT-19: Sync workbench SERVICE_REGISTRY.md pointer doc

---

## Evidence

- Audit report: `agentic-spine-audit-2026-02-08.docx` (in workspace root)
- Subagent audits: 4 parallel agents (infracore, observability, ai-services, automation)
- Spine authority files read: SERVICE_REGISTRY.yaml, STACK_REGISTRY.yaml, services.health.yaml, docker.compose.targets.yaml, infra.relocation.plan.yaml, infra.vm.profiles.yaml
- Workbench files audited: CONTAINER_INVENTORY.md, SERVICE_REGISTRY.md, all compose dirs, legacy docs, RAG scripts

---

## Success Criteria

| Criteria | Validation |
|----------|------------|
| All P0 tasks complete | Zero stale CONTAINER_INVENTORY, zero broken RAG scripts, zero duplicate monitoring risk |
| All P1 tasks complete | Workbench RAG docs deprecated, INFRASTRUCTURE_MAP current, SECRET_ROTATION fixed |
| spine.verify passes | 47/47 drift gates (or more if new gates added) |
| services.health.status passes | All registered services healthy |
| Workbench parity check | No remaining localhost:3002 or macbook references for migrated services |

---

## Non-Goals

- Do NOT migrate any running services (migration is complete)
- Do NOT change spine governance structure (it's correct)
- Do NOT restructure workbench directory layout (just update/archive individual files)

---

_Scope document created by: Opus 4.6 (Cowork subagent audit)_
_Created: 2026-02-08_

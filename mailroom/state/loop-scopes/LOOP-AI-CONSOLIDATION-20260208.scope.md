# LOOP-AI-CONSOLIDATION-20260208

> **Status:** ACTIVE
> **Owner:** @ronny
> **Created:** 2026-02-08
> **Severity:** medium

---

## Executive Summary

Consolidate scattered AI services onto a dedicated VM 207 on pve (shop R730XD). Qdrant and AnythingLLM currently run on the MacBook; Open WebUI runs on VM 202. This loop migrates them to a purpose-built VM with adequate CPU and RAM, while deliberately keeping Ollama on VM 202 due to its tight n8n integration.

---

## Placement Decisions (Locked In)

### Ollama: Stays on VM 202

| Factor | Decision |
|--------|----------|
| **Choice** | Keep Ollama on VM 202 (ai-services) |
| **Rationale** | Tight integration with n8n workflows, low-latency local inference, GPU passthrough already configured |

### VM 207 Resource Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| CPU | 8 vCPU | 8+ vCPU |
| RAM | 16 GB | 32 GB |
| Disk | 100 GB | 200 GB (vector DB growth) |
| GPU | None initially | Possible later (PCIe passthrough) |

---

## Target Architecture

### VM 207: ai-consolidation (shop R730XD)

| Service | Port | Purpose | Current Location | Status |
|---------|------|---------|-----------------|--------|
| Qdrant | 6333 (HTTP), 6334 (gRPC) | Vector database | MacBook | This loop |
| AnythingLLM | 3002 | RAG + chat interface | MacBook | This loop |
| Open WebUI | 3000 | LLM chat frontend | VM 202 | Evaluate in P4 |

### What Stays on VM 202 (ai-services)

| Service | Port | Reason |
|---------|------|--------|
| Ollama | 11434 | Tight n8n integration |
| n8n | 5678 | Workflow engine |

---

## Phases

| Phase | Scope | Dependency | Status |
|-------|-------|------------|--------|
| P0 | Evaluate RAM/GPU requirements for Qdrant + AnythingLLM | — | **COMPLETE** |
| P1 | Provision + bootstrap VM 207 to profile-ready (8 vCPU, 32GB RAM) | P0 | **COMPLETE** |
| P2 | Deploy Qdrant on VM 207 | P1 | **READY** |
| P3 | Deploy AnythingLLM on VM 207 | P2 | **READY** |
| P4 | Evaluate Open WebUI placement (move to 207 or keep on 202) | P3 | **COMPLETE** (Keep on VM 202) |
| P5 | Split Infisical projects (separate secrets for 202 vs 207) | P4 | **READY** |
| P6 | Verify + closeout | P5 | **READY** |

## Unblocked (2026-02-08)

VM 207 was not actually reachable at `192.168.12.207` (VMID is not an IP). Proxmox DHCP assigned `192.168.12.114` initially; after bootstrap, Tailscale is connected and the canonical SSH target is now `ubuntu@100.71.17.29`.

Evidence (receipts):
- `infra.vm.bootstrap`: `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260208-115107__infra.vm.bootstrap__Rl0f28410/receipt.md`
- `infra.vm.ready.status`: `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260208-115316__infra.vm.ready.status__R4cy810329/receipt.md`

---

## Migration Notes

### Qdrant (P2)

- Current: Docker on MacBook, data in local volume
- Migration: Export snapshots via Qdrant API, restore on VM 207
- Collections to migrate: inventory of collections TBD during P0
- **Risk:** Large vector collections may take significant transfer time

### AnythingLLM (P3)

- Current: Docker on MacBook
- Migration: Export workspace configs + document store
- Qdrant connection string must update to `localhost:6333` (co-located on 207)
- Ollama connection must update to `http://<vm202-tailscale-ip>:11434`

### Open WebUI (P4 — Evaluation)

- Currently on VM 202 alongside Ollama
- **Move if:** Open WebUI does not heavily depend on Ollama localhost latency
- **Keep if:** Latency-sensitive model switching benefits from co-location
- Decision deferred to P4 evaluation

---

## Infisical Project Split (P5)

Current `ai-services` Infisical project covers all AI workloads. After consolidation:

| Project | Scope | VM |
|---------|-------|----|
| ai-services | Ollama, n8n, (maybe Open WebUI) | 202 |
| ai-consolidation | Qdrant, AnythingLLM, (maybe Open WebUI) | 207 |

---

## Secrets Required

| Secret | Project | Notes |
|--------|---------|-------|
| QDRANT_API_KEY | ai-consolidation | API authentication |
| ANYTHINGLLM_AUTH_TOKEN | ai-consolidation | Admin access token |
| OLLAMA_BASE_URL | ai-consolidation | Remote Ollama endpoint on VM 202 |

---

## Success Criteria

| Criteria | Validation |
|----------|------------|
| VM 207 provisioned and spine-ready | SSH reachable, Tailscale joined |
| Qdrant healthy on VM 207 | `/collections` returns existing collections |
| AnythingLLM functional | Chat works with Qdrant + remote Ollama |
| Open WebUI placement decided | Documented decision with rationale |
| Infisical projects split | Each VM pulls only its own secrets |
| MacBook AI services stopped | No Qdrant/AnythingLLM containers on MacBook |

---

## Non-Goals

- Do NOT move Ollama off VM 202
- Do NOT set up GPU passthrough in this loop (future consideration)
- Do NOT consolidate n8n (stays on 202)
- Do NOT migrate model weights (Ollama manages its own)

---

## Practical Dependency Note

No hard blocker, but practical dependency on LOOP-DEV-TOOLS-DEPLOY-20260208 for CI integration if AnythingLLM or Qdrant configs need CI pipelines. Can proceed independently.

---

## Evidence

- Memory: Qdrant and AnythingLLM currently on MacBook
- Memory: Open WebUI on VM 202
- Memory: Ollama stays on VM 202 (tight n8n integration)
- DEVICE_IDENTITY_SSOT for VM 202 configuration

---

_Scope document created by: Opus 4.6_
_Created: 2026-02-08_

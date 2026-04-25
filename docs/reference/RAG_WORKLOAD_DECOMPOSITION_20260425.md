---
status: authoritative
owner: "@ronny"
type: derived-conclusion-note
loop: LOOP-RAG-WORKLOAD-DECOMPOSITION-20260425
wave: WAVE-20260425-11
origin: OI-20260425-125601-4859
scope: design-only
last_verified: "2026-04-25"
---

# RAG Workload Decomposition — Design Note

## Origin

OI-20260425-125601-4859 was auto-metabolized with:
- classification: `bind_adjacent_to_existing_seam`
- disposition: `deferred`
- concern_class: `domain_workload`

It was correctly held because no named seam existed for RAG infra pressure.
This note names the seam.

## Plain-Language Restatement

The RAG pipeline is a composite workload running across two hosts with six
distinct resource-pressure planes. Today it works but has no governed
decomposition — the workload is treated as one opaque blob ("the RAG stack").
This makes it impossible to reason about placement, scaling, or failure modes
per plane. The concern is: what are the real workload planes, what pressure
does each create, and which existing spine/infra seams do they touch?

## Workload Plane Decomposition

### 1. Ingestion (Document Sync)

- **What it is**: rsync of eligible repo documents from laptop/repo to the
  runner host, followed by upload into AnythingLLM's document store. Governed
  by `rag.workspace.contract.yaml` index and sync policies.
- **Resource pressure**: disk I/O on runner host (ai-consolidation), network
  transfer from repo source, AnythingLLM API load during upload. Pacing
  governed by `sync_policy.load_shaping` (inter-doc pause, per-request
  timeout, exponential backoff).
- **Adjacent seam**: `rag.remote.runner` binding (SSH runner on
  ai-consolidation, tmux session). Touches the execution-host workload
  contract (7 workloads already on ai-consolidation per
  `project_execution-host-activation-state-20260413`).
- **In-scope now or future**: exists and operates. No design gap — this plane
  is governed.

### 2. Embedding (Vector Generation)

- **What it is**: for each ingested document chunk, AnythingLLM sends text to
  Ollama (`mxbai-embed-large:latest`, 1024 dimensions) and receives a vector.
  Governed by `rag.embedding.backend.yaml`.
- **Resource pressure**: GPU/CPU on automation-stack (VM 202, Ollama host).
  This is the heaviest compute plane in the pipeline. Embedding competes with
  any LLM inference also running on Ollama. Latency SLO: 5000ms per embedding
  (probe contract). Network: ai-consolidation → automation-stack cross-host
  calls per chunk.
- **Adjacent seam**: Ollama is a shared inference service on automation-stack.
  Any future model-serving capacity planning touches this plane. The
  `services.health.yaml` ollama entry governs liveness but not capacity.
- **In-scope now or future**: exists and operates but has no capacity
  isolation. Cross-host embedding latency is the primary bottleneck during
  reindex. **Future work** — capacity/isolation boundary if Ollama load
  becomes contested.

### 3. Vector Storage (Qdrant)

- **What it is**: Qdrant stores and indexes embedding vectors. Runs as a
  container on ai-consolidation (port 6333). Accepts vectors from AnythingLLM
  after embedding.
- **Resource pressure**: memory (vector index lives in RAM), disk (WAL +
  snapshots), CPU during index rebuild. Current corpus is small (~100-230
  docs). Pressure is low at current scale.
- **Adjacent seam**: ai-consolidation container workload budget. Qdrant shares
  the host with AnythingLLM and 5 other spine workloads. Storage placement
  governed by `infra.storage.placement.policy.yaml`.
- **In-scope now or future**: exists, operates, low pressure at current scale.
  No design gap. **Future work** only if corpus grows significantly or
  multi-tenant RAG is needed.

### 4. Lexical / Filter Search

- **What it is**: AnythingLLM's retrieval path includes metadata filtering and
  optional keyword search alongside vector similarity. This is internal to
  AnythingLLM — not a separate service.
- **Resource pressure**: negligible at current scale. AnythingLLM CPU/memory
  during query time. Bounded by query volume (agent sessions, MCP calls).
- **Adjacent seam**: AnythingLLM container resource limits on ai-consolidation.
  Same host budget as Qdrant.
- **In-scope now or future**: exists inside AnythingLLM. No separate plane
  needed. No design gap.

### 5. Reranking

- **What it is**: post-retrieval reranking of candidate chunks before context
  assembly. AnythingLLM may apply its own relevance scoring. No external
  reranker service is deployed.
- **Resource pressure**: minimal — runs inside AnythingLLM at query time. If a
  dedicated reranker model were added (e.g., cross-encoder), it would create a
  new compute plane similar to embedding.
- **Adjacent seam**: none today. Would touch the Ollama/model-serving seam if a
  reranker model is introduced.
- **In-scope now or future**: **future work** only if retrieval quality demands
  a dedicated reranker. Not active today.

### 6. Generation (LLM Response)

- **What it is**: after retrieval, the assembled context + query goes to an LLM
  for response generation. This is NOT part of the RAG pipeline's infra
  footprint — it happens at the calling agent's inference layer (Claude API,
  Ollama chat, etc.).
- **Resource pressure**: external to the RAG stack. If Ollama chat models are
  used, it competes on automation-stack GPU/CPU with embeddings.
- **Adjacent seam**: model-serving capacity on automation-stack (shared Ollama).
  Claude API calls are external and have no local infra pressure.
- **In-scope now or future**: **out of scope** for RAG infra. Generation is an
  agent-layer concern, not a RAG-pipeline concern.

## The Real Seam

The seam is **shared model-serving capacity on automation-stack**. Embedding
and inference share Ollama on VM 202 with no isolation or prioritization.
During reindex, embedding saturates the model server, which could starve
concurrent inference. This is the only plane where RAG workload pressure
crosses into another domain's resource budget.

Secondary seam: **ai-consolidation container density**. AnythingLLM + Qdrant
colocate with 5 other spine workloads. At current scale this is fine, but the
host has no governed workload budget ceiling.

## Explicitly Out of Scope

- Host assignment or placement changes (guardrail)
- Hardware procurement or GPU provisioning
- Implementation of capacity isolation, rate limiting, or QoS
- New governance surfaces or doctrine
- Node topology changes
- L3 domain extraction for RAG
- Multi-tenant RAG or workspace proliferation
- Reranker model deployment
- AnythingLLM version upgrades or migration

## Valid Future Loop Names

If Ronny chooses to continue past this design note:

1. **LOOP-RAG-EMBEDDING-CAPACITY-ISOLATION** — Govern Ollama capacity split
   between embedding and inference on automation-stack. Narrow: priority,
   queuing, or time-slicing. NOT host migration.
2. **LOOP-RAG-WORKLOAD-BUDGET-AICONSOLIDATION** — Establish container resource
   ceilings for AnythingLLM + Qdrant within the ai-consolidation workload
   budget. Adjacent to the existing 7-workload inventory.
3. **LOOP-RAG-REINDEX-OBSERVABILITY** — Wire reindex telemetry (progress,
   latency, failure rate) into existing observability stack
   (Prometheus/Grafana on observability host). Narrow read-only addition.

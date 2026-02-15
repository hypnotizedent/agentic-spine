---
loop_id: LOOP-RAG-REINDEX-EXECUTION-20260215
created: 2026-02-15
status: active
owner: "@ronny"
scope: agentic-spine
objective: Execute RAG full reindex with checkpoint/resume, validate parity, run smoke queries, record attestation
---

# Loop Scope: RAG Reindex Execution

## Problem Statement

RAG workspace has stale/inflated document count (406 indexed vs 104 eligible).
Reindex sessions timeout on Ollama embedding endpoint (65 HTTP 000 failures in last run).
D90 gate now enforces runtime quality contract, but the actual reindex has not completed successfully.

## Inherited Context

- Spun out of LOOP-SPINE-CANONICAL-UPGRADE-20260210 (P2 blocked)
- GAP-OP-308 re-parented here from canonical upgrade loop
- D89 (quality contract lock) and D90 (runtime quality gate) already in place
- RAG_REINDEX_RUNBOOK.md documents the procedure

## Deliverables

1. Successful chunked reindex with checkpoint/resume (no timeout storm)
2. Parity validation: indexed docs match eligible docs
3. Smoke queries: 2+ governance queries return correct sources
4. Attestation document committed to repo
5. D90 gate passes with session STOPPED + quality OK

## Acceptance Criteria

- `rag.reindex.remote.verify` reports quality OK
- `rag.anythingllm.status` shows parity (indexed ~ eligible, no inflation)
- Smoke query: "how do I file a gap?" returns actionable answer with sources
- Smoke query: "what does D65 enforce?" returns correct answer
- Attestation committed with evidence

## Constraints

- Use RAG_REINDEX_RUNBOOK.md procedure
- Chunked sync with checkpoint/resume (not bulk)
- Monitor Ollama embedding latency before starting
- Scope: agentic-spine + VM 207 (ai-consolidation)

## Gaps

- GAP-OP-308: RAG full reindex deferred (re-parented from canonical upgrade)

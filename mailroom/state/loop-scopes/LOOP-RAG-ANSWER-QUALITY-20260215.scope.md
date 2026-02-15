---
status: closed
owner: "@ronny"
last_verified: 2026-02-15
scope: loop-scope
loop_id: LOOP-RAG-ANSWER-QUALITY-20260215
---

# Loop Scope: RAG Answer Quality

## Goal
Stabilize RAG answer quality for bridge consumers: wire auto mode (chat + fallback),
clean retrieval output noise (metadata/hotdir artifacts), define output contract.

## Child Gaps

| Gap ID | Description | Status |
|--------|-------------|--------|
| GAP-OP-367 | RAG chat path timeout; /rag/ask degrades to raw retrieval | fixed (791967e) |
| GAP-OP-368 | RAG index quality drift/noise (metadata + hotdir artifacts) | fixed (791967e) |
| GAP-OP-369 | RAG answer contract lacks clean-output requirements | fixed (791967e) |

## Changes

- Bridge `/rag/ask`: accepts `mode` param (auto/chat/retrieve), defaults to `auto`
- RAG CLI retrieve: strips `<document_metadata>` tags, normalizes `file:///app/collector/hotdir/` paths
- Bridge response: source normalization (dedup, prefix strip), metadata tag removal, `mode` field
- MAILROOM_BRIDGE.md: documents `/cap/run` and `/rag/ask` output contract
- 7 new tests in `test-rag-output-contract.sh`

## Evidence Baseline
- rag.health: OK (all services responding)
- reindex.remote.status: STOPPED, 281 uploaded, 0 failed
- reindex.remote.verify: FAIL (parity 0.94 — 95 indexed, 101 eligible, 6 docs behind)

## Deferred / Follow-ups
- Index parity gap (6 docs missing): requires remote reindex on VM207
- Chat timeout reliability: depends on Ollama/AnythingLLM performance tuning
- MCP server could also pass `--mode auto` for `rag_query` tool

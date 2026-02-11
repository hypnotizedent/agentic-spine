---
status: closed
owner: "@ronny"
last_verified: 2026-02-10
scope: loop-scope
loop_id: LOOP-RAG-ASK-UNBLOCK-20260210
---

# Loop Scope: LOOP-RAG-ASK-UNBLOCK-20260210

## Goal
Make `rag.anythingllm.ask` complete reliably end-to-end for the shop RAG stack.
If AnythingLLM chat remains slow/unreliable, `ask` must fall back to a
retrieval-only search (Qdrant vector search) and still return a useful result.

## Success Criteria
- `rag.health` passes (AnythingLLM + Qdrant + Ollama reachable).
- `rag.anythingllm.ask "<question>"` exits `0` and returns either:
  - an AnythingLLM chat answer, or
  - a retrieval-only search result set (fallback).
- `spine.verify` PASS after changes.

## Phases
- P0: Verify endpoints (AnythingLLM ping, Qdrant healthz, Ollama tags).
- P1: Implement retrieval-only subcommand (Ollama embeddings + Qdrant search).
- P2: Wire `ask` fallback to retrieval-only when chat is slow/unavailable.
- P3: Prove with receipts + close loop.

## Receipts
- `receipts/sessions/RCAP-20260210-105439__rag.health__Rbcaf5908/receipt.md`
- `receipts/sessions/RCAP-20260210-105443__rag.anythingllm.ask__Rci616013/receipt.md` (chat timeout -> retrieval fallback)
- `receipts/sessions/RCAP-20260210-105541__spine.verify__R20co10565/receipt.md`

## Deferred / Follow-ups
- If AnythingLLM chat is required again, do a separate loop to diagnose why
  `/api/v1/workspace/<slug>/chat` is timing out (model choice, backlog, or VM
  resource constraints). This loop intentionally only guarantees bounded-time
  retrieval for `ask`.

---
status: closed
owner: "@ronny"
created: 2026-02-11
closed: 2026-02-12
---

# LOOP-RAG-INDEX-PARITY-20260211

> **Status:** closed (deferred — baseline captured, no phases executed)
> **Owner:** @ronny
> **Created:** 2026-02-11
> **Closed:** 2026-02-12
> **Severity:** high

---

## Executive Summary

Eliminate RAG index drift between eligible canonical docs (82) and actually indexed
docs in AnythingLLM (34). Patch `rag status` to surface parity as a first-class
metric so future drift is immediately visible. Produce attestation with receipts.

---

## Phases

| # | Phase | Status |
|---|-------|--------|
| 1 | Run `rag.anythingllm.sync` to upload all eligible docs | deferred |
| 2 | Patch `rag status` to show eligible + parity line | deferred |
| 3 | Create attestation doc with before/after evidence | deferred |
| 4 | Final verify (rag.health + rag.status + spine.verify) | deferred |

---

## Baseline (before)

- `rag.health`: OK (AnythingLLM, Qdrant, Ollama all reachable)
- `rag.anythingllm.status`: docs_indexed=34
- `build_manifest()`: eligible=82
- `spine.verify`: PASS (D1-D71)
- Delta: **48 docs not indexed**

---

## Closure Note

Closed without execution to normalize loop count. All phases remain deferred.
Baseline is valid — re-open as a new loop when RAG parity becomes a priority.
The 48-doc delta is non-blocking (RAG is advisory, not enforcement).

---

## Done Criteria

- `rag.health` all OK
- `rag.anythingllm.status` shows canonical parity (or enforced threshold)
- `spine.verify` PASS
- Attestation doc committed

---
loop_id: LOOP-RUNTIME-DRIFT-CLOSEOUT-20260215
created: 2026-02-15
status: active
owner: "@ronny"
scope: agentic-spine
objective: Close remaining runtime drift — RAG verify count path, RAG parity, RAG chat timeout, mailroom bridge tree hygiene
---

# Loop Scope: Runtime Drift Closeout

## Problem Statement

Governance plane is fully sealed (91/91 gates, 0 open gaps, 0 open loops), but runtime reliability
has 4 residual drifts preventing "predictable outcomes" status:
1. `rag.reindex.remote.verify` warns/skips index count check (indexed=0, eligible=0)
2. RAG parity drift: 97 indexed vs 108 eligible (11 AOF docs missing from index)
3. RAG chat path times out (45s curl), falls back to retrieval-only
4. Mailroom bridge files dirty in working tree + `__pycache__/` untracked

## Deliverables

1. **Lane D** — Fix `rag-reindex-remote-verify` count retrieval to fail (not warn) on indeterminate counts
2. **Lane E** — Restore RAG parity via governed reindex
3. **Lane F** — Stabilize RAG chat timeout path
4. **Lane G** — Clean mailroom bridge tree state

## Child Gaps

| Gap ID | Description | Lane |
|--------|-------------|------|
| GAP-OP-329 | rag.reindex.remote.verify count check warns/skips | D |
| GAP-OP-330 | RAG parity drift after AOF docs | E |
| GAP-OP-331 | RAG chat timeout / fallback instability | F |
| GAP-OP-332 | Mailroom bridge tree hygiene | G |

## Acceptance Criteria

- `rag.reindex.remote.verify` PASS with no count warning
- `rag.anythingllm.status` parity OK
- `rag.anythingllm.ask` answers without chat-timeout fallback
- `git status` clean
- `spine.verify` PASS

## Constraints

- Governed flow only (gaps.file/claim/close, receipts, verify)
- No destructive shortcuts outside governed capabilities
- Keep changes scoped to the 4 items

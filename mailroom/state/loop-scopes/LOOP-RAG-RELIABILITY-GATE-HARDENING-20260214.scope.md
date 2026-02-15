---
loop_id: LOOP-RAG-RELIABILITY-GATE-HARDENING-20260214
created: 2026-02-14
closed: 2026-02-15
status: closed
scope: agentic-spine
objective: Fix false-green behavior where rag.health + parity can pass while reindex is timing out/failing
---

# Loop Scope: RAG Reliability Gate Hardening

## Problem Statement

Current controls show "green" while reindex quality is failing:
- `rag.health` passes (AnythingLLM/Qdrant/Ollama reachable)
- `rag.anythingllm.status` reports `parity: OK` because `docs_indexed >= docs_eligible`
- `rag.reindex.remote.status` shows HTTP 000 timeouts, 65 failures, 0 uploads

**Root Issue:** No gate/enforcement for reindex completion quality (timeout storm / stale checkpoint / inflated indexed count).

## Deliverables

1. **rag.reindex.remote.verify** capability - validates reindex completion quality
2. **rag.remote.dependency.probe** capability - checks VM207 dependencies
3. **Binding contracts** for quality thresholds
4. **D89/D90 drift gates** - enforce quality contracts
5. **Tests** for new gates
6. **Updated docs** (RAG_REINDEX_RUNBOOK, VERIFY_SURFACE_INDEX, SSOT_REGISTRY)

## Evidence Paths

- Remote log: `/home/ubuntu/code/agentic-spine/mailroom/logs/rag-sync.log`
- Checkpoint: `/home/ubuntu/code/agentic-spine/mailroom/state/rag-sync/checkpoint.txt`

## Constraints

- Scope: agentic-spine only (no workbench edits)
- Follow spine governance: register gaps before fixing

## Completion Receipt

- **Closed:** 2026-02-15
- **Final SHA:** 919fb14
- **Gates added:** D90 (rag-reindex-runtime-quality-gate)
- **Gate total:** 90/90 PASS
- **Gaps filed:** GAP-OP-316 through GAP-OP-320 (all fixed)
- **Remaining:** GAP-OP-308 (RAG full reindex deferred, tracked under LOOP-SPINE-CANONICAL-UPGRADE-20260210)
- **Run key:** CAP-20260215-074716__spine.verify__R5bnq4929

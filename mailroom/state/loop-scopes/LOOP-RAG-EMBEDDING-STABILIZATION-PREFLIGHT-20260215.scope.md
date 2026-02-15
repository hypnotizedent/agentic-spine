---
status: open
owner: "@ronny"
last_verified: 2026-02-15
scope: loop-scope
loop_id: LOOP-RAG-EMBEDDING-STABILIZATION-PREFLIGHT-20260215
---

# Loop Scope: RAG Embedding Stabilization Preflight

## Goal
Stabilize RAG embedding reliability before authorizing a full reindex.
Add backend selection contract, load-shaping knobs, and short-batch smoke
capability + gate so that a full reindex (GAP-OP-370) cannot run without
passing a deterministic preflight.

## Hard Constraints
- Do NOT run a full reindex in this loop.
- Keep GAP-OP-370 (runtime recovery), GAP-OP-385 (verifier semantics),
  GAP-OP-393 (infra/perf) open and separate.

## Deliverables
1. Embedding backend selection contract + capability flag
2. Sync load-shaping knobs (pace/retry/backoff/timeout)
3. Short-batch smoke capability + drift gate (D111)

## Acceptance Criteria
- Repeated embedding probes pass under defined threshold
- Short-batch completes with failed=0, clean checkpoint behavior
- Only then authorize full reindex loop continuation for GAP-OP-370

## Child Gaps

| Gap ID | Description | Status |
|--------|-------------|--------|
| GAP-OP-412 | Embedding backend selection contract missing — no explicit primary/fallback/probe binding | open |
| GAP-OP-413 | Sync load-shaping knobs missing — no governed per-request timeout/retry/backoff/pace controls | open |
| GAP-OP-414 | Short-batch smoke preflight missing — no small-N smoke capability or gate before full reindex | open |

## Related Gaps (not closed in this loop)
- GAP-OP-370: RAG runtime recovery track (full reindex)
- GAP-OP-385: Verifier semantics track
- GAP-OP-393: Infra/perf track

## Changes
(filled on closure)

## Evidence Baseline
(filled during acceptance)

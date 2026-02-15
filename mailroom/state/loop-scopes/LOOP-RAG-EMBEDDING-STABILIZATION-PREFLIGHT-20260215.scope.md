---
status: closed
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
| GAP-OP-412 | Embedding backend selection contract | fixed (1faaac6) |
| GAP-OP-413 | Sync load-shaping knobs | fixed (1faaac6) |
| GAP-OP-414 | Short-batch smoke preflight + D111 gate | fixed (1faaac6, db07c2b) |

## Related Gaps (not closed in this loop)
- GAP-OP-370: RAG runtime recovery track (full reindex) — OPEN
- GAP-OP-385: Verifier semantics track — OPEN
- GAP-OP-393: Infra/perf track — was fixed prior to this loop

## Changes

### Phase 1 — Backend selection contract
- `ops/bindings/rag.embedding.backend.yaml`: primary/fallback/probe/threshold binding
- `ops/plugins/rag/bin/rag-embedding-probe`: repeated probes with dim/latency/HTTP checks
- `rag.embedding.probe` capability registered (read-only)

### Phase 2 — Load-shaping knobs
- `ops/bindings/rag.workspace.contract.yaml`: sync_policy.load_shaping section
  (inter_doc_pace_sec, per_request_timeout_sec, max_retries, backoff_strategy, retry_base/max_delay)
- `ops/plugins/rag/bin/rag`: resolve_load_shaping + compute_retry_delay + inter-doc pacing
- `ops/plugins/rag/tests/rag-load-shaping-test.sh`: 11 tests

### Phase 3 — Short-batch smoke + D111 gate
- `ops/plugins/rag/bin/rag-reindex-smoke`: small-N remote smoke
- `rag.reindex.smoke` capability (mutating, manual approval)
- `surfaces/verify/d111-rag-embedding-smoke-preflight.sh`: evidence freshness gate
- D105-D111 wired into drift-gate.sh
- Gate registry: 111 total (110 active, 1 retired)

## Evidence Baseline

### Embedding Probes (3/3 PASS)
- Probe 1: HTTP 200, dim=1024, 1262ms
- Probe 2: HTTP 200, dim=1024, 1417ms
- Probe 3: HTTP 200, dim=1024, 1278ms
- Threshold: max_latency_ms=5000, expected_dimensions=1024
- Run key: CAP-20260215-140808__rag.embedding.probe__Ra2w099213

### Short-Batch Smoke (PASS)
- batch_size: 5, attempted: 4, uploaded: 4, failed: 0
- duration_sec: 366, checkpoint: has_6_lines (pre-existing)
- Run key: CAP-20260215-141040__rag.reindex.smoke__Rzwkv4289

### Load-Shaping Tests (11/11 PASS)

### spine.verify
- D111 PASS, D85 PASS
- D90 FAIL (pre-existing, GAP-OP-370 domain)
- D107-D109 FAIL (media stack SSH access, other terminal's domain)
- Run key: CAP-20260215-141711__spine.verify__Rjuoa49563

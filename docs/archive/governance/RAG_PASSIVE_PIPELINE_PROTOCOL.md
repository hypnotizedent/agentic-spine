---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-28
scope: rag-pipeline-lifecycle
---

# RAG Passive Pipeline Protocol

> Purpose: define a single governed lifecycle for RAG indexing so status is
> deterministic, parity decisions are consistent, and closure is automatic when
> quality gates pass.

## Objectives

1. Normalize RAG metrics into one contract surface.
2. Auto-trigger reindex only on eligible-document deltas.
3. Auto-closeout parity gaps once completion quality is proven.
4. Keep `d90` and `rag-reindex-remote-verify` parity decisions identical.

## Lifecycle

1. `idle`: no reindex in progress.
2. `queued`: eligible-doc delta detected and debounce window active.
3. `running`: remote sync session active.
4. `verifying`: sync session stopped, completion checks running.
5. `complete`: completion checks pass.
6. `failed`: completion checks fail (gap remains open or re-opened).

## Normalized Metrics Contract

Status consumers must read these fields only:

- `repo_docs`: markdown files under `docs/`, `ops/`, `surfaces/`.
- `path_filtered`: files after exclusion rules.
- `frontmatter_eligible`: filtered files with required frontmatter.
- `secrets_excluded`: files removed by secret-pattern filter.
- `rag_eligible`: `frontmatter_eligible - secrets_excluded`.
- `rag_indexed`: current workspace indexed document count.
- `parity_ratio`: `rag_indexed / rag_eligible`.
- `inflation_ratio`: `rag_indexed / rag_eligible` (same denominator, different threshold intent).
- `session_state`: `RUNNING | STOPPED`.
- `phase`: `idle | queued | running | verifying | complete | failed`.

## Auto-Trigger Rules

- Trigger source: eligible-doc change set (not any repo change).
- Debounce: wait configured quiet window before queueing reindex.
- If reindex already running, collapse new triggers into one queued follow-up.

## Auto-Closeout Rules

Close linked parity gap only when all are true:

1. Session is `STOPPED`.
2. `parity_ratio >= min_parity_ratio`.
3. `inflation_ratio <= max_index_inflation_ratio`.
4. Checkpoint is empty/absent.
5. Verification receipt exists.

If any check fails, keep gap open and emit failure receipt.

## `/rag/ask` Surface Contract

Bridge responses remain:

- `answer`
- `sources` (normalized, deduplicated)
- `mode` (final mode used: `chat` or `retrieve`)
- `receipt`
- `workspace`

`mode` and normalized `sources` are required for mobile/client predictability.

## Governance Touchpoints

- Quality thresholds: `ops/bindings/rag.reindex.quality.yaml`
- Pipeline behavior: `ops/bindings/rag.pipeline.contract.yaml`
- Metric field definitions: `ops/bindings/rag.metrics.normalization.yaml`
- Runtime gate: `surfaces/verify/d90-rag-reindex-runtime-quality-gate.sh`
- Runtime verifier: `ops/plugins/rag/bin/rag-reindex-remote-verify`

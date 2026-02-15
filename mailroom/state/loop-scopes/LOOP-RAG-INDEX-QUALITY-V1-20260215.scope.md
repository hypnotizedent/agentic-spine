# LOOP-RAG-INDEX-QUALITY-V1-20260215

**Status:** open
**Opened:** 2026-02-15
**Owner:** @ronny
**Terminal:** claude-code

## Objective

Reduce RAG index inflation ratio from 1.36 (141 indexed / 103 eligible) toward
<=1.15, then lock the tighter threshold in policy. This is a quality loop, not
recovery — all RAG infrastructure is healthy.

## Baseline (run keys)

- rag.remote.dependency.probe: CAP-20260215-170428__rag.remote.dependency.probe__Rvwgm52989
- rag.reindex.remote.verify: CAP-20260215-170433__rag.reindex.remote.verify__Rp0nf53128
- gaps.status: CAP-20260215-170438__gaps.status__R59x053512

## Gaps

| Gap | Type | Severity | Description |
|-----|------|----------|-------------|
| GAP-OP-468 | runtime-bug | high | Index cleanup/dedupe: identify and remove 38 stale/duplicate docs from AnythingLLM |
| GAP-OP-469 | runtime-bug | medium | Post-clean verify: short-batch + full verify evidence proving ratio <=1.15 |
| GAP-OP-470 | missing-entry | medium | Tighten threshold policy: update max_index_inflation_ratio from 1.5 to 1.15 |

## Exit Criteria

- [ ] inflation_ratio <= 1.15 after cleanup
- [ ] Short-batch + full verify evidence receipted
- [ ] rag.reindex.quality.yaml threshold updated to 1.15
- [ ] All drift gates PASS with new threshold

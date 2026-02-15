# LOOP-RAG-INDEX-QUALITY-V1-20260215

**Status:** closed
**Opened:** 2026-02-15
**Closed:** 2026-02-15
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

| Gap | Type | Severity | Description | Status |
|-----|------|----------|-------------|--------|
| GAP-OP-468 | runtime-bug | high | Index cleanup/dedupe: removed 46 duplicate docs from AnythingLLM (141→95) | closed |
| GAP-OP-469 | runtime-bug | medium | Post-clean verify: ratio 0.95 (98/103), all quality gates PASS | closed |
| GAP-OP-470 | missing-entry | medium | Tighten threshold: max_index_inflation_ratio 1.5→1.15 | closed |

## Exit Criteria

- [x] inflation_ratio <= 1.15 after cleanup (actual: 0.95)
- [x] Short-batch + full verify evidence receipted
- [x] rag.reindex.quality.yaml threshold updated to 1.15
- [x] All drift gates PASS with new threshold

## Closure Evidence

- Dedupe: 46 duplicates removed via AnythingLLM update-embeddings API
- Post-dedupe: 95 indexed / 103 eligible (ratio 0.92)
- Post-sync: 98 indexed / 103 eligible (ratio 0.95, parity 0.95)
- Verify run key: CAP-20260215-172402__rag.reindex.remote.verify__Rw13p40251
- Final verify run key: CAP-20260215-172402 (all gates PASS)
- Audit tooling: ops/plugins/rag/bin/rag-index-audit + rag-index-audit-report.py
- Commits: 2d9779c (audit tooling + skill update)

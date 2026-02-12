---
loop_id: LOOP-MINT-PROD-CUTOVER-EXECUTION-20260212
status: closed
closed: 2026-02-12
opened: 2026-02-12
owner: "@ronny"
scope: Execute first production cutover for mint-modules using promotion gate scripts
repos:
  - mint-modules (product — edits only if required)
  - agentic-spine (loop scope + receipts + closeout)
---

# LOOP: Mint Prod Cutover Execution

## Objective

Execute the first production cutover for mint-modules (artwork, order-intake,
quote-page) on docker-host (VM 200) using the promotion gate scripts. Immediate
rollback if any health gate fails.

## Phases

1. **P0 Baseline** — spine.verify, ops status, gaps.status, authority.project.status
2. **Parallel Prep** — validate env/tags, dry-run promote, staging smoke baseline
3. **Cutover** — real promotion, post-cutover smoke, health verification
4. **Rollback (if needed)** — immediate rollback + re-verify
5. **Final Recert** — spine verify + status + gaps
6. **Closeout** — close with exact command outputs and receipts

## Done Definition

- Production cutover succeeded OR rollback succeeded with services restored
- Post-cutover (or post-rollback) smoke passes
- No open loops/gaps introduced unexpectedly
- Loop scope closed with exact command outputs, receipts, final commit hashes

## Baseline Receipts

- spine.verify: CAP-20260212-011535__spine.verify__Rq3md83791 — PASS
- ops status: 0 loops, 0 gaps
- gaps.status: 0 open
- authority.project.status: GOVERNED

## Closeout

### Outcome

Production cutover **SUCCEEDED**. No rollback needed.

### Execution Summary

1. **Dry-run**: All preflight gates passed (typecheck, build, test for all 3 modules)
2. **Adaptation**: Docker Desktop not running locally — built images directly on remote host
3. **Migration**: Added `metadata` JSONB column to `artwork_seeds` table (non-breaking)
4. **Smoke fixes**: 3 bugs fixed in staging-integration-smoke.sh (field names, HTTP status, jq falsy)
5. **End-to-end verified**: intake → seed with metadata, has_line_item=true

### Post-Cutover State

- files-api: healthy (db=ok, minio=ok), image mint-modules/artwork:0ce4de6
- order-intake: healthy (artwork_api=ok), image mint-modules/order-intake:0ce4de6 (first deploy)
- quote-page: healthy (minio=ok, files_api=ok), image mint-modules/quote-page:0ce4de6
- Smoke: 6/6 passed (2 skipped — ORDER_INTAKE_API_KEY not set)

### Recert Receipts

- spine.verify: CAP-20260212-014128__spine.verify — ALL PASS
- gaps.status: CAP-20260212-014203__gaps.status — 0 open

### Final Commit Hashes

- mint-modules: `2ba09d2` (3 smoke script fixes during cutover)
- agentic-spine: (closeout commit below)

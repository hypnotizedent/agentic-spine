---
loop_id: LOOP-MINT-PROD-PROMOTION-GATE-20260212
status: closed
closed: 2026-02-12
opened: 2026-02-12
owner: "@ronny"
scope: Governed promotion gate from staged integration to production with explicit rollback
repos:
  - mint-modules (product changes)
  - agentic-spine (loop scope + receipts + closeout)
---

# LOOP: Mint Prod Promotion Gate

## Objective

Create a governed, repeatable promotion gate from staged integration to production
for mint-modules, with explicit rollback scripts and a production gate runbook.

## Phases

1. **P0 Baseline** — spine.verify, ops status, gaps.status, authority.project.status
2. **Worker D** — `deploy/docker-compose.prod.yml` + `deploy/PROMOTION_MANIFEST.md`
3. **Worker E** — `scripts/release/promote-to-prod.sh` + `scripts/release/rollback-prod.sh`
4. **Worker F** — `docs/READINESS/MINT_PROD_PROMOTION_GATE.md` production gate runbook
5. **Recert** — typecheck+build+test all 3 modules, spine verify+status+gaps
6. **Closeout** — Close loop with receipt IDs and final commit hashes

## Done Definition

- Prod compose + promotion manifest exist
- Promote + rollback scripts are executable and dry-run-safe
- Prod gate runbook complete
- All module tests/typecheck/build pass
- Spine ends at 0 loops / 0 gaps
- Loop closed with receipt IDs and final commit hashes

## Baseline Receipts

- spine.verify: CAP-20260212-010850__spine.verify__Raxxd64202 — PASS
- ops status: 0 loops, 0 gaps
- gaps.status: 0 open
- authority.project.status: GOVERNED (pass=7, warn=1, fail=0)

## Closeout

### Deliverables

| Artifact | Path | Status |
|----------|------|--------|
| Prod compose | `deploy/docker-compose.prod.yml` | Created |
| Promotion manifest | `deploy/PROMOTION_MANIFEST.md` | Created |
| Prod env template | `deploy/.env.prod.example` | Created |
| Promote script | `scripts/release/promote-to-prod.sh` | Created (executable) |
| Rollback script | `scripts/release/rollback-prod.sh` | Created (executable) |
| Prod gate runbook | `docs/READINESS/MINT_PROD_PROMOTION_GATE.md` | Created |
| Gitignore update | `.gitignore` (+`.env.prod`) | Updated |

### Recert Results

- artwork: typecheck PASS, build PASS, 95/95 tests PASS
- quote-page: typecheck PASS, build PASS, 51/51 tests PASS
- order-intake: typecheck PASS, build PASS, 113/113 tests PASS
- spine.verify: CAP-20260212-011314__spine.verify__R1onr74009 — ALL PASS
- authority.project.status: CAP-20260212-011351__authority.project.status__R38n383101 — GOVERNED
- gaps.status: CAP-20260212-011348__gaps.status__Rq5d583042 — 0 open

### Final Commit Hashes

- mint-modules: `0ce4de6` (feat: production promotion gate + rollback)
- agentic-spine: (closeout commit below)

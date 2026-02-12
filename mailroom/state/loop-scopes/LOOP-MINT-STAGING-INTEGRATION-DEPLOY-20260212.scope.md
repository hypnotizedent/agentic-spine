---
loop_id: LOOP-MINT-STAGING-INTEGRATION-DEPLOY-20260212
status: closed
closed: 2026-02-12
opened: 2026-02-12
owner: "@ronny"
scope: Deploy artwork + quote-page + order-intake as one staged runtime and prove end-to-end flow
repos:
  - mint-modules (product changes)
  - agentic-spine (loop scope + receipts + closeout)
---

# LOOP: Mint Staging Integration Deploy

## Objective

Deploy all three mint modules (artwork/files-api, quote-page, order-intake) together
as a single staged integration runtime and prove the end-to-end flow works from
quote intake through order-intake to artwork seed metadata.

## Phases

1. **P0 Baseline** — spine.verify, ops status, gaps.status, authority.project.status
2. **Worker D** — Create `deploy/docker-compose.staging.yml` with all 3 services, healthchecks, restart policy
3. **Worker E** — Create `deploy/.env.staging.example` + `deploy/README.md` env contract
4. **Worker F** — Create integration smoke runbook + executable smoke script
5. **Recert** — typecheck+build+test all 3 modules, spine verify+status+gaps
6. **Closeout** — Close loop with receipt IDs and final commit hashes

## Done Definition

- Single staged compose runs all 3 modules on shared network
- Env contract documented with zero committed secrets
- Integration smoke script + runbook in place
- All module test/typecheck/build green
- Spine remains 0 loops / 0 gaps after closeout
- Loop closed with receipt IDs and final commit hashes

## Baseline Receipts

- spine.verify: CAP-20260212-010034__spine.verify__Rloh644429 — PASS
- ops status: 0 loops, 0 gaps
- gaps.status: 113 total, 0 open, 107 fixed, 3 closed
- authority.project.status: GOVERNED (pass=7, warn=1, fail=0)

## Closeout

### Deliverables

| Artifact | Path | Status |
|----------|------|--------|
| Staged compose | `deploy/docker-compose.staging.yml` | Created |
| Env contract | `deploy/.env.staging.example` | Created |
| Deploy README | `deploy/README.md` | Created |
| Smoke runbook | `docs/READINESS/MINT_STAGING_INTEGRATION_SMOKE.md` | Created |
| Smoke script | `scripts/smoke/staging-integration-smoke.sh` | Created |
| Gitignore update | `.gitignore` (+`.env.staging`) | Updated |

### Recert Results

- artwork: typecheck PASS, build PASS, 95/95 tests PASS
- quote-page: typecheck PASS, build PASS, 51/51 tests PASS
- order-intake: typecheck PASS, build PASS, 113/113 tests PASS
- spine.verify: CAP-20260212-010606__spine.verify__Rav1c54354 — ALL PASS
- authority.project.status: CAP-20260212-010644__authority.project.status__Ryjv863447 — GOVERNED
- gaps.status: CAP-20260212-010641__gaps.status__R8b6b63387 — 0 open

### Final Commit Hashes

- mint-modules: `fb11923` (feat: staged integration deploy + smoke test)
- agentic-spine: (closeout commit below)

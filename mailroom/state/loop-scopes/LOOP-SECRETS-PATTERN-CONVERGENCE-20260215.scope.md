---
id: LOOP-SECRETS-PATTERN-CONVERGENCE-20260215
status: closed
closed: 2026-02-15
opened: 2026-02-15
owner: "@ronny"
gaps:
  - GAP-OP-402
  - GAP-OP-427
  - GAP-OP-428
  - GAP-OP-429
  - GAP-OP-430
  - GAP-OP-431
---

# LOOP: Secrets Access Pattern Convergence

## Objective

Converge all 29 secret-consuming scripts from 3 conflicting patterns to 1 canonical pattern (`infisical-agent.sh`).

## Patterns

- **Pattern A (Canonical):** subprocess `infisical-agent.sh get/auth/list` — 16 files already correct
- **Pattern B (Broken CLI):** `infisical secrets get` — 3 files, fails without `.infisical.json`
- **Pattern C (Inline API):** reimplements curl + JWT auth — 10 files, ~400 lines of duplication

## Phases

1. **Phase 1 (GAP-OP-402 + GAP-OP-427):** Fix Pattern B scripts (ha-service-call, home-health-alert, infra-vm-bootstrap)
2. **Phase 2 (GAP-OP-428):** Simple Pattern C convergence (ha-ssot-propose, secrets-exec, secrets-projects-status)
3. **Phase 3a (GAP-OP-429):** Extend infisical-agent.sh (list-recursive, jwt-decode, auth-token)
4. **Phase 3b (GAP-OP-430):** Advanced Pattern C convergence (6 files using new commands)
5. **Phase 3c (GAP-OP-431):** D112 gate + path normalization (8 files workbench→canonical)

## Outcome

- 29 files → 1 pattern
- ~400 lines of duplicate auth boilerplate removed
- D112 gate prevents regression

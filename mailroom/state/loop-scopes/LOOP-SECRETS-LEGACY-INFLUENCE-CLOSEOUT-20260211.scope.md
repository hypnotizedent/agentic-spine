---
status: closed
owner: "@ronny"
created: 2026-02-11
closed: 2026-02-11
scope: loop-scope
loop_id: LOOP-SECRETS-LEGACY-INFLUENCE-CLOSEOUT-20260211
severity: high
---

# Loop Scope: LOOP-SECRETS-LEGACY-INFLUENCE-CLOSEOUT-20260211

## Goal

Eliminate deprecated Infisical project influence paths from new agent secret operations. Prove that old-system project aliases (finance-stack, mint-os-portal, mint-os-vault) cannot affect governed secret entry points.

## Phases

### P0: Baseline — DONE
- [x] secrets.projects.status, secrets.namespace.status, secrets.cli.status, spine.verify
- [x] Captured 5 risks: hash mismatch, deprecated alias acceptance, set-interactive override, active workbench refs, D25 gate weakness

### P1: Core runtime lock (spine) — DONE (5341f37)
- [x] Harden infisical-agent.sh v1.1.0: gate deprecated projects (STOP on mutate, WARN on read)
- [x] Lock secrets-set-interactive to binding project + active projects only
- [x] Add FIREFLY_ACCESS_TOKEN and FIREFLY_API_URL key_path_overrides

### P2: Workbench parity + influence cleanup — DONE (ac891f2 workbench)
- [x] Sync vendored infisical-agent.sh from canonical (hash match)
- [x] Update 4 finance scripts from finance-stack to infrastructure project
- [x] Remove deprecated entries from sync-secrets-to-env.sh project maps

### P3: Anti-regression drift gate — DONE (this proposal)
- [x] Upgrade D25 from WARN to FAIL on infisical-agent hash mismatch
- [x] Create D70 secrets-deprecated-alias-lock (deprecated project write protection)
- [x] Wire D70 into drift-gate orchestrator
- [x] Update VERIFY_SURFACE_INDEX.md (D65-D70 rows, counts)

### P4: Validation — DONE
- [x] secrets.cli.status PASS (hash b38361592cbb)
- [x] secrets.projects.status OK (10/10)
- [x] secrets.namespace.status OK (77 keys, 0 root)
- [x] spine.verify D1-D70 PASS
- [x] gaps.status: 1 open (GAP-OP-037, hardware-blocked), 0 orphans

## Acceptance Criteria

1. `secrets.cli.status` PASS (hash parity)
2. No runtime path for new agents to mutate deprecated projects
3. Drift gate prevents regression
4. Loop closed with evidence

## Commits

| Phase | Hash | Repo | Description |
|-------|------|------|-------------|
| P1 | 5341f37 | spine | Runtime lock: agent v1.1.0 + set-interactive guard + namespace overrides |
| P2 | ac891f2 | workbench | Vendored agent sync + finance script migration |
| P3 | (this) | spine | D25 upgrade + D70 gate + index update |

---
status: active
owner: "@ronny"
created: 2026-02-11
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

### P1: Core runtime lock (spine)
- [ ] Harden infisical-agent.sh: gate deprecated projects (STOP on mutate, WARN on read)
- [ ] Lock secrets-set-interactive to binding project + active projects only
- [ ] Add missing key_path_overrides for finance keys used by active scripts

### P2: Workbench parity + influence cleanup
- [ ] Sync vendored infisical-agent.sh from canonical
- [ ] Update scripts/finance/* and scripts/root/firefly/* to use infrastructure project
- [ ] Remove deprecated entries from sync-secrets-to-env.sh project maps

### P3: Anti-regression drift gate
- [ ] Upgrade D25 from WARN to FAIL on hash mismatch
- [ ] Add deprecated-alias detection to drift gate
- [ ] Wire into D55 composite

### P4: Validation
- [ ] All secrets caps PASS
- [ ] spine.verify D1-D70 PASS
- [ ] Before/after proof table

## Acceptance Criteria

1. `secrets.cli.status` PASS (hash parity)
2. No runtime path for new agents to mutate deprecated projects
3. Drift gate prevents regression
4. Loop closed with evidence

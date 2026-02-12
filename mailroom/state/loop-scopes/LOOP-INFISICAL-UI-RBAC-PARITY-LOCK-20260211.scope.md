---
status: active
owner: "@ronny"
created: 2026-02-11
scope: loop-scope
loop_id: LOOP-INFISICAL-UI-RBAC-PARITY-LOCK-20260211
severity: high
---

# Loop Scope: LOOP-INFISICAL-UI-RBAC-PARITY-LOCK-20260211

## Goal

Lock Infisical UI + RBAC parity with spine runtime enforcement. Eliminate disconnect between spine runtime behavior, Infisical UI project state, and RBAC permissions for agent secret writes.

## Phases

### P0: Baseline & Proof
- [ ] secrets.projects.status, secrets.namespace.status, secrets.cli.status, spine.verify, gaps.status
- [ ] Scan active non-legacy deprecated project refs in workbench

### P1: RBAC Lock (live Infisical)
- [ ] Identify spine machine identity (Universal Auth client)
- [ ] Ensure write scope only for canonical project/path policy
- [ ] Remove write permissions on deprecated projects (finance-stack, mint-os-vault, mint-os-portal)

### P2: UI Lifecycle Parity Lock
- [ ] Verify UI state matches secrets.inventory.yaml lifecycle
- [ ] Update deprecated project descriptions in Infisical
- [ ] Decide on delete_candidate projects
- [ ] Update spine bindings if lifecycle changed

### P3: Active Consumer Cleanup (non-legacy)
- [ ] Replace deprecated project-targeted calls in workbench scripts
- [ ] Verify vendored infisical-agent hash parity
- [ ] Mark operator-only multiproject scripts explicitly

### P4: Anti-regression Gate
- [ ] D71: fail if active non-legacy scripts reference deprecated project names without allowlist
- [ ] Wire into drift-gate.sh, VERIFY_SURFACE_INDEX.md

### P5: Validation & Close
- [ ] All validation checks pass
- [ ] Structured closeout report delivered

## Acceptance Criteria

1. Spine identity cannot mutate deprecated projects (RBAC enforced)
2. UI lifecycle matches spine lifecycle
3. Active non-legacy deprecated-project refs = 0 (or exactly matched allowlist)
4. Gate coverage prevents regression
5. All receipts captured

## Commits

| Phase | Hash | Repo | Description |
|-------|------|------|-------------|

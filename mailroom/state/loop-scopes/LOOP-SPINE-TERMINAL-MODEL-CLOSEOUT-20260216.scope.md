---
loop_id: LOOP-SPINE-TERMINAL-MODEL-CLOSEOUT-20260216
created: 2026-02-16
status: active
owner: "@ronny"
scope: agentic-spine
objective: Register and close remaining spine stabilization gaps — terminal role contracts, launcher naming, proposal triage, audit artifact policy.
---

## Context

Pre-product-lane stabilization. Six gaps blocking clean terminal model:
terminal role contract missing, terminal.contract.status capability missing,
launcher --terminal-name support missing, runbook naming adoption missing,
pending proposals untriaged, audit artifact policy unresolved.

## Done Checks

- [ ] All 6 gaps registered and closed
- [ ] terminal.role.contract.yaml exists and validates
- [ ] terminal.contract.status capability operational
- [ ] Launcher supports --terminal-name (backward-compatible)
- [ ] Canonical terminal names documented in AGENTS.md, CLAUDE.md, runbooks
- [ ] All 4 pending proposals triaged (apply/supersede/defer)
- [ ] Audit artifact policy documented and enforced
- [ ] verify.core.run 8/8 PASS
- [ ] verify.domain.run aof --force 18/18 PASS

## Lane Split

| Lane | Scope | Gaps |
|------|-------|------|
| D (contract/runtime) | terminal.role.contract.yaml, terminal.contract.status cap | 1, 2 |
| E (entry/docs) | launcher --terminal-name, runbook naming | 3, 4 |
| F (queue/hygiene) | proposal triage, audit artifact policy | 5, 6 |

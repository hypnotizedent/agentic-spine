# W59_FINDINGS_TO_LOOP_ACTION_MATRIX_20260227

Purpose: exhaustive mapping from forensic findings to one of the three W59 cleanup loops.

## Loop Assignment Matrix

| Priority | Finding | Loop | Action Type | Target Gate/Contract |
|---|---|---|---|---|
| P0 | Entry surface gate-count mismatch (148 vs live) | LOOP 1 | normalize | D279 + entry parity matrix |
| P0 | Domain taxonomy mismatch across agents/roles/docs | LOOP 1 | normalize | D279 domain taxonomy parity |
| P0 | Loop scopes referencing missing gaps | LOOP 1 | reconcile | D280 gap-reference-integrity |
| P1 | High-churn `gate.domain.profiles.yaml` ungated | LOOP 2 | gate coverage | D275 |
| P1 | High-churn `ops/plugins/MANIFEST.yaml` ungated | LOOP 2 | gate coverage | D277 |
| P1 | High-churn `services.health.yaml` ungated | LOOP 2 | gate coverage | D276 |
| P1 | Terminal role status conflicts with agent status | LOOP 1 | normalize | taxonomy/status crosswalk contract |
| P1 | Service registry parity drift across three files | LOOP 2 | normalize | D276 + service parity contract |
| P1 | Decommissioned SSH target still referenced | LOOP 2 | normalize | D278 ssh-target lifecycle lock |
| P1 | verify checks routed to wrong domain packs | LOOP 2 | normalize | verify route trigger audit + patch |
| P2 | `verify.domain.run` vs `verify.pack.run` confusion | LOOP 1 | normalize | entry command semantics contract |
| P2 | `cap show` missing from top entry surface | LOOP 1 | normalize | AGENTS/SESSION parity refresh |
| P2 | Loop status enum documented in one file only | LOOP 1 | normalize | loop status vocabulary contract |
| P2 | Workbench repo boundary implicit | LOOP 1 | normalize | explicit multi-repo boundary doc |
| P2 | Missing mapping for media naming aliases | LOOP 1 | normalize | domain alias mapping |
| P2 | D112 enforcement assumptions outside scope | LOOP 2 | boundary | secrets enforcement boundary note |
| P2 | Duplicate staged compose stacks in archive/staged | LOOP 3 | classify | archive/tombstone matrix |
| P2 | Unclassified governance domain directories | LOOP 1 | classify | domain classification matrix |
| P2 | Inbox plugin path non-standard and under-documented | LOOP 2 | normalize | plugin location contract |
| P2 | 7 ghost modules in mint-modules unmarked | LOOP 3 | classify | scaffolded/deployed status contract |
| P2 | Duplicate `request-id` middleware across modules | LOOP 3 | promote | shared middleware promotion plan |
| P2 | Planning/canonical overlap without staleness markers | LOOP 3 | archive | stale artifact policy |
| P2 | Superseded versioned canonical docs coexisting | LOOP 3 | tombstone | superseded doc tombstone rules |
| P3 | Legacy aliases and stale endpoint refs | LOOP 3 | archive/refresh | shell alias hygiene register |
| P3 | Quarantine directories pending triage | LOOP 3 | classify | quarantine disposition checklist |
| P3 | Large receipt/session sprawl | LOOP 3 | archive policy | receipt archival automation contract |
| P3 | Untouched >7 day high-risk surfaces | LOOP 3 | refresh/tombstone | freshness ratchet in D281 |

## 7-Day Freshness Refresh Set (must classify)
1. `AGENTS.md`
2. `CLAUDE.md`
3. `docs/governance/SESSION_PROTOCOL.md`
4. `ops/bindings/agents.registry.yaml`
5. `ops/bindings/terminal.role.contract.yaml`
6. `ops/bindings/gate.domain.profiles.yaml`
7. `ops/plugins/MANIFEST.yaml`
8. `ops/bindings/services.health.yaml`
9. `SERVICE_REGISTRY.yaml`
10. `ops/bindings/ssh.targets.yaml`
11. `ops/bindings/docker.compose.targets.yaml`

## Execution Policy
- Loop 1 closes before Loop 2 enforce promotion.
- Loop 2 closes before Loop 3 delete-phase authorization.
- Loop 3 delete phase requires explicit token and archive evidence.

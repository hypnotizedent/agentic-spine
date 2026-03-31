---
title: Declared But Unwired Contract Enforcement — Decision
parent_loop_id: LOOP-SPINE-CLOSURE-AND-AGENTIC-CORE-STABILIZATION-20260326
concern: post-h2.declared-but-unwired-contract-enforcement
stage: decision
version: 1
updated_at: 2026-03-29
machine_enforcement: not_yet_machine_enforced
source_triangulation:
  - docs/governance/DECLARED_BUT_UNWIRED_CONTRACT_ENFORCEMENT_DISCOVERY.md
  - ops/bindings/spine.surface.metabolism.registry.yaml
  - ops/bindings/governed.change.lifecycle.contract.yaml
  - ops/bindings/governance.profile.contract.yaml
  - ops/bindings/session.admission.contract.yaml
---

# Declared But Unwired Contract Enforcement — Decision

## Parent Loop

- `LOOP-SPINE-CLOSURE-AND-AGENTIC-CORE-STABILIZATION-20260326`

## Concern

- `post-h2.declared-but-unwired-contract-enforcement`

## Authoritative Discovery Artifact

- `docs/governance/DECLARED_BUT_UNWIRED_CONTRACT_ENFORCEMENT_DISCOVERY.md` (commit `eaf084ce`)

## Capability-Backed Live Posture Summary

Reproduced 2026-03-29 via spine engine capabilities:

- verify.fast: 29 gates, 28 pass, 0 fail, 1 warn (D127). D425 PASS, D426 PASS.
- spine.control.tick: 8 open loops, 43 open gaps, 764 friction total, 0 queued.
- self-governance.status: FAIL (pre-existing projection drift and missing loop scope).
- Enforcement posture unchanged from discovery: ~19% machine-enforced, ~31% runtime-consumed, ~38% semantic-only, ~12% inactive.
- No mismatch between capability output and repo truth for this concern.

## Tranche-1 Decision

**Result**: `hot_path_governance_contracts_first`

**Rationale**: Session admission and governance profile contracts are both runtime-consumed
on the engine hot path (session bootstrap, policy guard) but have zero verify gate enforcement.
A structural parity gate between them is the smallest high-leverage landing because:
- Both contracts are already consumed — adding a gate closes the trust-verify gap
- The check is structurally bounded (YAML cross-reference validation, no live state inspection)
- Violations would silently break session admission or profile resolution
- It builds on the D425/D426 pattern (new gate script + registry + topology wiring)

## Exact Included Surfaces

| Contract | What The Gate Validates | Engine Relevance |
|---|---|---|
| `session.admission.contract.yaml` | Every lane references a valid profile; delivery/parity fields are present | critical |
| `governance.profile.contract.yaml` | Every profile defines required properties; lane assignments are bidirectionally consistent with session admission | critical |

The gate validates cross-contract structural parity:
1. Every lane in session.admission references a profile that exists in governance.profile
2. Every lane_assignment in governance.profile references a lane that exists in session.admission
3. Profile references match bidirectionally (no contradictions)
4. Required structural fields are present and non-empty

## Exact Write Boundary

Implementation (when authorized) may mutate ONLY:

- `surfaces/verify/d427-session-governance-contract-parity-lock.sh` — new gate script (create)
- `ops/bindings/gate.registry.yaml` — add D427 entry, update counts
- `ops/bindings/gate.execution.topology.yaml` — add D427 to core_mode, update core_count_limit
- `ops/bindings/gate.domain.profiles.yaml` — add D427 to core gate_ids
- `ops/bindings/terminal.worker.catalog.yaml` — regenerated projection (D411 pre-commit gate)
- `ops/bindings/terminal.launcher.view.yaml` — regenerated projection (D411 pre-commit gate)
- `docs/reference/generated/worker-usage/*.md` — regenerated docs (D411 pre-commit gate)

Implementation must NOT mutate:
- `session.admission.contract.yaml` (enforced, not changed)
- `governance.profile.contract.yaml` (enforced, not changed)
- Any other contract, governance doc, or capability metadata

## Exact Verify/Gate Boundary

- One new gate: D427 `session-governance-contract-parity-lock`
- Category: `governance-hygiene`
- Gate class: `invariant`
- Severity: `high`
- Ring: `standard`
- Domain: `spine`
- Mode: `enforce`
- Wired into: `verify fast` via core_mode topology

## Exact Deferred Surfaces

| Surface | Tranche | Reason Deferred |
|---|---|---|
| `governed.change.lifecycle.contract.yaml` route/stage sequencing | tranche-1b or tranche-2 | Requires live loop-state inspection; D425 already covers durability |
| `verify.failure.classification.contract.yaml` | tranche-2 | Lower urgency; classification is already functional |
| `spine.self-governance.lifecycle.contract.yaml` | tranche-2 | Already has capability-backed status check |
| `root.authority.contract.yaml` | tranche-2 | Structurally stable, rarely mutated |
| `node.role.contract.yaml` | tranche-2 | Structurally stable, rarely mutated |
| `role.runtime.control.contract.yaml` | tranche-2 | Structurally stable, rarely mutated |
| 4 stale governance doc frontmatter updates | tranche-3 | Cosmetic metadata drift, not behavioral |
| ~100 semantic-only contracts | tranche-4+ | Low engine relevance, needs sub-tranching |

## Posture Metadata Drift

**Deferred to tranche-3.** Four governance documents have stale `machine_enforcement: not_yet_machine_enforced`
metadata that is now inaccurate due to D425/D426 landing. This drift is cosmetic and does not affect
engine behavior. Fixing it in tranche-1 would broaden the write boundary beyond gate enforcement.

## Explicit Answers

1. **Does tranche 1 include contract/gate wiring, runtime-consumer wiring, posture cleanup, or a bad mixture?**
   Contract/gate wiring ONLY. No runtime-consumer changes. No posture cleanup. No contract edits.

2. **Should stale `machine_enforcement` frontmatter drift be folded into tranche 1 or deferred?**
   DEFERRED to tranche-3. It is cosmetic and would broaden the write boundary beyond the gate enforcement concern.

3. **Which pre-existing failures or warnings are allowed to remain out of scope?**
   - D127 warn (pre-existing)
   - self-governance projection parity drift (pre-existing, separate concern)
   - self-governance missing loop scope LOOP-...-20260321 (pre-existing)
   - scheduler 9 failed jobs, 1 unknown (pre-existing)

## Timeline

| Date | Stage | Deliverable | Dependency | Slip Condition |
|---|---|---|---|---|
| 2026-03-29 | discovery | Live posture inventory and tranche plan | Parent artifacts elect concern | Landed at `eaf084ce` |
| 2026-03-29 | decision | This artifact: exact tranche-1 boundary | Discovery landed and pushed | Landing now |
| 2026-03-29 or next clean window | election | Authorization of D427 implementation | Decision landed and pushed | Operator review delays |
| 2026-03-29 to 2026-03-30 | implementation | D427 gate: session-governance-contract-parity-lock | Election authorizes implementation | Pre-commit failures, gate design complexity |
| After tranche-1 receipts | follow-on | Tranche-1b (lifecycle route enforcement) or tranche-2 (authority chain) | Tranche-1 verified and closed | Tranche-1 residue or new concerns |

## Non-Goals

- Do not edit contracts or governance docs outside this single decision artifact
- Do not add or modify verify gates in this pass
- Do not fix stale posture metadata in this pass
- Do not change capability metadata
- Do not broaden into election or implementation by stealth
- Do not fix self-governance projection drift (pre-existing, separate concern)
- Do not fix scheduler failures (pre-existing)

## Exact Proposed Next Action

- `declared_but_unwired_contract_enforcement_election`

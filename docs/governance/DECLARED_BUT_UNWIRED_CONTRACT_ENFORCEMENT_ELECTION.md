---
status: authoritative
owner: "@ronny"
last_verified: 2026-03-29
scope: declared-but-unwired-contract-enforcement-election
version: 1.0
source_triangulation:
  - docs/governance/DECLARED_BUT_UNWIRED_CONTRACT_ENFORCEMENT_DISCOVERY.md
  - docs/governance/DECLARED_BUT_UNWIRED_CONTRACT_ENFORCEMENT_DECISION.md
  - ops/bindings/governed.change.lifecycle.contract.yaml
  - ops/bindings/gate.registry.yaml
  - ops/bindings/gate.execution.topology.yaml
machine_enforcement: not_yet_machine_enforced
---

# Declared But Unwired Contract Enforcement Election

## Parent Loop Id

- `LOOP-SPINE-CLOSURE-AND-AGENTIC-CORE-STABILIZATION-20260326`

## Concern Id

- `post-h2.declared-but-unwired-contract-enforcement`

## Authoritative Discovery Artifact Path

- `docs/governance/DECLARED_BUT_UNWIRED_CONTRACT_ENFORCEMENT_DISCOVERY.md`
- Commit: `eaf084ce`

## Authoritative Decision Artifact Path

- `docs/governance/DECLARED_BUT_UNWIRED_CONTRACT_ENFORCEMENT_DECISION.md`
- Commit: `4d2b65df`

## Capability-Backed Live Posture Confirmation Summary

Reconfirmed 2026-03-29 via spine engine capabilities:

- `session.v3.attach`: root-main integration lane clean; entry packet compiled successfully.
- `authority.resolve`: loop `LOOP-SPINE-CLOSURE-AND-AGENTIC-CORE-STABILIZATION-20260326` is active and `ready_for_dispatch: true`.
- `spine.control.tick --fast --json`: 8 open loops, 43 open gaps, 764 friction total, 0 queued, scheduler still erroring with 9 failed jobs and 1 unknown.
- `spine.self-governance.status`: FAIL from pre-existing projection parity drift and missing loop scope; unchanged from discovery/decision.
- `verify.fast --json`: 29 total, 28 pass, 0 fail, 1 warn (`D127`); D425 and D426 both PASS.

No live capability output introduced a blocker inside tranche-1. The terminal-contract failure on
`stabilization.mode.yaml` belongs to deferred terminal-scope enforcement, not the elected D427 write
boundary.

## Exact Elected Result

- `authorize_declared_but_unwired_contract_enforcement_tranche1_implementation`

## Explicit Rationale

- Discovery established that governance-core enforcement posture remains mixed and that the highest
  leverage unwired debt sits in runtime-consumed hot-path governance contracts.
- Decision narrowed tranche-1 to the smallest high-leverage landing: one structural parity gate
  between `session.admission.contract.yaml` and `governance.profile.contract.yaml`.
- Live capability confirmation shows the same pre-existing background issues recorded earlier, but no
  new blocker within the tranche-1 slice.
- The authorized write set is bounded, structural, and machine-checkable: one gate script, gate
  registry/topology/profile wiring, and the D411-driven regenerated worker projections required by the
  repo's current pre-commit discipline.

## Whether Implementation Is Authorized Now

- Yes.

## Exact Authorized Implementation Boundary

- Create `surfaces/verify/d427-session-governance-contract-parity-lock.sh`.
- Update `ops/bindings/gate.registry.yaml` to register D427.
- Update `ops/bindings/gate.execution.topology.yaml` to wire D427 into `core_mode`.
- Update `ops/bindings/gate.domain.profiles.yaml` to include D427 in the `core` gate set.
- Regenerate the D411-tracked worker projection outputs:
  - `ops/bindings/terminal.worker.catalog.yaml`
  - `ops/bindings/terminal.launcher.view.yaml`
  - `docs/reference/generated/worker-usage/*.md`

## What Is Explicitly Not Authorized

- Editing `session.admission.contract.yaml`
- Editing `governance.profile.contract.yaml`
- Editing any other governance contract
- Editing stale `machine_enforcement` frontmatter drift
- Authority-chain or terminal-scope enforcement work
- Capability, domain, plane, or layer mutation
- Broader semantic-only contract enforcement

## Whether Posture Metadata Drift Is In Tranche 1

- No. Stale posture metadata remains deferred to tranche-3.

## Preserved Non-Goals

- Persistence gate enforcement remains landed and in force.
- Layer classification remains landed and in force.
- Pre-existing D127 warn remains out of scope.
- Pre-existing self-governance projection drift remains out of scope.
- Pre-existing missing self-governance loop scope remains out of scope.
- Git workflow discipline remains a separate doctrine concern.
- Autonomous multi-node operation remains a separate downstream `new_truth`.
- H3 publication remains inactive.
- Extraction remains inactive.
- Cowork remains `out_of_scope_until_governed_adapter_exists`.

## Timeline Confirmation

| Date | Stage | Deliverable | Dependency | Slip Condition |
|---|---|---|---|---|
| 2026-03-29 | discovery | Live posture inventory and tranche plan | Parent artifacts elected concern | Landed at `eaf084ce` |
| 2026-03-29 | decision | Exact tranche-1 boundary | Discovery committed and pushed | Landed at `4d2b65df` |
| 2026-03-29 | election | Authorization of tranche-1 implementation | Decision committed and pushed | Landing now |
| 2026-03-29 to 2026-03-30 | implementation | D427 parity gate and bounded wiring | Election authorizes implementation | Gate design or D411 regeneration issues |
| After tranche-1 receipts | follow-on | Tranche-1b or tranche-2/3 selection | Tranche-1 verified and closed | Residue or new blockers |

## Exact Next Action

- `declared_but_unwired_contract_enforcement_implementation`

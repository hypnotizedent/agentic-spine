# Declared But Unwired Contract Enforcement — Follow-On D411 Blocker Election

## Parent Loop Id

- `LOOP-SPINE-CLOSURE-AND-AGENTIC-CORE-STABILIZATION-20260326`

## Concern Id

- `post-h2.declared-but-unwired-contract-enforcement-followon-d411-blocker`

## Authoritative Blocker Discovery Artifact Path

- `docs/governance/DECLARED_BUT_UNWIRED_CONTRACT_ENFORCEMENT_FOLLOWON_D411_BLOCKER_DISCOVERY.md` (commit `b66134a6`)

## Authoritative Blocker Decision Artifact Path

- `docs/governance/DECLARED_BUT_UNWIRED_CONTRACT_ENFORCEMENT_FOLLOWON_D411_BLOCKER_DECISION.md` (commit `29d59b6c`)

## Live Blocker Posture Confirmation Summary

- Branch: `main`, HEAD: `29d59b6c`, clean, synced `0 ahead / 0 behind`
- No repo-owned implementation commit landed after the blocked structural-only attempt
- `./bin/ops cap run verify.fast -- --json`: PASS (`30 total / 30 pass / 0 fail / 0 warn`)
- `./bin/ops cap run verify.core.run -- --json`: PASS (`30 total / 30 pass / 0 fail / 0 warn`)
- `./bin/ops cap run terminal.worker.projection.audit`: PASS (`4 governed surfaces`)
- `bash surfaces/verify/d411-terminal-worker-projection-lock.sh`: PASS
- D411 still delegates to `ops/plugins/core/verify/bin/worker-projection-audit`
- `worker-projection-audit` still binds all 4 tracked worker-projection outputs to the 4 generator wrappers
- `gate.domain.profiles.yaml` remains a D411 input in `.githooks/pre-commit`
- The 4 tracked outputs still exist on disk and remain version-controlled
- Prompt/runtime semantics, protocol runtime handoffs, and cross-surface state synthesis remain outside this seam

## Exact Elected Result

- `authorize_declared_but_unwired_contract_enforcement_followon_d411_blocker_implementation`

## Explicit Rationale

The live blocker posture still matches the committed blocker discovery and blocker decision exactly. D411 is healthy on `HEAD`, the tracked worker-projection outputs remain present and governed, and the widened combined slice remains the smallest truthful landable boundary. No new dependency, capability-definition, or cross-surface drift has appeared that would justify reopening scope or holding for operator review.

## Whether Implementation Is Authorized Now

- `yes`

## Exact Authorized Implementation Boundary

### Authorized Write Surfaces (9)

- `ops/bindings/authority.concerns.yaml`
- `ops/bindings/single.authority.contract.yaml`
- `ops/bindings/gate.registry.yaml`
- `ops/bindings/gate.execution.topology.yaml`
- `ops/bindings/gate.domain.profiles.yaml`
- `ops/bindings/terminal.worker.catalog.yaml`
- `ops/bindings/routing.dispatch.yaml`
- `ops/bindings/terminal.launcher.view.yaml`
- `docs/reference/generated/worker-usage/`

### Preserved Read-Only Support Surfaces

- `ops/plugins/core/authority/bin/authority-concerns-projection-build`
- `surfaces/verify/d406-concern-projection-registration-completeness-lock.sh`
- `surfaces/verify/d411-terminal-worker-projection-lock.sh`
- `surfaces/verify/d422-translator-authority-isolation-lock.sh`
- `ops/plugins/core/verify/bin/worker-projection-audit`
- `ops/bindings/terminal.worker.projection.contract.yaml`
- `ops/plugins/core/ops/bin/gen-terminal-worker-runtime-v2.py`
- `ops/plugins/core/ops/bin/gen-worker-catalog.sh`
- `ops/plugins/core/ops/bin/gen-routing-dispatch.sh`
- `ops/plugins/core/ops/bin/gen-launcher-view.sh`
- `ops/plugins/core/ops/bin/gen-worker-usage-docs.sh`
- `.githooks/pre-commit`

### Mandatory Commit Rule

- All 4 tracked worker-projection outputs must land in the same governed commit as the 5 structural surfaces.

## Exact Blocker If Not Authorized

- `none`

## Preserved Deferred Surfaces

- `ops/capabilities.yaml`
- `ops/bindings/verify.run.profile.contract.yaml`
- `ops/bindings/prompt.registry.yaml`
- `ops/bindings/prompt.library.contract.yaml`
- `ops/plugins/core/session/bin/session-v3-attach`
- `ops/bindings/communication.protocol.contract.yaml`
- `ops/bindings/spine.surface.metabolism.registry.yaml`
- `ops/bindings/master.inventory.registry.yaml`
- `ops/bindings/domain.projection.contract.yaml`

## Preserved Non-Goals

- No implementation occurs in this election pass
- No tracked worker-output regeneration occurs in this election pass
- No generator code modification
- No `terminal.worker.projection.contract.yaml` modification
- No capability-definition rewiring
- No prompt/runtime semantics absorption
- No protocol runtime handoff absorption
- No cross-surface state synthesis absorption
- No D411 weakening

## Timeline Confirmation

| Date | Stage | Exact Deliverable | Dependency | Slip Condition |
|---|---|---|---|---|
| 2026-03-29 | follow-on election landed | Structural-only election at `773ba854` | Prior follow-on discovery + decision | Already landed |
| 2026-03-29 | blocked implementation status recorded | No repo-owned implementation landing because D411 required fresh worker-projection outputs | Structural-only implementation attempt | Already recorded |
| 2026-03-29 | blocker discovery landed | `b66134a6` | Blocked implementation evidence | Already landed |
| 2026-03-29 | blocker decision landed | `29d59b6c` with exact widened 9-surface boundary | Blocker discovery committed and pushed | Already landed |
| 2026-03-29 | blocker election lands | This artifact authorizes or holds the combined structural + worker-projection slice | Blocker decision committed and pushed; live blocker posture unchanged | Material live drift in D411, worker-projection audit, or deferred-surface coupling before election |
| After election | bounded implementation target | Restore structural concern source/projection truth and regenerate all 4 tracked worker-projection outputs in one governed commit | This election authorizes the widened slice | Additional blocker outside the 9 write surfaces, generator failure, or deferred-surface coupling beyond the committed decision |
| After the widened slice closes | separate concern resumption | Remaining capability-definition, prompt/runtime, protocol-runtime, posture-drift, and cross-surface concerns resume through their own classified passes | Widened slice landed and verified | Implementation reveals a different truthful next seam |

## Exact Next Action

- `declared_but_unwired_contract_enforcement_followon_d411_blocker_implementation`

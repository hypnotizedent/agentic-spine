# Declared But Unwired Contract Enforcement — Follow-On Election

## Parent Loop Id

- `LOOP-SPINE-CLOSURE-AND-AGENTIC-CORE-STABILIZATION-20260326`

## Concern Id

- `post-h2.declared-but-unwired-contract-enforcement-followon`

## Authoritative Follow-On Discovery Artifact Path

- `docs/governance/DECLARED_BUT_UNWIRED_CONTRACT_ENFORCEMENT_FOLLOWON_DISCOVERY.md` (commit `14d5d842`)

## Authoritative Follow-On Decision Artifact Path

- `docs/governance/DECLARED_BUT_UNWIRED_CONTRACT_ENFORCEMENT_FOLLOWON_DECISION.md` (commit `afd8e6d9`)

## Live Structural Posture Confirmation Summary

- `ops/bindings/authority.concerns.yaml` is still absent.
- `ops/bindings/single.authority.contract.yaml` is still absent.
- Standalone D422 still fails on the missing `authority.concerns.yaml` dependency.
- D406 and D422 remain assigned to `core`, and `core_mode.core_gate_ids` still omits both gates.
- `verify.fast` and `verify.core.run` still resolve to `verify-topology core`.
- `./bin/ops cap run verify.fast -- --json` still passes `30 total / 30 pass / 0 fail / 0 warn`.
- `./bin/ops cap run verify.core.run -- --json` still passes `30 total / 30 pass / 0 fail / 0 warn`.
- `ops/plugins/core/verify/bin/verify-run fast --json` still passes `27 total / 27 pass / 0 fail / 0 warn`.
- `authority-concerns-projection-build` and D406 still depend on `authority.concerns.yaml`.
- Prompt/runtime semantics, protocol runtime handoffs, and downstream cross-surface synthesis remain outside this seam.

## Exact Elected Result

- `authorize_declared_but_unwired_contract_enforcement_followon_implementation`

## Explicit Rationale

- The live repo still matches the committed discovery and decision boundary closely enough to ratify the same bounded slice without reopening scope.
- The missing concern-source contract, the missing compatibility projection, D406, D422, and core-pack topology alignment still form one coherent governance-core enforcement seam.
- Restoring only the missing source file would leave the authority projection chain and fast-pack contradiction unresolved.
- Broadening into capability-definition rewiring, prompt/runtime semantics, protocol runtime handoffs, or cross-surface synthesis is still unnecessary and still unsupported by the live posture recheck.

## Whether Implementation Is Authorized Now

- `yes`

## Exact Authorized Implementation Boundary

- `ops/bindings/authority.concerns.yaml`
- `ops/plugins/core/authority/bin/authority-concerns-projection-build`
- `ops/bindings/single.authority.contract.yaml`
- `surfaces/verify/d406-concern-projection-registration-completeness-lock.sh`
- `surfaces/verify/d422-translator-authority-isolation-lock.sh`
- `ops/bindings/gate.registry.yaml`
- `ops/bindings/gate.execution.topology.yaml`
- `ops/bindings/gate.domain.profiles.yaml`

Implementation authorization also preserves these boundary rules:

- restore `ops/bindings/authority.concerns.yaml` as canonical concern-source truth
- keep the authority projection chain in the same slice
- keep D406 inside the same slice
- keep fast-pack alignment inside the same slice
- treat archived `ops/bindings/archive/pre-consolidation/authority.concerns.yaml` as evidence and seed reference only, not as a blind restore source
- keep capability-definition rewiring deferred unless implementation proves topology alignment alone is insufficient

## Exact Blocker If Not Authorized

- `none`

## Preserved Deferred Surfaces

- `ops/bindings/master.inventory.registry.yaml`
- `ops/bindings/domain.projection.contract.yaml`
- `ops/bindings/verify.run.profile.contract.yaml`
- `ops/capabilities.yaml`
- `ops/bindings/routing.dispatch.yaml`
- `ops/bindings/prompt.registry.yaml`
- `ops/bindings/prompt.library.contract.yaml`
- `ops/plugins/core/context/bin/prompt-library-bootstrap`
- `ops/plugins/core/session/bin/session-v3-attach`
- `ops/bindings/communication.protocol.contract.yaml`
- `ops/bindings/spine.surface.metabolism.registry.yaml`

## Preserved Non-Goals

- No implementation occurs in this election pass.
- Do not restore `authority.concerns.yaml` in this pass.
- Do not create `single.authority.contract.yaml` in this pass.
- Do not modify D406, D422, gate topology, gate registry, gate profiles, or capability definitions in this pass.
- Do not absorb prompt/runtime semantics into this concern.
- Do not absorb protocol runtime handoffs into this concern.
- Do not absorb cross-surface state synthesis into this concern.
- Do not broaden beyond the elected structural-alignment slice.

## Timeline Confirmation

| Date | Intended Stage | Exact Deliverable | Dependency | Slip Condition |
|---|---|---|---|---|
| 2026-03-29 | implementation landed | D427 tranche-1 implementation landed at `3d96c11f` | prior discovery, decision, and election completed | already landed |
| 2026-03-29 | implementation handed back | translator-authority implementation landed at `b193da58` and handed back to this concern | translator-authority implementation verified and closed | already landed |
| 2026-03-29 | discovery | follow-on discovery landed at `14d5d842` | clean synced baseline and live residue reproduced | already landed |
| 2026-03-29 | decision | follow-on decision landed at `afd8e6d9` | discovery artifact committed and pushed | already landed |
| 2026-03-29 | election | this artifact authorizes the bounded structural gate dependency / pack-alignment slice | decision artifact committed and pushed, live posture unchanged | material live drift before landing would have blocked authorization |
| after election | bounded implementation target | restore the concern-source contract, restore the compatibility projection, and align the elected structural gates into the core fast pack | this election authorizes the exact write set | scope creep into deferred runtime, protocol, or cross-surface concerns |
| after that slice closes | separate follow-on work | remaining prompt/runtime, protocol, posture-drift, and downstream cross-surface concerns resume through their own classified passes | structural-alignment slice verified and closed | residual failures show a different truthful follow-on seam |

## Exact Next Action

- `declared_but_unwired_contract_enforcement_followon_implementation`

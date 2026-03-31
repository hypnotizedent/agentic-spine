# Declared But Unwired Contract Enforcement — Follow-On Decision

## Parent Loop Id

- `LOOP-SPINE-CLOSURE-AND-AGENTIC-CORE-STABILIZATION-20260326`

## Concern Id

- `post-h2.declared-but-unwired-contract-enforcement-followon`

## Authoritative Follow-On Discovery Artifact Path

- `docs/governance/DECLARED_BUT_UNWIRED_CONTRACT_ENFORCEMENT_FOLLOWON_DISCOVERY.md` (commit `14d5d842`)

## Live Structural-Alignment Recheck Summary

- `ops/bindings/authority.concerns.yaml` is still absent in the live repo, and `ops/bindings/single.authority.contract.yaml` is still absent as the missing compatibility projection target.
- Standalone `bash surfaces/verify/d422-translator-authority-isolation-lock.sh` still fails for the same reason: `authority.concerns.yaml not found`.
- `ops/bindings/gate.registry.yaml` still marks D422 active in `enforce` mode, and `ops/bindings/gate.execution.topology.yaml` still assigns both D406 and D422 to the `core` domain.
- `core_mode.core_gate_ids` still omits both D406 and D422, so fast-pack execution still hides the same seam that the standalone gate exposes.
- `./bin/ops cap show verify.fast` and `./bin/ops cap show verify.core.run` still resolve to the same command: `./ops/plugins/core/verify/bin/verify-topology core`.
- `./bin/ops cap run verify.fast -- --json` still passes `30 total / 30 pass / 0 fail / 0 warn`, and `ops/plugins/core/verify/bin/verify-run fast --json` still passes `27 total / 27 pass / 0 fail / 0 warn`; neither path surfaces D422 because both still resolve from the core fast-pack gate set rather than the failing standalone gate.
- `surfaces/verify/d406-concern-projection-registration-completeness-lock.sh` and `ops/plugins/core/authority/bin/authority-concerns-projection-build` still depend on `ops/bindings/authority.concerns.yaml`.
- The archived predecessor at `ops/bindings/archive/pre-consolidation/authority.concerns.yaml` still exists and remains structurally relevant evidence, including the historical `translator_authority_surfaces` concern family.
- Prompt/runtime semantics, communication-protocol runtime handoffs, and downstream cross-surface synthesis still remain outside this seam.

## Exact Tranche Decision

- The next slice is a broader `structural_gate_dependency_and_pack_alignment` slice, not a one-file restore.
- The missing `authority.concerns.yaml` is one symptom inside a single coherence seam:
  - the canonical concern-source contract is missing;
  - the compatibility projection target is missing;
  - D406 and D422 still depend on that concern-source chain;
  - fast-pack execution still omits the same structural gates from the core pack.
- This concern remains on the `new_truth` route through election. The next slice does not merely repair a broken file; it re-freezes which surface is canonical concern-source truth and how governance-core fast-pack enforcement is supposed to surface that truth.

## Exact Chosen Direction For `authority.concerns.yaml`

- Chosen direction: restore `ops/bindings/authority.concerns.yaml` as the canonical concern-source contract.
- Rejected direction: do not narrow D422, D406, or the authority-concern projection chain away from that dependency.
- The archived pre-consolidation file is evidence and seed reference only. It is not authorized as a blind copy source.
- Later implementation must restore the live file against current repo truth:
  - current repo-relative paths;
  - current projection output locations;
  - current authoritative/projection/tombstoned state markers;
  - current concern families that still matter live.

## Exact Fast-Pack Alignment Decision

- Fast-pack alignment is inside the next slice.
- The future implementation boundary must align governance-core fast-pack membership with the elected structural gates for this seam, specifically by bringing the elected authority-concern gates into the `core_mode.core_gate_ids` set.
- Current capability routing is already aligned at the command level: `verify.fast` and `verify.core.run` both point to `verify-topology core`. Rewiring those capability definitions is not part of the elected boundary.
- `verify-run fast` / wrapper-path changes are not independently authorized by default. They become in-scope only if they are strictly required to keep wrapper execution on the same elected gate set after topology alignment is landed.

## Exact In-Scope Implementation Surfaces

### Core structural source/projection chain

- `ops/bindings/authority.concerns.yaml`
  Purpose: restore the canonical concern-source contract using current live repo truth.
- `ops/plugins/core/authority/bin/authority-concerns-projection-build`
  Purpose: keep the generated compatibility projection aligned to the restored concern-source contract.
- `ops/bindings/single.authority.contract.yaml`
  Purpose: restore the compatibility projection generated from the restored concern-source contract.

### Structural enforcement surfaces inside the same slice

- `surfaces/verify/d406-concern-projection-registration-completeness-lock.sh`
  Purpose: keep the concern-projection registration lock truthful against the restored concern-source chain.
- `surfaces/verify/d422-translator-authority-isolation-lock.sh`
  Purpose: keep translator-isolation enforcement truthful against the restored concern-source chain.
- `ops/bindings/gate.registry.yaml`
  Purpose: update gate metadata only if required to keep D406/D422 classification truthful after restoration.
- `ops/bindings/gate.execution.topology.yaml`
  Purpose: align `core_mode.core_gate_ids` with the elected structural gates in this seam.
- `ops/bindings/gate.domain.profiles.yaml`
  Purpose: keep core-domain gate profile truth aligned with the restored topology boundary.

## Exact Deferred Surfaces

- `ops/bindings/master.inventory.registry.yaml`
  Current live registrations for the D406-enforced concern families are already present; broad registry rewrite is not authorized in the next slice.
- `ops/bindings/domain.projection.contract.yaml`
  Current live projection registrations are already present; broad projection-contract rewrite is not authorized in the next slice.
- `ops/bindings/verify.run.profile.contract.yaml`
  Profile semantics remain separate from the structural source/pack repair unless later implementation proves a residual mismatch after topology alignment.
- `ops/capabilities.yaml`
  Capability command routing is already aligned to `verify-topology core`; no capability-definition rewrite is authorized in the next slice.
- `ops/bindings/routing.dispatch.yaml`
  No dispatch-route rewrite is authorized in the next slice.
- `ops/bindings/translator.authority.contract.yaml`
  Translator authority meaning is already landed; this concern restores its declared dependency chain but does not reopen translator-authority doctrine.
- `ops/bindings/prompt.registry.yaml`
- `ops/bindings/prompt.library.contract.yaml`
- `ops/plugins/core/context/bin/prompt-library-bootstrap`
- `ops/plugins/core/session/bin/session-v3-attach`
- `ops/bindings/communication.protocol.contract.yaml`
- `ops/bindings/spine.surface.metabolism.registry.yaml`
  Prompt/runtime semantics, protocol runtime handoffs, and posture/cross-surface synthesis drift remain separate concerns.

## Exact Non-Goals

- Do not restore `authority.concerns.yaml` in this pass.
- Do not create `single.authority.contract.yaml` in this pass.
- Do not wire D406 or D422 into fast-pack execution in this pass.
- Do not edit any contract, gate, template, session surface, or adapter surface outside this single decision artifact.
- Do not broaden into prompt/runtime semantics, `role_prompt_sets`, template loading, communication-protocol runtime handoffs, or runtime prompt freshness sync.
- Do not absorb cross-surface state synthesis, metabolism-registry cleanup, or autonomous multi-node work into this concern.
- Do not reopen translator-authority unification.

## Explicit Timeline

| Date | Intended Stage | Exact Deliverable | Dependency | Slip Condition |
|---|---|---|---|---|
| 2026-03-29 | implementation landed | D427 tranche-1 implementation landed at `3d96c11f` | prior discovery, decision, and election completed | already landed |
| 2026-03-29 | implementation handed back | translator-authority implementation landed at `b193da58` and handed back to this concern | translator-authority verification completed | already landed |
| 2026-03-29 | discovery | `docs/governance/DECLARED_BUT_UNWIRED_CONTRACT_ENFORCEMENT_FOLLOWON_DISCOVERY.md` landed at `14d5d842` with residue inventory, tranche candidates, and tranche recommendation | clean synced baseline and live residue reproduced | already landed |
| 2026-03-29 | decision | this artifact freezes the exact structural gate dependency and pack-alignment boundary | follow-on discovery committed on `main`, live structural posture unchanged | live source/projection or pack posture diverges before landing |
| 2026-03-29 or next clean landing window | election | `declared_but_unwired_contract_enforcement_followon_election` to authorize or hold the exact structural-alignment slice | this decision artifact committed and pushed, parent artifacts aligned | unresolved disagreement over whether D406 belongs inside the slice or newly surfaced live drift beyond the frozen boundary |
| after election | bounded implementation target | restore the concern-source contract, restore its compatibility projection, and align the elected structural gates into the core fast pack without reopening deferred seams | election authorizes the exact write set | scope creep into prompt/runtime semantics, protocol runtime handoffs, posture drift cleanup, or broader capability/profile rewrites |
| after that slice closes | separate follow-on work | resume remaining separate concerns, including prompt/runtime semantics, posture metadata drift, or downstream cross-surface synthesis only through their own classified passes | structural-alignment slice verified and closed | residual failures show the next truthful concern boundary is different |

## Exact Proposed Next Action

- `declared_but_unwired_contract_enforcement_followon_election`

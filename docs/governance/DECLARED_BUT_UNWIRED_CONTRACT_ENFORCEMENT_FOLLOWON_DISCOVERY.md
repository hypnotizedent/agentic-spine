# Declared But Unwired Contract Enforcement — Follow-On Discovery

## Parent Loop Id

- `LOOP-SPINE-CLOSURE-AND-AGENTIC-CORE-STABILIZATION-20260326`

## Concern Id

- `post-h2.declared-but-unwired-contract-enforcement-followon`

## Live Post-Tranche Governance-Core Posture Summary

- `2026-03-29`: tranche-1 contract-enforcement implementation landed at `3d96c11f`; translator-authority implementation landed at `b193da58` and truthfully handed priority back to this follow-on concern.
- `ops/bindings/authority.concerns.yaml` is absent in the live repo. Standalone `bash surfaces/verify/d422-translator-authority-isolation-lock.sh` still fails at check `4/4` with `authority.concerns.yaml not found`.
- `ops/bindings/gate.registry.yaml` still declares D422 as an active `enforce` / `invariant` gate. `ops/bindings/gate.execution.topology.yaml` still assigns D422 to the `core` domain, but `core_mode.core_gate_ids` includes `D425` and `D427` and omits `D422`.
- `./bin/ops cap run verify.fast -- --json` passes `30 total / 30 pass / 0 fail / 0 warn`, and `ops/plugins/core/verify/bin/verify-run fast --json` passes `27 total / 27 pass / 0 fail / 0 warn`; neither surfaced D422 because the current fast-pack path does not execute it.
- D425 and D427 remain healthy and aligned: standalone `bash surfaces/verify/d425-governed-change-lifecycle-stage-evidence-lock.sh` and `bash surfaces/verify/d427-session-governance-contract-parity-lock.sh` both pass.
- `ops/bindings/prompt.registry.yaml` still declares `role_prompt_sets`, but no live consumer surface reads them. `ops/commands/cap.sh` reads only capability `defaults` / `capability_overrides` / `source_refs` prompt lineage.
- `ops/bindings/prompt.library.contract.yaml` now truthfully records seeded-but-unconsumed prompt copies. `ops/plugins/core/context/bin/prompt-library-bootstrap` only seeds `.runtime/spine/state/prompts/`, and `ops/plugins/core/session/bin/session-v3-attach` still does not load templates or runtime prompt copies.
- `ops/bindings/communication.protocol.contract.yaml` still declares typed handoffs, but no live consumer surface implements those structured message types programmatically.
- `ops/bindings/spine.surface.metabolism.registry.yaml` is now stale relative to live repo truth: it still says `NORTH_STAR.md` is missing even though `NORTH_STAR.md` exists, and its gate counts predate D425-D427 landing.
- Earlier discovery truth must be narrowed before the next stage:
  - the tranche-1-era assumption that translator authority was already coherently machine-enforced is stale because D422 is active only as a failing standalone gate and is absent from fast-pack execution;
  - the earlier translator-authority finding that `prompt.library.contract.yaml` carried a false `runtime_bound` claim is now resolved and no longer belongs to this concern.

## Exact Residue Table For Named Remaining Surfaces

| Surface | Live Truth | Residue Class | Why It Still Matters |
|---|---|---|---|
| `ops/bindings/authority.concerns.yaml` | Missing from live repo; archived predecessor still exists under `ops/bindings/archive/pre-consolidation/authority.concerns.yaml` and contains `translator_authority_surfaces` | `structural_gate_dependency_and_pack_alignment` | D422, D406, authority projection tooling, routing/projection metadata, and translator contract isolation guards still name this authority surface. |
| `surfaces/verify/d422-translator-authority-isolation-lock.sh` | Active standalone enforce gate; passes checks 1-3 and fails on missing `authority.concerns.yaml` | `structural_gate_dependency_and_pack_alignment` | Confirms the missing dependency is real and that translator isolation is not coherently enforced today. |
| `ops/bindings/gate.registry.yaml` + `ops/bindings/gate.execution.topology.yaml` + `ops/bindings/verify.run.profile.contract.yaml` + `ops/capabilities.yaml` | Registry says D422 is active, topology assigns it to `core`, but `core_mode.core_gate_ids` omits it and `verify.fast` / `verify-run fast` both pass without executing it | `structural_gate_dependency_and_pack_alignment` | This is the first-class standalone-vs-pack enforcement mismatch. |
| `ops/plugins/core/authority/bin/authority-concerns-projection-build` + `surfaces/verify/d406-concern-projection-registration-completeness-lock.sh` + `ops/bindings/single.authority.contract.yaml` | Live tooling still depends on `ops/bindings/authority.concerns.yaml` as canonical input | `structural_gate_dependency_and_pack_alignment` | Shows the D422 failure is not just one missing file; it fans out into the authority projection chain. |
| `ops/bindings/prompt.registry.yaml` (`role_prompt_sets`) | Declared only; no read path found in `cap.sh`, `session-v3-attach`, or `prompt-library-bootstrap` | `prompt_runtime_registry_semantics` | Still declared-but-unwired, but not part of the structural D422 seam. |
| `ops/bindings/prompt.library.contract.yaml` + `ops/plugins/core/context/bin/prompt-library-bootstrap` + `.runtime/spine/state/prompts/` + `ops/plugins/core/session/bin/session-v3-attach` | Prompt-library posture is now truthful: canonical templates seed decorative runtime copies; no live consumer loads them | `prompt_runtime_registry_semantics` | Consumer wiring and freshness remain separate from governance-core gate alignment. |
| `ops/bindings/communication.protocol.contract.yaml` | Structured handoff schema remains declarative; no runtime consumer path implements `normalized_request` / `execution_receipt` / `status_rendering` | `communication_protocol_runtime_handoffs` | Still declared-but-unwired, but would require a different runtime slice. |
| `ops/bindings/spine.surface.metabolism.registry.yaml` | Still carries stale factual posture (`NORTH_STAR.md` missing, stale gate counts) | `posture_metadata_and_cross_surface_drift` | Real drift, but cleanup does not close the D422 / fast-pack enforcement seam. |

## Candidate Tranche Breakdown

### `structural_gate_dependency_and_pack_alignment`

- Exact included surfaces:
  - `ops/bindings/authority.concerns.yaml`
  - `surfaces/verify/d422-translator-authority-isolation-lock.sh`
  - `ops/bindings/gate.registry.yaml`
  - `ops/bindings/gate.execution.topology.yaml`
  - `ops/bindings/verify.run.profile.contract.yaml`
  - `ops/capabilities.yaml` (`verify.core.run`, `verify.fast`)
  - `ops/plugins/core/authority/bin/authority-concerns-projection-build`
  - `ops/bindings/single.authority.contract.yaml`
  - `surfaces/verify/d406-concern-projection-registration-completeness-lock.sh`
- Why it is bounded:
  - Every implicated surface sits on the same core governance-enforcement path: authority-concern source truth, its projection/dependency chain, and the fast verify execution path that should expose D422.
- Tranche type:
  - `contract/gate wiring`
- Why it should go first:
  - It resolves the newly surfaced enforcement contradiction directly: an active governance gate fails standalone while the fast-pack path still reports green. That is the smallest high-leverage seam left in this concern.

### `prompt_runtime_registry_semantics`

- Exact included surfaces:
  - `ops/bindings/prompt.registry.yaml`
  - `ops/bindings/prompt.library.contract.yaml`
  - `ops/plugins/core/context/bin/prompt-library-bootstrap`
  - `ops/plugins/core/session/bin/session-v3-attach`
  - `.runtime/spine/state/prompts/`
  - `ops/commands/cap.sh`
- Why it is bounded:
  - All surfaces live on prompt-template declaration, seeding, freshness, and runtime-consumption semantics.
- Tranche type:
  - `consumer/runtime wiring`
- Why it should not go first:
  - Translator-authority unification already separated this seam as a later `ordinary_fix` or separate runtime-wiring decision. It does not reduce the D422 / pack-alignment enforcement contradiction.

### `communication_protocol_runtime_handoffs`

- Exact included surfaces:
  - `ops/bindings/communication.protocol.contract.yaml`
  - `ops/bindings/operator.boundary.contract.yaml`
  - `ops/bindings/controller.boundary.contract.yaml`
  - any future runtime dispatch / receipt surfaces that would actually emit the typed message objects
- Why it is bounded:
  - All surfaces live on typed Operator→Translator→Controller message handoff implementation.
- Tranche type:
  - `consumer/runtime wiring`
- Why it should not go first:
  - No live runtime consumer path exists yet. Landing this before structural verify alignment would silently broaden the concern into translator/runtime implementation.

### `posture_metadata_and_cross_surface_drift`

- Exact included surfaces:
  - `ops/bindings/spine.surface.metabolism.registry.yaml`
  - any status docs or scout artifacts whose factual counts or file-existence claims now drift from live truth
- Why it is bounded:
  - It is a posture-correction slice only.
- Tranche type:
  - `posture/dependency cleanup`
- Why it should not go first:
  - It improves factual cleanliness but does not restore governance-core enforcement coherence.

### `defer_or_out_of_scope`

- Exact included surfaces:
  - prompt-runtime freshness sync
  - `role_prompt_sets` consumer wiring or removal
  - `session-v3-attach` template loading
  - communication-protocol runtime handoffs
  - Claude/Cowork adapter work
  - authoritative cross-surface state synthesis / autonomous multi-node follow-on
- Why it is bounded:
  - These are separate already-classified seams, each with different governing boundaries.
- Tranche type:
  - `mixed and therefore bad tranche design`
- Why it should not go first:
  - Pulling them into this concern would silently reopen translator-authority work or autonomy work instead of closing the next governance-core enforcement seam.

## Exact Recommended Next Tranche

- `structural_gate_dependency_and_pack_alignment`

Recommended shape:

- Treat the missing `authority.concerns.yaml` as one dependency symptom inside a broader structural alignment slice, not as a one-file patch by itself.
- Freeze the next write boundary around the authority-concern source/projection chain plus the fast verify execution path that should expose D422 truthfully.
- Keep prompt/runtime semantics, typed protocol handoffs, and cross-surface synthesis outside this tranche.

## Explicit Handling Of D422 Dependency Drift

- The missing `ops/bindings/authority.concerns.yaml` is not the next tranche by itself.
- It is one visible symptom of a broader structural alignment seam because live repo surfaces beyond D422 still depend on it:
  - `ops/plugins/core/authority/bin/authority-concerns-projection-build`
  - `surfaces/verify/d406-concern-projection-registration-completeness-lock.sh`
  - `ops/bindings/translator.authority.contract.yaml`
  - `ops/bindings/gate.domain.profiles.yaml`
  - `ops/bindings/routing.dispatch.yaml`
- The archived pre-consolidation contract proves the concern family existed before; discovery does not authorize restoring or rewriting it yet.

## Explicit Handling Of Verify-Pack Vs Standalone-Gate Alignment

- The standalone-vs-pack mismatch is a first-class enforcement problem.
- Live truth today is contradictory:
  - D422 is active and enforce-mode in `gate.registry.yaml`;
  - D422 is assigned to `core` in `gate.execution.topology.yaml`;
  - D422 is omitted from `core_mode.core_gate_ids`;
  - `verify.fast` capability still dispatches `verify-topology core`;
  - `verify-run fast` also resolves without D422.
- This means the fast verify path can report green while the standalone gate for the same governance concern still fails. That contradiction is the strongest reason to take structural alignment first.

## Explicit Handling Of Prompt/Runtime And Protocol Deferred Surfaces

- `role_prompt_sets` stay outside this concern now. They remain declared-but-unwired and are not needed to restore governance-core gate coherence.
- Prompt-library runtime freshness sync stays outside this concern now. The false `runtime_bound` claim is already corrected; what remains is a separate consumer/freshness issue, not the next governance-core enforcement tranche.
- `session-v3-attach` template loading stays outside this concern now. No live evidence in this pass shows it must move ahead of structural gate alignment.
- Communication-protocol typed handoffs stay outside this concern now. They remain declarative only and would require a separate runtime slice.
- Authoritative cross-surface state synthesis stays separate. Nothing in this discovery shows it must supersede the follow-on contract-enforcement concern.

## Explicit Dated Timeline

| Date | Stage | Deliverable | Dependency | Slip Condition |
|---|---|---|---|---|
| 2026-03-29 | implementation landed | D427 tranche-1 implementation landed at `3d96c11f` | prior discovery, decision, election completed | historical reference only |
| 2026-03-29 | priority override completed | translator-authority priority override landed at `b193da58` and handed back to this concern | translator-authority implementation verified and closed | historical reference only |
| 2026-03-29 | discovery | this artifact: remaining governance-core residue inventory, tranche candidates, and recommendation to take structural gate dependency and pack alignment first | clean synced baseline, live repo truth reproduced | conflicting live posture would have blocked landing |
| 2026-03-29 or next clean landing window | decision | freeze exact write boundary for the structural gate dependency and pack alignment slice | this discovery artifact committed and pushed, parent artifacts aligned | unresolved boundary between D422 recovery and broader authority-projection chain |
| 2026-03-29 or next clean landing window after decision | election | authorize or hold the structural gate dependency and pack alignment slice | decision artifact committed and pushed | operator review delay or newly surfaced dependency fan-out |
| after election | implementation target | bounded follow-on landing on the elected structural alignment surfaces only | election authorizes implementation | scope creep into prompt/runtime semantics, protocol wiring, or cross-surface synthesis |

## Open Questions For Decision Stage

- Should the next slice restore `ops/bindings/authority.concerns.yaml` directly from the archived concern map, or should D422 be narrowed away from that dependency instead?
- Must `ops/plugins/core/authority/bin/authority-concerns-projection-build` and `ops/bindings/single.authority.contract.yaml` land in the same slice as the authority-concern restore, or can they remain deferred without creating fresh drift?
- Should D422 be wired into `core_mode.core_gate_ids`, should `verify.fast` / `verify.core.run` be normalized to the wrapper path, or do both changes belong in the same tranche?
- Is D406 part of the same structural alignment slice, or should this follow-on stop at D422 plus fast-pack coherence and leave projection-registration enforcement for the next tranche?
- What is the smallest truthful write set that makes standalone and fast-pack governance-core verification agree without reopening prompt/runtime or protocol implementation?

## Exact Proposed Next Action

- `declared_but_unwired_contract_enforcement_followon_decision`

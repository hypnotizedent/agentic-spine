# Declared But Unwired Contract Enforcement — Follow-On D411 Blocker Discovery

## Parent Loop Id

- `LOOP-SPINE-CLOSURE-AND-AGENTIC-CORE-STABILIZATION-20260326`

## Concern Id

- `post-h2.declared-but-unwired-contract-enforcement-followon-d411-blocker`

## Blocked Implementation Summary

The follow-on election at `773ba854` authorized a bounded structural-alignment implementation slice covering:

- `ops/bindings/authority.concerns.yaml` (restore)
- `ops/bindings/single.authority.contract.yaml` (create)
- `ops/plugins/core/authority/bin/authority-concerns-projection-build` (existing)
- `surfaces/verify/d406-concern-projection-registration-completeness-lock.sh` (existing)
- `surfaces/verify/d422-translator-authority-isolation-lock.sh` (existing)
- `ops/bindings/gate.registry.yaml` (modify)
- `ops/bindings/gate.execution.topology.yaml` (modify)
- `ops/bindings/gate.domain.profiles.yaml` (modify)

The local blocked implementation attempt proved:

| Check | Outcome |
|---|---|
| `authority.concerns.yaml` created and valid | PASS |
| `single.authority.contract.yaml` created and valid | PASS |
| `authority-concerns-projection-build --check --verify` | PASS |
| Standalone D406 | PASS |
| Standalone D422 | PASS |
| D406/D422 added to `core_mode.core_gate_ids` | PASS (local) |
| `verify.fast` with D406/D422 in core pack | FAIL (D411) |
| `git commit` with staged `gate.domain.profiles.yaml` | BLOCKED by pre-commit D411 |
| Deferred surfaces unchanged | PASS |

No repo-owned implementation commit landed. HEAD remained at `773ba854`.

## Exact D411-Coupled Residue Table

### D411 Pre-Commit Enforcement Mechanism

The canonical pre-commit hook (`.githooks/pre-commit`) enforces D411 via staged-file trigger:

**D411 Input Files** (any staged triggers the check):

| Input | In elected write set? |
|---|---|
| `ops/capabilities.yaml` | no (deferred) |
| `ops/bindings/capability_map.yaml` | no (deferred) |
| `ops/bindings/agents.registry.yaml` | no (deferred) |
| `ops/bindings/terminal.role.contract.yaml` | no (deferred) |
| `ops/bindings/gate.domain.profiles.yaml` | **yes** |
| `ops/bindings/gate.agent.profiles.yaml` | no (deferred) |
| `ops/bindings/service.endpoint.catalog.yaml` | no (deferred) |
| `ops/plugins/core/ops/bin/gen-terminal-worker-runtime-v2.py` | no (deferred) |

When triggered, D411 delegates to `ops/plugins/core/verify/bin/worker-projection-audit`, which runs `--check` on all 4 governed wrapper scripts.

**D411 Required Tracked Outputs** (must be fresh in the same commit):

| Target | Tracked Output | Generator Wrapper |
|---|---|---|
| catalog | `ops/bindings/terminal.worker.catalog.yaml` | `ops/plugins/core/ops/bin/gen-worker-catalog.sh` |
| dispatch | `ops/bindings/routing.dispatch.yaml` | `ops/plugins/core/ops/bin/gen-routing-dispatch.sh` |
| launcher | `ops/bindings/terminal.launcher.view.yaml` | `ops/plugins/core/ops/bin/gen-launcher-view.sh` |
| usage | `docs/reference/generated/worker-usage/` | `ops/plugins/core/ops/bin/gen-worker-usage-docs.sh` |

All 4 outputs exist on disk and are version-controlled. The master generator is `ops/plugins/core/ops/bin/gen-terminal-worker-runtime-v2.py`. The projection contract is `ops/bindings/terminal.worker.projection.contract.yaml`.

### Why D411 Blocked the Structural-Alignment Commit

1. The structural-alignment slice modifies `ops/bindings/gate.domain.profiles.yaml` to add D406 and D422 to `core_mode.core_gate_ids`.
2. `gate.domain.profiles.yaml` is an explicit D411 input in the pre-commit hook.
3. Staging it triggers D411, which runs `worker-projection-audit`.
4. `worker-projection-audit` runs all 4 generator wrappers with `--check` and detects tracked output drift.
5. The commit is blocked because the tracked outputs are not included in the staged set.

### D411 In Core Pack Enforcement

- `gate.execution.topology.yaml`: D411 is in `core_mode.core_gate_ids` (present since before the election).
- `gate.domain.profiles.yaml`: D411 is in `domains.core.gate_ids`.
- `verify.fast` and `verify.core.run` include D411 in the core pack.
- D411 currently **passes** on HEAD (`773ba854`) because the tracked outputs match the current generator inputs.
- Modifying `gate.domain.profiles.yaml` changes generator inputs, causing tracked output drift.

## Worker-Projection Ownership Summary

| Surface | Owner | Type |
|---|---|---|
| `terminal.worker.projection.contract.yaml` | `@ronny` | Authority contract |
| `gen-terminal-worker-runtime-v2.py` | Core generator | Master generator |
| `gen-worker-catalog.sh` | Core wrapper | Wrapper for catalog target |
| `gen-routing-dispatch.sh` | Core wrapper | Wrapper for dispatch target |
| `gen-launcher-view.sh` | Core wrapper | Wrapper for launcher target |
| `gen-worker-usage-docs.sh` | Core wrapper | Wrapper for usage target |
| `worker-projection-audit` | Core verify | Python audit script |
| `d411-terminal-worker-projection-lock.sh` | Gate surface | Shell gate delegating to audit |
| `terminal.worker.catalog.yaml` | Tracked projection | Generated output |
| `routing.dispatch.yaml` | Tracked projection | Generated output |
| `terminal.launcher.view.yaml` | Tracked projection | Generated output |
| `docs/reference/generated/worker-usage/` | Tracked projection | Generated output directory (20 docs) |

## Candidate Tranche Breakdown

### Candidate 1: `worker_projection_dependency_alignment`

- **Included surfaces**: Only the 4 tracked outputs and their generators (regeneration via `--apply`)
- **Boundary**: Regenerate tracked outputs to match current inputs without modifying any structural surface
- **Type**: Generated worker-projection alignment only
- **Assessment**: This tranche alone does not unblock the structural-alignment slice because the structural slice is what triggers the need. Running `--apply` on HEAD without structural changes would produce no drift because D411 already passes. This tranche is only useful *after* or *alongside* the structural modification. **Not bounded as a standalone concern.**
- **Recommendation**: Not viable standalone.

### Candidate 2: `combined_structural_and_worker_projection_alignment`

- **Included surfaces**: All 8 elected structural surfaces + regeneration of all 4 tracked outputs
- **Boundary**: The structural-alignment slice from the prior election, widened to include mechanical regeneration of worker-projection outputs in the same commit
- **Type**: Mixed structural/gate alignment + generated worker-projection alignment
- **Assessment**: The only tranche that produces a landable commit. The worker-projection regeneration is a mechanical consequence of modifying a D411 input, not a separate semantic concern. The generators already exist and work. The regeneration is not capability rewiring — it is a deterministic rebuild from existing inputs. The risk is that regeneration could surface further drift from unrelated input changes, but the implementation status confirmed that only D411 failed (not any other gate). **Bounded and necessary.**
- **Recommendation**: Recommended next tranche.

### Candidate 3: `terminal_worker_projection_governance_separation`

- **Included surfaces**: `.githooks/pre-commit` D411 input list, possibly `gate.domain.profiles.yaml` path trigger set
- **Boundary**: Remove `gate.domain.profiles.yaml` from the D411 pre-commit input list so that structural-alignment changes do not trigger D411 regeneration
- **Type**: Governance boundary change
- **Assessment**: This would weaken D411 enforcement. `gate.domain.profiles.yaml` is legitimately a D411 input because it is consumed by the worker-projection generators (it defines which gates are in which domains, which affects how workers are cataloged and dispatched). Removing it would create a governance hole. **Not recommended.**
- **Recommendation**: Rejected — weakens enforcement.

### Candidate 4: `defer_or_out_of_scope`

- **Included surfaces**: None
- **Boundary**: Defer the structural-alignment slice entirely and pursue a different concern
- **Type**: Deferral
- **Assessment**: The structural-alignment slice remains truthful and mechanically achievable. The only blocker is the need to include worker-projection regeneration. Deferral would leave D406/D422 absent from the core pack indefinitely. **Not recommended.**
- **Recommendation**: Not justified.

## Exact Recommended Next Tranche

- `combined_structural_and_worker_projection_alignment`

### Rationale

The D411 pre-commit enforcement boundary is correct: `gate.domain.profiles.yaml` is a legitimate D411 input because it feeds worker-projection generators. The structural-alignment slice necessarily modifies this file. Therefore the implementation boundary must be widened to include mechanical regeneration of all 4 tracked worker-projection outputs. This is not a new semantic concern — it is the same structural-alignment concern with an enforcement-mandated write set expansion.

### Explicit Handling of the Prior Structural-Alignment Slice

- The prior elected structural-alignment boundary remains correct and fully included.
- The write set is widened by 4 regenerated tracked outputs (or their containing paths), not replaced.
- The prior election's authorization is not invalidated — it is refined by this discovery.

### Explicit Handling of D411 and Worker-Projection Outputs

- D411 enforcement is correct and must not be weakened.
- The 4 tracked outputs must be regenerated via `--apply` after structural modifications are complete, then staged alongside the structural changes.
- The regeneration is deterministic from existing generator machinery.
- No generator modification is needed.
- No worker-projection contract modification is needed.

### Explicit Handling of Deferred Concerns

- Capability-definition rewiring remains deferred. The regeneration uses existing capabilities as generator inputs — it does not modify `ops/capabilities.yaml`.
- Prompt/runtime semantics remain separate. No prompt registry, session-v3-attach, or prompt-library-bootstrap surfaces are involved.
- Protocol runtime handoffs remain separate. No communication-protocol surfaces are involved.
- Cross-surface state synthesis remains separate. No metabolism registry or cross-surface coordinator surfaces are involved.

## Dated Timeline

| Date | Stage | Exact Deliverable | Dependency | Slip Condition |
|---|---|---|---|---|
| 2026-03-29 | election landed | Follow-on election at `773ba854` authorized structural-alignment slice | Prior discovery + decision | Already landed |
| 2026-03-29 | implementation blocked | Structural-alignment implementation blocked by D411 pre-commit enforcement; no repo-owned commit | Election authorization | D411 pre-commit trigger on `gate.domain.profiles.yaml` required deferred tracked outputs |
| 2026-03-29 | blocker discovery | This D411 blocker discovery artifact lands with residue inventory and tranche recommendation | Blocked implementation status as evidence | Discovery could not land if blocked implementation evidence were unavailable |
| 2026-03-29 or next clean landing window | blocker decision | Decision on whether to widen the structural-alignment boundary to include worker-projection regeneration | This discovery artifact committed and pushed | Material change to D411 enforcement mechanism or generator machinery before decision |
| 2026-03-29 or next clean landing window after decision | blocker election | Election ratifying the combined structural + worker-projection implementation boundary | Decision artifact committed and pushed | Discovery of additional D411-coupled surfaces not identified here |
| After election | bounded implementation | Restore authority concerns, create compatibility contract, align gates into core pack, regenerate all 4 worker-projection tracked outputs, land as single governed commit | Election authorization of widened boundary | Generator failures, additional pre-commit enforcement blockers, or scope creep into deferred concerns |

## Open Questions for Decision Stage

1. Should the implementation commit include `git add` of all 4 tracked output paths, or should a pre-implementation verification pass first confirm that regeneration produces only expected changes?
2. Does the widened write set require a formal re-election, or does the decision stage's ratification of the discovery finding suffice?
3. Are there any other pre-commit enforcement surfaces that would fire when the combined set is staged?

## Exact Proposed Next Action

- `declared_but_unwired_contract_enforcement_followon_d411_blocker_decision`

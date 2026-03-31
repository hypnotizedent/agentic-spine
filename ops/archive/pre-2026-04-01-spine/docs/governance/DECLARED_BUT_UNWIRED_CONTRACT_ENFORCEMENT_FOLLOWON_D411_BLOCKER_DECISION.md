# Declared But Unwired Contract Enforcement — Follow-On D411 Blocker Decision

## Parent Loop Id

- `LOOP-SPINE-CLOSURE-AND-AGENTIC-CORE-STABILIZATION-20260326`

## Concern Id

- `post-h2.declared-but-unwired-contract-enforcement-followon-d411-blocker`

## Authoritative Blocker Discovery Artifact Path

- `docs/governance/DECLARED_BUT_UNWIRED_CONTRACT_ENFORCEMENT_FOLLOWON_D411_BLOCKER_DISCOVERY.md` (commit `b66134a6`)

## Live Blocker Recheck Summary

- Branch: `main`, HEAD: `b66134a6`, clean, synced `0/0`
- `./bin/ops cap run verify.fast -- --json`: PASS (`30 total / 30 pass / 0 fail / 0 warn`)
- `bash surfaces/verify/d411-terminal-worker-projection-lock.sh`: PASS (`4 governed surfaces`)
- D411 currently passes on HEAD because tracked outputs match current generator inputs
- `gate.domain.profiles.yaml` remains in the pre-commit D411 input list (`.githooks/pre-commit` line 98)
- `worker-projection-audit` still binds all 4 tracked outputs to their 4 generator wrappers
- No repo-owned implementation commit landed after the blocked attempt; HEAD is `b66134a6` (blocker discovery only)
- Prompt/runtime semantics, protocol runtime handoffs, and cross-surface synthesis remain outside this seam

## Exact Tranche Decision

- `combined_structural_and_worker_projection_alignment`

### Rationale

The structural-alignment slice necessarily modifies `gate.domain.profiles.yaml`. This file is a legitimate D411 input because the worker-projection generators consume gate domain topology to produce worker catalog, routing dispatch, launcher view, and usage documentation. The pre-commit hook enforces D411 when any D411 input is staged. Therefore the implementation must widen the write set to include mechanical regeneration of all 4 tracked worker-projection outputs in the same commit.

This is not a new semantic concern. It is the same structural-alignment concern with an enforcement-mandated write set expansion. The generators are not modified. The projection contract is not modified. The regeneration is deterministic from existing machinery applied to the modified gate topology.

### Decision on Discovery Open Questions

1. **Should implementation include `git add` of all 4 tracked output paths, or pre-verify first?**
   Decision: Implementation should regenerate all 4 tracked outputs via `--apply`, then stage them alongside the structural changes. A pre-implementation dry run (`--check`) is recommended but not mandatory — the pre-commit D411 enforcement itself provides the safety gate.

2. **Does the widened write set require a formal re-election?**
   Decision: Yes. A formal blocker election is required because the write set is materially wider than what the prior election authorized. The prior election explicitly listed `routing.dispatch.yaml` as a deferred surface. The blocker election ratifies the widened boundary.

3. **Are there other pre-commit enforcement surfaces that fire when the combined set is staged?**
   Decision: The pre-commit hook runs D30, D31, D42, D44, D46, D47, D48 (lane), D58, D84, D85, D150, D411 (staged input trigger), and a mirror-sanitization canary. Of these, D85 (gate-registry-parity) checks consistency between the gate registry and the gate execution topology — both are in the structural write set, so the implementation must ensure they remain consistent. No other pre-commit gate is expected to fire from the combined set. D85 is already accounted for in the structural-alignment design.

## Exact Widened Implementation Boundary

### In-Scope Implementation Surfaces (write set)

| Surface | Action | Prior election status |
|---|---|---|
| `ops/bindings/authority.concerns.yaml` | restore/create | in prior election |
| `ops/bindings/single.authority.contract.yaml` | create | in prior election |
| `ops/bindings/gate.registry.yaml` | modify (add D406, D422) | in prior election |
| `ops/bindings/gate.execution.topology.yaml` | modify (add D406, D422 to core_mode) | in prior election |
| `ops/bindings/gate.domain.profiles.yaml` | modify (add D406, D422 to core domain) | in prior election |
| `ops/bindings/terminal.worker.catalog.yaml` | regenerate via `gen-worker-catalog.sh --apply` | **widened by D411** |
| `ops/bindings/routing.dispatch.yaml` | regenerate via `gen-routing-dispatch.sh --apply` | **widened by D411** |
| `ops/bindings/terminal.launcher.view.yaml` | regenerate via `gen-launcher-view.sh --apply` | **widened by D411** |
| `docs/reference/generated/worker-usage/` | regenerate via `gen-worker-usage-docs.sh --apply` | **widened by D411** |

### Read-Only Support Surfaces (not modified, used during implementation)

| Surface | Role |
|---|---|
| `ops/plugins/core/authority/bin/authority-concerns-projection-build` | Projection builder for authority concerns |
| `surfaces/verify/d406-concern-projection-registration-completeness-lock.sh` | Standalone D406 verification |
| `surfaces/verify/d422-translator-authority-isolation-lock.sh` | Standalone D422 verification |
| `surfaces/verify/d411-terminal-worker-projection-lock.sh` | Standalone D411 verification |
| `ops/plugins/core/verify/bin/worker-projection-audit` | D411 audit script |
| `ops/bindings/terminal.worker.projection.contract.yaml` | Projection governance contract |
| `ops/plugins/core/ops/bin/gen-terminal-worker-runtime-v2.py` | Master generator |
| `ops/plugins/core/ops/bin/gen-worker-catalog.sh` | Catalog wrapper |
| `ops/plugins/core/ops/bin/gen-routing-dispatch.sh` | Dispatch wrapper |
| `ops/plugins/core/ops/bin/gen-launcher-view.sh` | Launcher wrapper |
| `ops/plugins/core/ops/bin/gen-worker-usage-docs.sh` | Usage wrapper |
| `.githooks/pre-commit` | Pre-commit enforcement |

### Exact Deferred Surfaces

| Surface | Reason |
|---|---|
| `ops/capabilities.yaml` | Capability-definition rewiring remains deferred |
| `ops/bindings/verify.run.profile.contract.yaml` | Outside structural concern |
| `ops/bindings/prompt.registry.yaml` | Prompt/runtime semantics remain separate |
| `ops/bindings/prompt.library.contract.yaml` | Prompt/runtime semantics remain separate |
| `ops/plugins/core/session/bin/session-v3-attach` | Template loading remains separate |
| `ops/bindings/communication.protocol.contract.yaml` | Protocol runtime handoffs remain separate |
| `ops/bindings/spine.surface.metabolism.registry.yaml` | Cross-surface synthesis remains separate |
| `ops/bindings/master.inventory.registry.yaml` | Outside structural concern |
| `ops/bindings/domain.projection.contract.yaml` | Outside structural concern |

### Exact Non-Goals

- No generator code modification in the implementation pass.
- No worker-projection contract modification in the implementation pass.
- No capability-definition rewiring.
- No prompt/runtime semantics absorption.
- No protocol runtime handoff absorption.
- No cross-surface state synthesis absorption.
- No D411 enforcement weakening.
- No `.githooks/pre-commit` modification.
- No election or implementation in this decision pass.

### Explicit Decision: Generator Code Write Scope

- All generator code is read-only support. The implementation pass invokes the existing generators via `--apply` but does not modify them.

### Explicit Decision: Tracked Outputs in Same Commit

- Yes. All 4 tracked worker-projection outputs must land in the same governed commit as the structural surfaces. This is required by D411 pre-commit enforcement: staging `gate.domain.profiles.yaml` triggers the D411 check, which requires all tracked outputs to be fresh.

### Explicit Decision: `terminal.worker.projection.contract.yaml`

- Read-only support. The projection contract is not modified. It defines the governance relationship between generators and tracked outputs, which remains unchanged.

### Explicit Decision: Capability-Definition Rewiring

- Remains deferred. The regeneration consumes `ops/capabilities.yaml` as a read-only input. Capability definitions are not modified by this slice. If regeneration reveals that capability definitions are materially stale and block a clean rebuild, the implementation pass must stop and report rather than absorbing capability rewiring.

## Timeline

| Date | Stage | Exact Deliverable | Dependency | Slip Condition |
|---|---|---|---|---|
| 2026-03-29 | election landed | Follow-on election at `773ba854` | Prior discovery + decision | Already landed |
| 2026-03-29 | implementation blocked | No repo commit; D411 pre-commit enforcement on `gate.domain.profiles.yaml` | Election authorization | Already recorded |
| 2026-03-29 | blocker discovery landed | `b66134a6` | Blocked implementation status | Already landed |
| 2026-03-29 | blocker decision landed | This artifact with exact widened boundary | Blocker discovery committed and pushed | Material live posture drift before decision (none observed) |
| 2026-03-29 or next clean landing window | blocker election | Election ratifying the combined structural + worker-projection implementation boundary | Decision artifact committed and pushed | Discovery of additional D411-coupled surfaces not identified here, or material change to pre-commit enforcement |
| After election | bounded implementation | Restore authority concerns, create compatibility contract, align D406/D422 into core pack, regenerate all 4 tracked outputs, land as single governed commit | Election authorization of widened boundary | Generator failures, additional pre-commit enforcement blockers, capability-definition staleness forcing scope expansion, or scope creep into deferred concerns |
| After implementation closes | separate follow-on work | Remaining prompt/runtime, protocol, posture-drift, and downstream cross-surface concerns resume through their own classified passes | Structural + worker-projection slice verified and closed | Residual failures show a different truthful follow-on seam |

## Exact Proposed Next Action

- `declared_but_unwired_contract_enforcement_followon_d411_blocker_election`

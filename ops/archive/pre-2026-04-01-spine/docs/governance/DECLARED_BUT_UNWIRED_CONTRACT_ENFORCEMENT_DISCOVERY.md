---
title: Declared But Unwired Contract Enforcement — Discovery
parent_loop_id: LOOP-SPINE-CLOSURE-AND-AGENTIC-CORE-STABILIZATION-20260326
concern: post-h2.declared-but-unwired-contract-enforcement
stage: discovery
version: 1
updated_at: 2026-03-29
machine_enforcement: not_yet_machine_enforced
source_triangulation:
  - ops/bindings/spine.surface.metabolism.registry.yaml
  - ops/bindings/governed.change.lifecycle.contract.yaml
  - ops/bindings/governance.profile.contract.yaml
  - ops/bindings/session.admission.contract.yaml
  - ops/bindings/root.authority.contract.yaml
  - ops/bindings/node.role.contract.yaml
  - ops/bindings/terminal.role.contract.yaml
  - ops/bindings/spine.self-governance.lifecycle.contract.yaml
  - ops/bindings/verify.run.profile.contract.yaml
  - ops/bindings/verify.failure.classification.contract.yaml
---

# Declared But Unwired Contract Enforcement — Discovery

## Parent Loop

- `LOOP-SPINE-CLOSURE-AND-AGENTIC-CORE-STABILIZATION-20260326`

## Problem Statement

The metabolism registry classifies `governance_core` as `active_not_yet_machine_enforced` and
recommends `declared_but_unwired_contract_enforcement` as the next action. The spine has ~106
contract YAML files, but only ~19% are machine-enforced by verify gates. The remaining ~81%
declare governance truth that nothing checks at gate time, creating a trust-only posture for
most governance surfaces.

## Baseline

- Repo: `/Users/ronnyworks/code/agentic-spine`
- Branch: `main`
- HEAD: `2b8a64f8`
- Ahead/behind: `0 / 0`
- Working tree: clean

## Live Posture Reproduction (Spine Engine Capability Outputs)

### session.v3.attach

- Session: `SES-20260329-071011-scan-3d7877`
- Lane: `scan` (root_main_integration)
- Capability count: 804
- Friction queued: 0
- Lifecycle issues: 0

### spine.control.tick --fast --json

- Open loops: 8
- Open gaps: 43
- Friction: 763 total, 0 queued, 597 filed, 5 matched
- Scheduler: error (9 failed jobs, 1 unknown)
- Verify: 0 current failed runs

### spine.self-governance.status

- Status: FAIL
- 2 failures: projection_parity drift (workflow.vocabulary.catalog.yaml, spine.self-governance.lifecycle.projected.yaml), missing loop scope (LOOP-SPINE-SELF-GOVERNANCE-LIFECYCLE-CANONICALIZATION-20260321)
- 1 warning: dormancy_candidates (15 capabilities, 15 gates)
- Pre-existing conditions, not caused by this concern

### verify.fast --json

- Total: 29 gates
- Pass: 28
- Fail: 0
- Warn: 1 (D127)
- D425 (stage evidence durability): PASS
- D426 (layer classification): PASS

## Enforcement Classification Inventory

Source: metabolism registry aggregate counts, reconciled against gate registry and plugin script references.

### Aggregate Posture (from metabolism registry)

| Category | Count | Percentage |
|---|---|---|
| Machine-enforced (verify gated) | ~50 | ~19% |
| Runtime-consumed (scripts reference, no gate) | ~80 | ~31% |
| Semantic-only (declared, nothing checks) | ~100 | ~38% |
| Inactive | ~32 | ~12% |

### Machine-Enforced Contract Surfaces (Already Gated)

These contracts have at least one verify gate enforcing their invariants:

- `governed.change.lifecycle.contract.yaml` — D425 (stage evidence durability only; route/stage sequencing not yet gated)
- `terminal.role.contract.yaml` — D135 (naming enforcement)
- `verify.run.profile.contract.yaml` — consumed by verify-run topology
- `entry.surface.contract.yaml` — gate-referenced
- `fabric.boundary.contract.yaml` — gate-referenced
- `translator.authority.contract.yaml` — D422 (translator isolation)
- `secrets.enforcement.contract.yaml` — gated
- `launchd.runtime.contract.yaml` — gated

Note: D425 covers `governed.change.lifecycle.contract.yaml` stage evidence durability, but route classification,
stage sequencing, and pre-implementation gate enforcement are NOT yet machine-enforced.

### Runtime-Consumed But Not Gated (Category of Interest)

These contracts are actively read by session, lifecycle, or control-cycle scripts but have no verify gate enforcement:

| Contract | Consumers | Engine Relevance |
|---|---|---|
| `session.admission.contract.yaml` | session bootstrap, attach | critical |
| `governance.profile.contract.yaml` | session, policy guard | critical |
| `spine.self-governance.lifecycle.contract.yaml` | self-governance.status, lifecycle | critical |
| `verify.failure.classification.contract.yaml` | verify output classification | high |
| `root.authority.contract.yaml` | path resolution, runtime bootstrap | high |
| `node.role.contract.yaml` | authority matrix reference | medium |
| `role.runtime.control.contract.yaml` | terminal role defaults | medium |
| `policy.runtime.contract.yaml` | policy guard runtime | medium |
| `mailroom.runtime.contract.yaml` | mailroom paths, externalization | medium |
| `worktree.lifecycle.contract.yaml` | worktree provisioning | medium |
| `loop.closeout.contract.yaml` | loop closeout | medium |
| `wave.closeout.contract.yaml` | wave finalization | medium |
| `memory.continuity.contract.yaml` | session memory layer | medium |

### Semantic-Only (Declared, Nothing Checks)

~100 contracts declare governance truth with zero machine enforcement and zero runtime consumption.
These include domain-specific contracts, workbench surface contracts, network governance contracts,
and operator commitment contracts. They are the largest category but the lowest urgency for
enforcement because their violation would not corrupt engine behavior.

Representative examples:
- `network.crowdsec.contract.yaml`, `network.honeypot.contract.yaml`, `network.ids.tuning.contract.yaml`
- `cloudflare.advanced.scope.contract.yaml`, `tailscale.audit.log.contract.yaml`
- `workbench.operator.surface.contract.yaml`, `workbench.ssh.attach.contract.yaml`
- `operator.commitments.contract.yaml`, `planning.horizon.contract.yaml`
- `spine.vertical.integration.product.contract.yaml`, `vertical.integration.admission.contract.yaml`

### Inactive

~32 bindings appear inactive. These include archived pre-consolidation contracts and
never-activated domain surfaces. Not in scope for enforcement.

## Stale Posture Metadata Inventory

Six governance documents carry `machine_enforcement: not_yet_machine_enforced` in frontmatter:

| Document | Claim | Reality | Assessment |
|---|---|---|---|
| `GOVERNED_CHANGE_LIFECYCLE_PERSISTENCE_GATE_DISCOVERY.md` | `not_yet_machine_enforced` | D425 now enforces stage evidence | **STALE** |
| `LAYER_CLASSIFICATION_ELECTION.md` | `not_yet_machine_enforced` | D426 now enforces layer classification | **STALE** |
| `LAYER_CLASSIFICATION_DECISION.md` | `not_yet_machine_enforced` | D426 now enforces layer classification | **STALE** |
| `PLATFORM_LAYER_MODEL.md` | `not_yet_machine_enforced` | Layer implementation landed at `2b8a64f8` | **STALE** |
| `GIT_WORKFLOW_DISCIPLINE.md` | `not_yet_machine_enforced` | No gate enforcement; intentionally deferred | Accurate |
| `AUTONOMOUS_MULTI_NODE_VISION.md` | `not_yet_machine_enforced` | No gate enforcement; future concern | Accurate |

Four documents have stale metadata. Two are accurate.

## Capability Output vs Repo Truth Reconciliation

| Surface | Capability Output | Repo Truth | Agreement |
|---|---|---|---|
| verify.fast gate count | 29 | 29 (gate.execution.topology core_count_limit) | YES |
| D425 PASS | PASS | gate exists and is wired | YES |
| D426 PASS | PASS | gate exists and is wired | YES |
| self-governance projection parity | FAIL (drift) | projections exist but are stale | AGREE (pre-existing) |
| self-governance loop scope | FAIL (missing LOOP-...20260321) | scope file absent | AGREE (pre-existing) |
| metabolism governance_core state | `active_not_yet_machine_enforced` | ~81% of contracts unwired | AGREE |

No disagreement between capability output and repo truth for this concern.

## Candidate Tranches

### Tranche 1: Hot-Path Governance Contract Gate Enforcement

**Scope**: Add verify gate enforcement for the runtime-consumed governance contracts that
directly protect the engine hot path — session admission, governance profiles, change lifecycle
route/sequencing, and verify failure classification.

**Surfaces**:
- `session.admission.contract.yaml` — validate lane/profile/delivery parity
- `governance.profile.contract.yaml` — validate profile definitions match lane assignments
- `governed.change.lifecycle.contract.yaml` — extend D425 or add new gate for route classification and stage sequencing (beyond existing durability check)
- `verify.failure.classification.contract.yaml` — validate classification categories match verify output

**Write boundary**: New verify gate script(s), gate registry entries, topology/profile wiring.

**Why first**: These are the highest-leverage contracts — already consumed at runtime, violations
would go undetected, and they directly govern the engine's own change process and session model.

### Tranche 2: Authority-Chain and Terminal-Scope Enforcement

**Scope**: Add gate enforcement for the authority chain that governs path resolution,
node role boundaries, and terminal write scopes.

**Surfaces**:
- `root.authority.contract.yaml` — validate path taxonomy, no orphan root usage
- `node.role.contract.yaml` — validate authority matrix consistency
- `role.runtime.control.contract.yaml` — validate runtime role defaults

**Why deferred**: These contracts are structurally stable and rarely mutated. Their
enforcement is valuable but lower urgency than hot-path contracts.

### Tranche 3: Stale Posture Metadata Cleanup

**Scope**: Update `machine_enforcement` frontmatter in the four stale governance documents
to reflect current gate enforcement reality.

**Surfaces**:
- `docs/governance/GOVERNED_CHANGE_LIFECYCLE_PERSISTENCE_GATE_DISCOVERY.md`
- `docs/governance/LAYER_CLASSIFICATION_ELECTION.md`
- `docs/governance/LAYER_CLASSIFICATION_DECISION.md`
- `docs/governance/PLATFORM_LAYER_MODEL.md`

**Why deferred**: Metadata drift is real but cosmetic. It does not affect engine behavior.
Fixing it in a later tranche (or folded into tranche-1 if convenient) avoids scope creep.

### Tranche 4: Broader Semantic-Only Contract Enforcement

**Scope**: The ~100 semantic-only contracts. Too large for a single tranche. Would need
further sub-tranching by domain (network, workbench, domain-runtime, operator).

**Why deferred**: Low engine relevance. Violations of semantic-only contracts do not corrupt
engine behavior because nothing consumes them at runtime.

## Tranche-1 Recommendation

`hot_path_governance_contracts_first`

Rationale:
- Smallest high-leverage landing: 3-4 contracts, 1-2 new gates
- Directly reinforces the engine's own governance lifecycle
- Builds on D425 foundation (extends lifecycle contract enforcement beyond durability)
- Runtime consumers already exist — adding gates closes the trust-verify gap
- Does not require touching capability/domain/layer truth

## Surfaces That Should NOT Be In Tranche 1

- Stale posture metadata cleanup (cosmetic, not behavioral)
- Semantic-only contracts (no runtime consumption, low urgency)
- Domain-specific contracts (out of governance-core scope)
- Network/workbench/provider contracts (low engine relevance)
- Any capability, domain, or layer mutation

## Timeline

| Date | Stage | Deliverable | Dependency | Slip Condition |
|---|---|---|---|---|
| 2026-03-29 | discovery | This artifact with live posture inventory and tranche plan | Parent artifacts elect concern | None (landing now) |
| 2026-03-29 | decision | Exact tranche-1 boundary, write/gate boundary, deferred map | Discovery landed and pushed | Operator review delays |
| 2026-03-29 or next clean window | election | Authorization of tranche-1 implementation | Decision landed and pushed | Operator review delays |
| 2026-03-29 to 2026-03-30 | implementation | New gate(s) for hot-path contract enforcement | Election authorizes implementation | Pre-commit failures, gate design complexity |
| After tranche-1 receipts | follow-on | Tranche-2 (authority-chain) or tranche-3 (posture cleanup) | Tranche-1 verified and closed | Tranche-1 residue or new concerns |

## Non-Goals

- Do not edit contracts or docs outside this single discovery artifact
- Do not add or modify verify gates in this pass
- Do not fix stale posture metadata in this pass
- Do not change capability metadata
- Do not broaden into implementation by stealth
- Do not fix self-governance projection drift (pre-existing, separate concern)
- Do not fix scheduler failures (9 failed jobs are pre-existing)

## Exact Next Action

- `declared_but_unwired_contract_enforcement_decision`

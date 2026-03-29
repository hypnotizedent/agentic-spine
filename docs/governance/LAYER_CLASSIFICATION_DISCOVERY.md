# Layer Classification Discovery

## Parent Loop Id

- `LOOP-SPINE-CLOSURE-AND-AGENTIC-CORE-STABILIZATION-20260326`

## Concern Id

- `post-h2.layer-classification-preparation`

## Current Residue Count

- Remaining `domain: none` capabilities: `68`
- Remaining residue lifecycle distribution: `ready=68`
- Remaining residue plane distribution: `fabric=68`
- Current top-level domain counts: `infra=107`, `core=100`, `loop_gap=95`, `none=68`

## Family Distribution Of Remaining Residue

- `gate` (`7`): `gate.id.allocate`, `gate.mutation.trailers`, `gate.registry.add`, `gate.registry.update`, `gate.topology.assign`, `gate.topology.projection.build`, `gate.topology.validate`
- `agent` (`5`): `agent.health.check-all`, `agent.info`, `agent.route`, `agent.session.closeout`, `agent.tools`
- `github` (`5`): `github.actions.status`, `github.labels.status`, `github.mirror.sync`, `github.queue.status`, `github.status`
- `share` (`4`): `share.publish.apply`, `share.publish.preflight`, `share.publish.preview`, `share.publish.status`
- `surface` (`4`): `surface.audit.full`, `surface.boundary.audit`, `surface.boundary.reconcile.plan`, `surface.mobile.dashboard.status`
- `terminal` (`4`): `terminal.contract.status`, `terminal.heartbeat.post`, `terminal.scope.status`, `terminal.worker.projection.audit`
- `maker` (`3`): `maker.label.print`, `maker.qr.generate`, `maker.tools.status`
- `monolith` (`3`): `monolith.git_status`, `monolith.search`, `monolith.tree`
- `prompt` (`3`): `prompt.library.bootstrap`, `prompt.library.list`, `prompt.registry.status`
- `capability` (`2`): `capability.map.projection.build`, `capability.register`
- `domain` (`2`): `domain-inventory-refresh`, `domain.onboard.new`
- `git` (`2`): `git.merge.safe`, `git.stage.commit.scoped`
- `lean` (`2`): `lean.budget.check`, `lean.scorecard`
- `session` (`2`): `session.role.override`, `session.start`
- `snapshot` (`2`): `snapshot.projection.apply`, `snapshot.surface.audit`
- `audit` (`1`): `audit.export.governance_iac`
- `budget` (`1`): `budget.check`
- `catalog` (`1`): `catalog.domain.sync`
- `codex` (`1`): `codex.worktree.status`
- `coordinator` (`1`): `coordinator.lane.closeout`
- `foundation` (`1`): `foundation.agent.contracts.normalize`
- `lane` (`1`): `lane.standard.run`
- `nightly` (`1`): `nightly.closeout`
- `operator` (`1`): `operator.hygiene.reconcile`
- `outcome` (`1`): `outcome.slo.report`
- `projection` (`1`): `projection.reconcile`
- `sanitization` (`1`): `sanitization.audit`
- `schema` (`1`): `schema.conventions.audit`
- `self-governance` (`1`): `self-governance.closure.primitives.status`
- `service` (`1`): `service.data.lifecycle.projection.build`
- `stabilization` (`1`): `stabilization.mode.status`
- `wave` (`1`): `wave.closeout.finalize`
- `workspace` (`1`): `workspace.closeout.verify`

## Provisional Layer Bucket For Each Remaining Family Or Singleton

### `gate`

- Capability ids: `gate.id.allocate`, `gate.mutation.trailers`, `gate.registry.add`, `gate.registry.update`, `gate.topology.assign`, `gate.topology.projection.build`, `gate.topology.validate`
- Provisional bucket: `likely_L1_engine`
- Primary issue: `prefix/tool seam ambiguity`
- Decision tests: `L1`
- Reason: These capabilities allocate, register, project, validate, and mutate the verify gate topology itself. Removing them would directly degrade governed verify, gate routing, and control-plane mutation discipline even if no product runtime were active, which matches the L1 engine test.

### `agent`

- Capability ids: `agent.health.check-all`, `agent.info`, `agent.route`, `agent.session.closeout`, `agent.tools`
- Provisional bucket: `likely_L1_engine`
- Primary issue: `ownership ambiguity`
- Decision tests: `L1`
- Reason: These capabilities expose agent registry truth, agent tooling surfaces, deterministic routing, and claim-preflight/session-closeout health around the control plane. They primarily operate the spine execution fabric rather than any workload runtime, so the L1 engine test is the best fit.

### `github`

- Capability ids: `github.actions.status`, `github.labels.status`, `github.mirror.sync`, `github.queue.status`, `github.status`
- Provisional bucket: `mixed_requires_lower_granularity`
- Primary issue: `mixed granularity`
- Decision tests: `L1`, `L2`
- Reason: The read-only GitHub status surfaces behave like control-plane/provider observation, while `github.mirror.sync` is a mutating publication rail. The top-level prefix therefore mixes repo-governance observation with shared release/provider transport, so the family is too coarse to assign one layer truthfully.

### `share`

- Capability ids: `share.publish.apply`, `share.publish.preflight`, `share.publish.preview`, `share.publish.status`
- Provisional bucket: `likely_L2_shared_infrastructure`
- Primary issue: `layer ambiguity`
- Decision tests: `L2`
- Reason: These capabilities are a reusable outbound publishing rail with shared preflight, preview, readiness, and apply semantics. The primitive is not one product's business logic; it is a common publication substrate that multiple runtimes could inherit, which matches the L2 shared-infrastructure test.

### `surface`

- Capability ids: `surface.audit.full`, `surface.boundary.audit`, `surface.boundary.reconcile.plan`, `surface.mobile.dashboard.status`
- Provisional bucket: `mixed_requires_lower_granularity`
- Primary issue: `mixed granularity`
- Decision tests: `L1`, `L3`
- Reason: The boundary and audit capabilities are engine-governance surfaces, but `surface.mobile.dashboard.status` is a product-facing/mobile status summary rather than an engine primitive. The family spans both engine governance and runtime-facing output, so it must be decided below the top-level prefix.

### `terminal`

- Capability ids: `terminal.contract.status`, `terminal.heartbeat.post`, `terminal.scope.status`, `terminal.worker.projection.audit`
- Provisional bucket: `likely_L1_engine`
- Primary issue: `ownership ambiguity`
- Decision tests: `L1`
- Reason: These capabilities enforce session contract truth, heartbeat scope ownership, collision detection, and worker projection parity for the terminal/control-plane surface itself. They exist to keep governed execution possible and observable, which fits the L1 engine test directly.

### `maker`

- Capability ids: `maker.label.print`, `maker.qr.generate`, `maker.tools.status`
- Provisional bucket: `likely_L3_product_runtime`
- Primary issue: `ownership ambiguity`
- Decision tests: `L3`
- Reason: This family is hardware- and workflow-specific to the maker/print runtime and would not be inherited unchanged by unrelated runtimes. Removing it would affect one product/runtime family rather than the spine engine or shared substrate, so the L3 product-runtime test fits provisionally.

### `monolith`

- Capability ids: `monolith.git_status`, `monolith.search`, `monolith.tree`
- Provisional bucket: `likely_L1_engine`
- Primary issue: `prefix/tool seam ambiguity`
- Decision tests: `L1`
- Reason: These are repo-operator primitives for navigating and interrogating the governed monolith. They are generic controller utilities for working on the spine itself rather than workload behavior, which aligns better with L1 engine operation than with shared infrastructure or product runtime logic.

### `prompt`

- Capability ids: `prompt.library.bootstrap`, `prompt.library.list`, `prompt.registry.status`
- Provisional bucket: `likely_L1_engine`
- Primary issue: `ownership ambiguity`
- Decision tests: `L1`
- Reason: Prompt library seeding, listing, and lineage/registry status are part of governed control-plane context handling, not product-local behavior. They support repeatable execution and evidence across the spine itself, so the L1 engine test is the closest match.

### `capability`

- Capability ids: `capability.map.projection.build`, `capability.register`
- Provisional bucket: `likely_L1_engine`
- Primary issue: `prefix/tool seam ambiguity`
- Decision tests: `L1`
- Reason: These capabilities mutate and rebuild canonical capability authority surfaces. They power the engine's own registration and projection machinery, and removing them would break governed capability authority management even without any product runtime active.

### `domain`

- Capability ids: `domain-inventory-refresh`, `domain.onboard.new`
- Provisional bucket: `mixed_requires_lower_granularity`
- Primary issue: `mixed granularity`
- Decision tests: `L1`, `L2`
- Reason: `domain.onboard.new` is an engine-governance onboarding surface, while `domain-inventory-refresh` is a cross-domain operational orchestrator spanning media, HA, and network snapshots. The family therefore mixes engine governance with shared operational substrate and cannot be truthfully assigned as one unit.

### `git`

- Capability ids: `git.merge.safe`, `git.stage.commit.scoped`
- Provisional bucket: `likely_L1_engine`
- Primary issue: `prefix/tool seam ambiguity`
- Decision tests: `L1`
- Reason: These are governed landing and merge discipline primitives for the spine repo itself. They do not exist to serve a workload; they exist to make governed mutation, landing, and recovery safe, which is squarely within the L1 engine test.

### `lean`

- Capability ids: `lean.budget.check`, `lean.scorecard`
- Provisional bucket: `likely_L1_engine`
- Primary issue: `ownership ambiguity`
- Decision tests: `L1`
- Reason: Lean budget enforcement and scorecard rendering are governance controls over repo complexity and gate growth. They operate the spine's own change discipline, so their primitive function is engine governance rather than shared substrate or product behavior.

### `session`

- Capability ids: `session.role.override`, `session.start`
- Provisional bucket: `likely_L1_engine`
- Primary issue: `ownership ambiguity`
- Decision tests: `L1`
- Reason: These capabilities bootstrap sessions and control session-scoped role policy. They are part of governed entry and role/runtime control for the spine itself, which makes them engine primitives under the L1 test.

### `snapshot`

- Capability ids: `snapshot.projection.apply`, `snapshot.surface.audit`
- Provisional bucket: `likely_L2_shared_infrastructure`
- Primary issue: `layer ambiguity`
- Decision tests: `L2`
- Reason: Snapshot promotion and snapshot-surface auditing normalize how multiple runtimes handle governed snapshot bindings and tracked promotion. The primitive is shared operational substrate reused across HA, media, network, and related surfaces, which matches the L2 test.

### `audit`

- Capability ids: `audit.export.governance_iac`
- Provisional bucket: `likely_L1_engine`
- Primary issue: `ownership ambiguity`
- Decision tests: `L1`
- Reason: This export surface produces redacted governance/IaC evidence about the spine and adjacent governed repos. Its primitive is control-plane audit/export of governed truth, so it aligns more closely with engine self-observation than with shared workload infrastructure.

### `budget`

- Capability ids: `budget.check`
- Provisional bucket: `likely_L1_engine`
- Primary issue: `ownership ambiguity`
- Decision tests: `L1`
- Reason: This capability checks execution-token budget against a receipt. That is a control-plane execution constraint rather than a workload feature or shared product substrate, which makes it a provisional L1 engine primitive.

### `catalog`

- Capability ids: `catalog.domain.sync`
- Provisional bucket: `likely_L1_engine`
- Primary issue: `prefix/tool seam ambiguity`
- Decision tests: `L1`
- Reason: This capability reconciles authoritative domain catalog bindings and canonical docs from capability truth. It manages the spine's governance/catalog projections rather than a product runtime, which fits the L1 engine test.

### `codex`

- Capability ids: `codex.worktree.status`
- Provisional bucket: `likely_L1_engine`
- Primary issue: `prefix/tool seam ambiguity`
- Decision tests: `L1`
- Reason: Despite the `codex.` prefix, this capability is the D48 worktree lifecycle hygiene gate over governed worktrees and root normalization. Its primitive is controller/worktree safety for the spine repo itself, which places it provisionally in L1.

### `coordinator`

- Capability ids: `coordinator.lane.closeout`
- Provisional bucket: `likely_L1_engine`
- Primary issue: `ownership ambiguity`
- Decision tests: `L1`
- Reason: Coordinator lane closeout chains push parity, verify, friction reconcile, and worktree cleanup into one governed closeout surface. That is lane/control-plane lifecycle management, not workload or shared service substrate.

### `foundation`

- Capability ids: `foundation.agent.contracts.normalize`
- Provisional bucket: `likely_L1_engine`
- Primary issue: `ownership ambiguity`
- Decision tests: `L1`
- Reason: This capability normalizes compatibility markers against the spine's agent registry and contract truth. Its primitive is engine-level contract compatibility for agent execution surfaces, which points to L1.

### `lane`

- Capability ids: `lane.standard.run`
- Provisional bucket: `likely_L1_engine`
- Primary issue: `ownership ambiguity`
- Decision tests: `L1`
- Reason: This one-command ceremony runner coordinates snapshot, verify, and status checks for governed execution lanes. That is execution-framework orchestration, so the L1 engine test is the right provisional bucket.

### `nightly`

- Capability ids: `nightly.closeout`
- Provisional bucket: `likely_L1_engine`
- Primary issue: `ownership ambiguity`
- Decision tests: `L1`
- Reason: Nightly closeout is a lifecycle-driven cleanup/orchestration surface for the governed workspace and controller state. It exists to keep the spine execution environment closed and consistent, not to serve one runtime, which fits L1.

### `operator`

- Capability ids: `operator.hygiene.reconcile`
- Provisional bucket: `likely_L1_engine`
- Primary issue: `ownership ambiguity`
- Decision tests: `L1`
- Reason: This capability reconciles operator-home hygiene, external tool retention, and safe dev-artifact cleanup around the governed workstation. The primitive is control-plane self-maintenance, which is closer to L1 engine operation than to L2 or L3.

### `outcome`

- Capability ids: `outcome.slo.report`
- Provisional bucket: `likely_L2_shared_infrastructure`
- Primary issue: `layer ambiguity`
- Decision tests: `L2`
- Reason: This report-only capability probes critical-tier outcomes across communications, media, and mint, which is a shared operational reliability surface rather than one runtime's business logic. Multiple workloads would otherwise reinvent the same health/reporting primitive, so the L2 test fits best.

### `projection`

- Capability ids: `projection.reconcile`
- Provisional bucket: `likely_L1_engine`
- Primary issue: `prefix/tool seam ambiguity`
- Decision tests: `L1`
- Reason: This capability reconciles authoritative projection surfaces such as gate registry headers and entry-surface projections. That is engine-governance upkeep of canonical generated truth, so it aligns with L1.

### `sanitization`

- Capability ids: `sanitization.audit`
- Provisional bucket: `likely_L2_shared_infrastructure`
- Primary issue: `layer ambiguity`
- Decision tests: `L2`
- Reason: Sanitization auditing is a shared release/publication safeguard rather than product-local behavior. It represents a reusable outward-facing release hygiene primitive that multiple runtimes or publication flows would consume, which makes L2 the best provisional fit.

### `schema`

- Capability ids: `schema.conventions.audit`
- Provisional bucket: `likely_L1_engine`
- Primary issue: `ownership ambiguity`
- Decision tests: `L1`
- Reason: This capability audits binding-schema conventions across the repo and emits governance normalization evidence. The primitive is engine self-governance over bindings, so the L1 engine test applies.

### `self-governance`

- Capability ids: `self-governance.closure.primitives.status`
- Provisional bucket: `likely_L1_engine`
- Primary issue: `ownership ambiguity`
- Decision tests: `L1`
- Reason: This capability reports on closure primitives such as topology, endpoint, lifecycle, and portability status for the spine's own self-governance. It is directly about the engine's control-plane closure posture, which is L1.

### `service`

- Capability ids: `service.data.lifecycle.projection.build`
- Provisional bucket: `likely_L2_shared_infrastructure`
- Primary issue: `layer ambiguity`
- Decision tests: `L2`
- Reason: Service-data lifecycle projection is a shared retention/lifecycle substrate that normalizes service behavior across workloads rather than implementing one product's runtime logic. That shared normalization role fits the L2 test.

### `stabilization`

- Capability ids: `stabilization.mode.status`
- Provisional bucket: `likely_L1_engine`
- Primary issue: `ownership ambiguity`
- Decision tests: `L1`
- Reason: This capability reports stabilization-window status, verify bypass targets, and preflight requirements for the governed control plane. It exists to operate the spine's own execution posture, which is an L1 concern.

### `wave`

- Capability ids: `wave.closeout.finalize`
- Provisional bucket: `likely_L1_engine`
- Primary issue: `ownership ambiguity`
- Decision tests: `L1`
- Reason: Wave closeout finalization validates receipts, stages exact closeout evidence, enforces gate discipline, commits, and checks push parity. That is core wave/control-plane lifecycle behavior, not shared infrastructure or runtime logic.

### `workspace`

- Capability ids: `workspace.closeout.verify`
- Provisional bucket: `likely_L1_engine`
- Primary issue: `ownership ambiguity`
- Decision tests: `L1`
- Reason: This capability verifies workspace closure, closed-repo parity, and agent inbox/runtime state for the operator workspace model itself. It is an execution-environment invariant for the spine engine, which makes it L1 provisionally.

## Key Seams Requiring Lower-Granularity Interpretation

- `domain-inventory-refresh` vs `domain.onboard.new`: the top-level `domain` family mixes shared cross-domain orchestration with engine governance onboarding.
- `github.*`: repo/provider observation and publication transport share one prefix, so the top-level family is too coarse.
- `surface.*`: engine boundary/audit surfaces and the mobile/customer dashboard status surface do not share one primitive function.
- `codex.worktree.status`: the `codex.` prefix obscures an engine worktree-hygiene gate.
- `git.stage.commit.scoped` and `git.merge.safe`: the `git.` prefix names a tool, but the primitive is governed landing discipline.
- `capability.map.projection.build`: the `capability.` prefix names authority subject matter, but the primitive is engine projection upkeep.
- `catalog.domain.sync`: doc/catalog ownership truth lives under a prefix that reads like content rather than control-plane projection.
- `share.publish.*`: the family reads like product publication, but the primitive may be shared release/distribution substrate.
- `agent.*`: the family is cohesive enough to provisionally lean L1, but it still mixes registry observation, route lookup, and session-closeout auditing.
- `gate.*`: the family is provisionally L1, but the prefix names the governed object rather than the engine function that manages it.

## Whether Any Further Ownership-Only Tranche Remains Justified

- No.
- The remaining residue is no longer a truthful ownership-only cleanup problem.
- The unresolved seams are dominated by layer interpretation, tool-prefix ambiguity, and mixed families rather than missing owner inference alone.

## Whether `core` Automatic Growth Should Now Be Treated As Closed Absent New Justification

- Yes.
- `core` automatic growth should be treated as closed absent new explicit justification.
- The remaining residue includes multiple engine-looking seams, but they now require primitive-function proof against the layer model rather than another default-to-`core` ownership sweep.

## Exact Open Questions For The Decision Stage

- Should `domain` be split at capability granularity, with `domain.onboard.new` treated separately from `domain-inventory-refresh`?
- Should `github` be decided as a provider family at sub-family/capability granularity, especially `github.mirror.sync` versus the read-only status surfaces?
- Should `surface.mobile.dashboard.status` be held apart from the engine-governance `surface.*` audits?
- Should `share.publish.*` and `sanitization.audit` be ratified as shared publication substrate (`L2`) or held for narrower release/publication interpretation?
- Should `outcome.slo.report` and `service.data.lifecycle.projection.build` be ratified as shared operational substrate even though they currently live under `core` verify/authority paths?
- Is `maker.*` ready to be treated as the first clear provisional `L3` residue pocket, or should its ownership/layer decision remain coupled to later product-boundary work?
- Which seams must be decided at family granularity, which at sub-family granularity, and which at single-capability granularity?

## Exact Proposed Next Action

- `layer_classification_decision`

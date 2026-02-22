---
status: draft
owner: "@ronny"
last_verified: 2026-02-22
scope: terminal-worker-runtime-v2
---

# Terminal Worker Runtime Contract v2 (Design)

## 1) Problem This Solves
The spine runtime is operationally strong, but ergonomically fragmented:
- Agent registration, terminal role wiring, gate scope, and usage guidance are split across multiple files.
- Adding an agent does not automatically make it launchable/scoped/self-documenting.
- Domain workers see broad/global surfaces instead of domain-scoped runtime context.
- Proposal supersede state is valid but operationally painful under high proposal churn.

This contract defines a single coherent model: **one registration input, generated runtime surfaces, and deterministic terminal behavior**.

## 2) Design Goals (Locked)
1. Canonical uniformity: one convention for worker runtime registration and dispatch.
2. No orphaned implementations: registered agents become discoverable/launchable/verifiable immediately.
3. Domain-scoped runtime: each terminal sees only relevant capabilities, gates, and open work.
4. Self-documenting agents: usage surface is generated from registration, not manually maintained.

## 3) Existing Assets Reused
- `ops/bindings/terminal.role.contract.yaml`
- `ops/bindings/gate.domain.profiles.yaml`
- `ops/bindings/gate.agent.profiles.yaml`
- `ops/bindings/agents.registry.yaml`
- `ops/capabilities.yaml`
- `ops/commands/terminal-launch.sh`
- `ops/plugins/verify/bin/verify-topology`
- proposal model (`ops/bindings/proposals.lifecycle.yaml`, `ops/plugins/proposals/bin/*`)

## 4) Canonical v2 Model

### 4.1 Authoritative Inputs
- `ops/bindings/agents.registry.yaml` = **single registration input for domain workers**.
- `ops/capabilities.yaml` = capability SSOT.
- `ops/bindings/gate.domain.profiles.yaml` + `ops/bindings/gate.agent.profiles.yaml` = gate scoping SSOT.
- `ops/bindings/terminal.role.contract.yaml` = static control-plane/audit role policy.

### 4.2 Generated Runtime Surfaces
Generated (not hand-edited):
1. `ops/bindings/terminal.worker.catalog.yaml`
- Unified runtime catalog per terminal worker.
- Includes terminal id, domain, scoped capability set, scoped gate set, write scope, verify pack target, launcher metadata.

2. `ops/bindings/routing.dispatch.yaml`
- Deterministic dispatch map: capability -> execution target (`plugin` or `agent`).
- Eliminates implicit routing spread across registries/scripts.

3. `docs/governance/generated/worker-usage/<terminal_id>.md`
- Auto-generated usage surface for each worker terminal:
  - what it owns
  - available capabilities
  - gate pack and verify commands
  - tool examples and boundaries
- D84 integration requirement: generated worker usage docs must be covered by a deterministic docs index policy
  (dynamic registration pattern or explicit generated-path exclusion, but not silent drift).

4. `ops/bindings/terminal.launcher.view.yaml`
- Picker-ready source for launcher UI/hotkeys/cards.

Implementation ownership requirement:
- When introduced, all four generated surfaces above must be added to
  `ops/bindings/registry.ownership.yaml` as `type: generated`.

## 5) One-File Registration Flow

### 5.1 Registration Rule
Registering/updating a domain worker is a single edit to:
- `ops/bindings/agents.registry.yaml`

Required minimal fields (v2):
- `id`
- `domain`
- `contract`
- `capabilities_scope`:
  - `include_prefixes` (prefix match, e.g. `ha.`)
  - `include_keys` (exact capability ids)
  - `exclude_keys` (optional deny overrides)
- `write_scope`
- `gates` (optional explicit overrides; otherwise resolved from domain/agent profiles)
- `terminal_binding`:
  - `terminal_id`
  - `hotkey`
  - `lane_profile`
  - `verify_domain`

Compatibility note:
- Existing `capabilities` arrays in `agents.registry.yaml` are supported during migration.
- Generator normalizes legacy `capabilities` into `capabilities_scope` before building runtime outputs.

### 5.2 Generation Rule
After registry change, generator pipeline produces all runtime surfaces above.
No manual edits to launcher/gate/capability usage docs for that agent.

### 5.3 Validation Rule
Parity validators enforce:
- every registered worker has a launcher card
- every worker has a usage doc
- every worker resolves to scoped capabilities and scoped gates
- every scoped capability resolves through `routing.dispatch.yaml`

## 6) Terminal Runtime Behavior (v2)
When launching a terminal worker (`SPINE-CONTROL-01`, `DOMAIN-HA-01`, etc.):

1. Session bootstrap reads `terminal.worker.catalog.yaml` for that `terminal_id`.
2. Session output is scoped by default:
- **Capabilities:** worker-scoped subset only.
- **Verify:** worker/domain-relevant packs only.
- **Open work:** loop/gap/proposal view filtered to worker domain and linked loop scopes.
3. Usage surface is printed/referenced from generated usage doc.

### 6.1 Open-Work Domain Dependency
- Domain-filtered open work requires explicit domain identity on loop/gap/proposal surfaces.
- Phase B dependency: extend loop/gap/proposal schemas with normalized `domain` fields.
- Transitional fallback (pre-schema migration): derive domain from existing loop/gap naming + linkage rules.

### Example: `DOMAIN-HA-01`
- Capability surface: `ha.*`, `home.*`, relevant `verify.*` helpers.
- Verify surface: `home`/`home-assistant` gate packs, not full global surface.
- Open work: HA/home-automation loops/gaps/proposals first-class; other domains hidden unless `--all` requested.

## 7) Uniformity Contract
All worker terminals follow the same envelope:
- `terminal_id`
- `domain`
- `capabilities_scoped[]`
- `gates_scoped[]`
- `open_work_scope`
- `usage_surface`
- `dispatch_source`

This envelope is generated and machine-checkable.

## 8) Proposal Supersede Coherence (Pain Fix)
Current supersede lifecycle exists, but replacement flow is manual and lossy under churn.

### v2 Additions
1. Add `replaces` to new proposal manifests.
- When set, apply/submit tooling validates target exists and is pending.

2. Add `superseded_by` on superseded proposal.
- Bidirectional trace between old and replacement proposals.

3. Add `proposals.replace` capability.
- Atomic operation:
  - create replacement proposal
  - mark replaced proposal as `superseded`
  - set linkage fields in both manifests
- Guardrail: replacement is valid only for fully pending proposals
  (`status: pending`, no `.applied` marker, no apply-in-progress lock/artifact).
- If partial apply evidence exists, `proposals.replace` must hard-fail and require manual reconciliation.

4. Queue display semantics:
- `proposals.list` groups replacement chains.
- `proposals.status` highlights pending proposals with unresolved predecessor links.

Outcome: no repeated manual supersede churn for iterative proposal revisions.

## 9) Migration Plan (Design-Level)

### Phase A: Contract and generators
- Approve this v2 design.
- Define schemas for generated artifacts:
  - `terminal.worker.catalog.yaml`
  - `routing.dispatch.yaml`
  - `terminal.launcher.view.yaml`

### Phase B: Launcher/runtime wiring
- `terminal-launch` reads generated launcher view.
- session start flow resolves `terminal_id` -> scoped runtime envelope.
- Add normalized `domain` fields to loop/gap/proposal schemas to support deterministic open-work filtering.

### Phase C: Enforcement
- Add parity gate(s):
  - worker catalog parity
  - routing dispatch parity
  - generated usage surface parity
- Make worker registration incomplete/invalid if generated runtime surfaces fail.

### Phase D: Proposal lifecycle coherence
- Implement `proposals.replace` and replacement link fields.
- Enforce lifecycle linkage checks in proposal status/admission.

## 10) Non-Goals (This Proposal)
- No runtime behavior change now.
- No registry rewiring now.
- No gate additions now.
- No launcher implementation changes now.

This is a contract-first alignment artifact to lock design before implementation.

## 11) Acceptance Criteria for Future Implementation Proposal
1. One-file worker registration proven for at least one new agent.
2. New agent appears in launcher without manual launcher edits.
3. New agent can run scoped verify and scoped capability list.
4. Usage surface auto-generated and linked at launch.
5. Proposal replacement chain works with `proposals.replace` and no manual supersede edits.

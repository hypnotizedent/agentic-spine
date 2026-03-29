# Authoritative Cross-Surface State Synthesis Decision

## Parent Loop Id

- `LOOP-SPINE-CLOSURE-AND-AGENTIC-CORE-STABILIZATION-20260326`

## Concern Id

- `authoritative_cross_surface_state_synthesis`

## Authoritative Discovery Artifact Path

- `/Users/ronnyworks/code/agentic-spine/docs/governance/AUTHORITATIVE_CROSS_SURFACE_STATE_SYNTHESIS_DISCOVERY.md`

## Live Boundary Recheck Summary

- Repo baseline remained `main`, clean, and synced at decision start with `HEAD` at discovery commit `3ec69e0a`; no repo-owned implementation landed after discovery and before this decision.
- `ops/bindings/authority.concerns.yaml` still resolves cleanly for all 10 declared concern families.
- `ops/bindings/root.authority.contract.yaml` remains truthful and still sits outside the current concern map.
- Repo-root `AGENTS.md` and `CLAUDE.md` still exist; `AGENTS.md` retains authoritative front matter, while `CLAUDE.md` remains a thin repo pointer without an explicit authority marker.
- `ops/bindings/platform.control.surfaces.yaml` still agrees with `./bin/ops cap run platform.control.surface.status`.
- `./bin/ops cap run host.claude.entrypoint.status` still reports home-level Claude warnings only; those remain adapter evidence under root-authority policy, not canonical repo truth.
- No material live-posture change invalidated the discovery boundary.

## Exact Tranche Decision

- `concern_map_to_live_surface_reconciliation`
- The next slice is one repo-owned reconciliation slice, not multiple passes.
- Its purpose is to reconcile the concern map to live repo authority surfaces and normalize only the directly affected repo surfaces needed to make that map truthful.
- It does not authorize capability-definition rewiring, prompt/runtime semantics work, protocol runtime handoffs, or autonomous multi-node implementation.

## Exact Implementation Boundary

### In-Scope Write Surfaces

- `/Users/ronnyworks/code/agentic-spine/ops/bindings/authority.concerns.yaml`
- `/Users/ronnyworks/code/agentic-spine/AGENTS.md`
- `/Users/ronnyworks/code/agentic-spine/CLAUDE.md`
- `/Users/ronnyworks/code/agentic-spine/ops/capabilities.yaml`
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/gate.execution.topology.yaml`
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/intake.lifecycle.contract.yaml`
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/platform.control.surfaces.yaml`

### Exact Read-Only Evidence/Support Surfaces

- `/Users/ronnyworks/code/agentic-spine/ops/bindings/root.authority.contract.yaml`
- `/Users/ronnyworks/code/agentic-spine/docs/governance/AUTHORITATIVE_CROSS_SURFACE_STATE_SYNTHESIS_DISCOVERY.md`
- `./bin/ops cap run platform.control.surface.status`
- `./bin/ops cap run host.claude.entrypoint.status`
- `./bin/ops cap run spine.control.tick -- --fast --json`

### Exact Deferred Surfaces

- Home-level adapter targets under `/Users/ronnyworks/.claude/` and `/Users/ronnyworks/.codex/`
- Capability-definition command/path rewiring outside the repo-owned relation and marker reconciliation of `ops/capabilities.yaml`
- Prompt/runtime semantics surfaces, including prompt registry and prompt library wiring
- Protocol runtime handoff surfaces, including communication-protocol runtime implementation
- Autonomous multi-node runtime and any other downstream autonomy implementation
- Projection or generator decomposition beyond what is already recorded in the current files

### Exact Non-Goals

- Do not mutate any home-level adapter surface.
- Do not change capability ids, capability command routing, or capability runtime wrappers.
- Do not add a new shared synthesis mechanism in this slice.
- Do not mutate platform runtime state or run reconcile/apply surfaces.
- Do not broaden into prompt/runtime semantics, protocol runtime handoffs, or autonomous multi-node work.

## Explicit Decisions

- `AGENTS.md`
  - Treat as the authoritative repo-root entry-surface anchor inside the next slice.
  - It is not a separate root-taxonomy concern and does not require home-level parity work.
- `CLAUDE.md`
  - Treat as a subordinate repo-root thin-pointer surface under the same repo entry-surface concern family as `AGENTS.md`.
  - It must gain an explicit truthful marker/relationship in the next slice and must not become an independent source of truth.
- `root.authority.contract.yaml`
  - Remains truthful read-only support for the next slice.
  - Do not edit it in the next slice unless later evidence proves the repo-vs-home taxonomy itself is wrong, which discovery did not show.
- `platform.control.surfaces.yaml`
  - Add to the concern map as its own standalone concern family rather than folding it into a broader platform-authority family.
  - Current live contract truth is already sufficient; any file mutation in the next slice must stay limited to what the concern-map reconciliation strictly requires.
- `ops/capabilities.yaml`
  - Keep in the same synchronized reconciliation slice as `gate.execution.topology.yaml` and `intake.lifecycle.contract.yaml`.
  - Treat it as a live repo authority surface whose concern-map relationship must be re-declared before any deeper rewiring work.
- `ops/bindings/gate.execution.topology.yaml`
  - Keep in the same synchronized reconciliation slice as `ops/capabilities.yaml` and `ops/bindings/intake.lifecycle.contract.yaml`.
  - The next slice must treat it with a truthful mixed authority/projection model; that mixed model is not deferred.
- `ops/bindings/intake.lifecycle.contract.yaml`
  - Keep in the same synchronized reconciliation slice as `ops/capabilities.yaml` and `ops/bindings/gate.execution.topology.yaml`.
  - Reconcile its declared authority role against the live capability/topology chain rather than applying a marker-only patch.

## Explicit Decision On Capability-Definition Rewiring

- Capability-definition rewiring remains deferred.
- The next slice may reconcile concern-map relationships and surface markers/source-of-truth posture in `ops/capabilities.yaml`, but it does not authorize command-path rewiring, alias changes, or runtime routing changes.

## Timeline

| Date | Stage | Deliverable | Dependency | Slip Condition |
|---|---|---|---|---|
| 2026-03-29 | implementation landed | Widened structural + worker-projection implementation landed at `11bf71a2` | Prior D411 blocker discovery, decision, election, and implementation closure | Already landed |
| 2026-03-29 | discovery landed | Cross-surface synthesis discovery landed at `3ec69e0a` with residue inventory and tranche recommendation | Clean synced baseline and live read-only recheck | Already landed |
| 2026-03-29 | decision landed | This decision artifact freezes the exact concern-map reconciliation boundary | Discovery artifact committed and live posture still matching discovery | Slips if the live repo surface set changes before election |
| 2026-03-29 or next clean landing window | election target | One explicit authorization result for the bounded reconciliation slice | Discovery + decision artifacts committed and pushed | Slips if operator review finds the boundary still mixes repo-owned and home-level work |
| After election | bounded implementation target if authorized | Concern-map reconciliation and directly coupled repo-surface normalization on the elected write set only | Election authorizes implementation | Slips if implementation proves a deferred concern is strictly required |

## Exact Proposed Next Action

- `authoritative_cross_surface_state_synthesis_election`

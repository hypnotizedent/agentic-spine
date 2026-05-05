---
status: authoritative
owner: "@human-steward"
last_verified: 2026-05-01
scope: spine-minimal-operating-contract
---

# SPINE.md - Minimal Operating Contract

The spine is a tool. Agent entry is AGENTS-first, then doc-first and CLI-first.

## Startup

Read [AGENTS.md](../../AGENTS.md) first for the
current aperture and operator entry rules.

```bash
cd ~/code/agentic-spine
./bin/ops terminal launch --tool <tool> --terminal <name>
./bin/ops status
./bin/ops cap run verify.engine.run
./bin/ops cap run spine.verify
```

If you are already inside a governed terminal-launch session and only need the
orientation banner again, use the read-only orientation surface:

```bash
./bin/ops cap run session.v3.attach
```

## Daily Use

- Read [AGENTS.md](../../AGENTS.md) first for the current aperture.
- Read [NORTH_STAR.md](../../NORTH_STAR.md) for platform identity.
- Read [SESSION_PROTOCOL.md](SESSION_PROTOCOL.md) for environment behavior.
- Read [NODE_PROMOTION_LADDER.md](NODE_PROMOTION_LADDER.md) when the question is how node roles become real.
- Use `./bin/ops cap run <capability> -- ...` when a capability exists.
- Use `./bin/ops status` as the public readback surface.
- Use `./bin/ops status --expert` only when public status gives a reason for
  drilldown.
- Use foundational verification for entry and truth checks:
  `./bin/ops cap run verify.engine.run` and `./bin/ops cap run spine.verify`.

## Public Grammar

The taught operator grammar is deliberately tiny:

- request
- claim
- heartbeat
- outcome, result, or failure
- receipt
- status
- verify

Everything else is engine machinery, scoped pack behavior, compatibility, or
expert drilldown unless this contract explicitly promotes it. Loops, waves,
packets, handoffs, raw gates, raw receipts, manual custody surgery, direct
SQLite inspection, and runtime path inspection may still exist because the
engine needs internals and experts need repair tools. They must not be taught as
normal operator grammar or treated as peer authority beside status and
foundational verify.

## Principle

If an agent cannot understand how to work here by reading the entry surface,
the doctrine docs, and running the startup commands above, the entry surface is
too complex.

If the entry surface causes human-steward guidance to be parked, renamed, or
reprocessed instead of carried forward by the engine, the entry surface is wrong
and must be reconciled before more workflow ceremony is added.

## Public Read Model

The default operator read model is `ops status`.

It answers five questions:

- What work is open?
- What is blocked or risky?
- What automation is running?
- Is the system healthy?
- What needs attention now?

This is a subtraction rule, not a new subsystem. `ops status` reads existing
canonical authorities and presents one public operational model. Requests,
claims, heartbeats, outcomes/results/failures, receipts, verify/readback,
standing-program health, and execution-lane truth remain canonical inputs.
Loops, waves, handoffs, delegations, packets, dispatch envelopes, raw gates,
raw receipts, direct SQLite inspection, and runtime path inspection remain
valid engine or expert drilldown surfaces, but they must not be taught as peer
public operator grammar.

Use `ops status --expert`, `ops wave`, `ops loops`, `delegation.status`,
`orchestration.wave.status`, and direct evidence reads only when the public
readback points to a reason for drilldown.

## First-Class Change Closure

The spine must not solve ambiguity by adding a new canonical surface while the
old surfaces continue to read back as peer truth.

For any change that promotes a new L1/L2 authority, adapter, readback, operator
entry path, or human-intent flow, construction is not completion. The change is
complete only when the closure questions in
[`first.class.change.closure.contract.yaml`](../../ops/bindings/first.class.change.closure.contract.yaml)
are answered:

- Which existing L1/L2 home owns this concern, and what cross-plane readback was
  checked before mutation?
- What is the one canonical authority after the change?
- What old surface, field, wrapper, vocabulary, or readback did it replace?
- What remains compatibility-only, projection-only, or expert drilldown?
- What was deleted, retired, hidden from operator grammar, or demoted?
- Which normal readback now teaches the canonical model?
- Which verify lock prevents both old and new paths from acting canonical?

If the answer is "nothing was replaced," the change must say why. If the
answer is "old work needs catchup," the catchup must use the new canonical
authority rather than create a second migration plane.

Surface expansion also follows
[`SESSION_PROTOCOL.md#surface-expansion-discipline`](SESSION_PROTOCOL.md#surface-expansion-discipline):
new first-class surfaces must retire, fold, hide, or demote an old peer path in
the same slice.

## Layer Framing

Persist this distinction or the shell will grow back:

- **Spine Core**: request, claim, heartbeat, outcome/result/failure, receipt
- **Public Readback**: status, `verify.engine.run`, `spine.verify`
- **Spine Engine**: admission, capability execution, delegation, wave execution,
  internal closeout, scoped verify implementation
- **L2 Workbench Rails**: reusable agents, adapters, generators, validators,
  and operator tools that multiple domains can depend on
- **Operational Packs**: secrets, recovery, control-cycle, service health, and
  scoped runtime packs that remain subordinate to spine authority
- **L3 Project/Product Bodies**: workload-specific logic, health, product
  behavior, app compose, product playbooks, and domain-local contracts
- **Shelf**: cockpit proliferation, broker read shells, narrative/explanatory comfort layers

`operator_console` admits and observes work.

Governed nodes carry unattended runtime.

Workbench is not a second spine and not a dumping ground. A surface living in
Workbench is first-class only when its role is clear: shared L2 rail, unstable
L3 project/domain body, stable product body, generated projection, or retired
residue. Moving a file out of `agentic-spine` is not subtraction unless the old
authority is removed, the replacement home is named, and the normal readback
teaches the new ownership.

Hand-maintained YAML is valid only when it is the contract itself. If a YAML
file is a factual view of runtime, inventory, admission, storage, backup, or
product state, it must either be generated from the living authority or demoted
from canonical truth.

## Rebuild-Grade Core

If the spine were rebuilt from the durable kernel lessons only, the current
truthful core would be:

| Surface | Status | Why |
|---|---|---|
| canonical state root + shared authority | `keep` | Truth must live outside chat/session memory. |
| `bin/ops` + governed capability registry | `keep` | Named capabilities are the boring execution/control surface. |
| terminal identity + execution class | `keep` | Custody and legal mutation boundaries must be explicit. |
| request / governed birth object | `keep` | Bounded work must have a governed birth object; loop shape is an internal materialization. |
| execution request / governed execution birth object | `keep` | Execution still needs a governed birth object; delegation, orchestration manifest, and wave runtime state are internal or expert-visible materializations of the request. |
| claim | `keep` | Custody proof is core kernel truth. |
| heartbeat | `keep` | Liveness proof is core kernel truth. |
| outcome/result/failure | `keep` | Completion truth must be explicit and machine-readable. |
| internal execute/closeout machinery | `keep` | Minimal governed execution and closeout remain necessary engine internals, not public grammar. |
| receipts + outcome | `keep` | Every meaningful action must emit proof. |
| `verify.engine.run`, `spine.verify` | `keep` | Foundational verify must stay tiny and discoverable. These are the only foundational verify surfaces; `spine.status` is a unified status front door, not a verify surface. |
| explicit interactive worker handoff | `keep` | `delegate.to.execution` remains a governed handoff path, not an autonomous default queue or public operator grammar. |
| manual custody path taught as normal operator grammar | `demote` | Expert compatibility only. |
| cockpit/mobile/operator payload variants | `shelf` | Useful read shells, not irreducible core. |
| broker read APIs | `shelf` | Convenience/read-model shell, not kernel substrate. |
| plans, handoffs, narrative receipts | `shelf` | Legitimate surfaces, but not day-one spine core. |
| public teaching of raw loops/waves/packets/handoffs/gates/scope surgery as operator-default grammar | `delete` | Keep as drilldown/surgery only, not public front-door grammar. |
| bounded execution pickup lane as the internal controller-prompt execution substrate | `keep` | Operational mailroom execution is now proved as the bounded runtime artery: request, claim, heartbeat, outcome/result/failure, receipt. It supports capability-backed routes plus one no-tools provider-backed `agent_tool` bridge proof class. It is engine-internal and public readback is `execution.pickup.status`; open-ended tool-using AI-agent autonomy is not part of the kernel. |
| translator/control-node storytelling as irreducible core substrate | `must_prove_again` | Explanatory shell must not outrank the smaller engine. |

This matrix is deliberately smaller than the current shell. A surface may be
first-class and still not be part of the rebuild-grade core.

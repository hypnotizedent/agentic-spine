---
status: authoritative
owner: "@ronny"
last_verified: 2026-04-07
scope: spine-minimal-operating-contract
---

# SPINE.md - Minimal Operating Contract

The spine is a tool. Agent entry is AGENTS-first, then doc-first and CLI-first.

## Startup

Read [AGENTS.md](/Users/ronnyworks/code/agentic-spine/AGENTS.md) first for the
current aperture and operator entry rules.

```bash
cd ~/code/agentic-spine
./bin/ops terminal launch --tool <tool> --terminal <name>
./bin/ops status --json
./bin/ops cap run verify.engine.run
./bin/ops cap run spine.verify
./bin/ops cap list
```

If you are already inside a governed terminal-launch session and only need the
orientation banner again, use:

```bash
./bin/ops cap run session.v3.attach
```

## Daily Use

- Read [AGENTS.md](/Users/ronnyworks/code/agentic-spine/AGENTS.md) first for the current aperture.
- Read [NORTH_STAR.md](/Users/ronnyworks/code/agentic-spine/NORTH_STAR.md) for platform identity.
- Read [SESSION_PROTOCOL.md](/Users/ronnyworks/code/agentic-spine/docs/governance/SESSION_PROTOCOL.md) for environment behavior.
- Read [NODE_PROMOTION_LADDER.md](/Users/ronnyworks/code/agentic-spine/docs/governance/NODE_PROMOTION_LADDER.md) when the question is how node roles become real.
- Use `./bin/ops cap run <capability> -- ...` when a capability exists.
- Use foundational verification for entry and truth checks:
  `./bin/ops cap run verify.engine.run` and `./bin/ops cap run spine.verify`.
## Principle

If an agent cannot understand how to work here by reading the entry surface,
the doctrine docs, and running the three commands above, the entry surface is
too complex.

## Layer Framing

Persist this distinction or the shell will grow back:

- **Spine Core**: request, claim, heartbeat, result/failure, receipt
- **Spine Engine**: admission, capability execution, delegation, wave execution, verify, status
- **Operational Packs**: secrets, recovery, control-cycle, service health, domain/runtime packs
- **Shelf**: cockpit proliferation, broker read shells, narrative/explanatory comfort layers

`operator_console` admits and observes work.

Governed nodes carry unattended runtime.

## Rebuild-Grade Core

If the spine were rebuilt from the durable kernel lessons only, the current
truthful core would be:

| Surface | Status | Why |
|---|---|---|
| canonical state root + shared authority | `keep` | Truth must live outside chat/session memory. |
| `bin/ops` + governed capability registry | `keep` | Named capabilities are the boring execution/control surface. |
| terminal identity + execution class | `keep` | Custody and legal mutation boundaries must be explicit. |
| `work_request` / loop birth | `keep` | Bounded work must have a governed birth object. |
| `execution_request` / delegation birth | `keep` | Execution still needs a governed birth object, even if transport realizations change. |
| claim | `keep` | Custody proof is core kernel truth. |
| heartbeat | `keep` | Liveness proof is core kernel truth. |
| `wave.execute` / `wave.finish` | `keep` | Minimal governed execution and closeout remain core. |
| receipts + outcome | `keep` | Every meaningful action must emit proof. |
| `verify.engine.run`, `spine.verify`, `spine.status` | `keep` | Foundational verify must stay tiny and discoverable. |
| `delegate.to.execution` taught as an autonomous default queue | `demote` | Today it is an explicit interactive handoff, not admitted autonomous lane truth. |
| manual custody path taught as normal operator grammar | `demote` | Expert compatibility only. |
| cockpit/mobile/operator payload variants | `shelf` | Useful read shells, not irreducible core. |
| broker read APIs | `shelf` | Convenience/read-model shell, not kernel substrate. |
| plans, handoffs, narrative receipts | `shelf` | Legitimate surfaces, but not day-one spine core. |
| public teaching of raw loops/waves/scope surgery as operator-default grammar | `delete` | Keep as drilldown/surgery only, not public front-door grammar. |
| mailroom task lane as the default controller-prompt execution substrate | `must_prove_again` | Real autonomous lane now admits controller-prompt work truthfully and synchronizes packet runtime state, but packet closeout is still explicit and the path is not yet proven as the permanent default. |
| translator/control-node storytelling as irreducible core substrate | `must_prove_again` | Explanatory shell must not outrank the smaller engine. |

This matrix is deliberately smaller than the current shell. A surface may be
first-class and still not be part of the rebuild-grade core.

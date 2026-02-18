---
status: draft
owner: "@ronny"
last_verified: 2026-02-18
scope: spine-autonomous-orchestration-gap-audit
---

# Spine Autonomous Orchestration Gap Audit (2026-02-18)

## Current Formalized Foundation

- Agent registry v2 is live with identity, domain, tools, write scopes, and gate bindings.
- Terminal role contracts and heartbeat collision checks are in place for multi-terminal safety.
- Agent contracts define owns/defers boundaries per domain.
- Mailroom queue/state/ledger infrastructure exists for governed receipts and traceability.
- Deterministic routing surfaces exist (`agent.info`, `agent.route`, `agent.tools`).
- Scope-overlap and heartbeat checks provide mechanical write-collision visibility.

## Three Walls Blocking Autonomous Orchestration

1. No agent-to-agent task protocol:
   Agents still rely on operator mediation rather than autonomous enqueue/claim/handoff.
2. No unified gateway-exposed domain tool surface:
   Spine gateway does not yet expose full agent discovery + route delegation tooling.
3. No machine-enforced workflow dependency model:
   Loop scopes are human-readable, but step dependencies and handoff contracts are not fully machine-enforced.

## Target Agent Archetypes

| Archetype | Example | Role | Required Capability |
|---|---|---|---|
| Orchestrator | Mailroom Magic | Creates loops, assigns work, tracks execution | DAG/task coordination, health-aware scheduling |
| Executor | Domain agents (finance, HA, mint, media) | Claims tasks, runs capabilities, emits artifacts | Governed claim/heartbeat/complete protocol |
| Verifier | Security Defender / audit | Verifies artifacts, runs gates, closes loops | Cross-agent receipt validation and close authority |

## Coordination Protocol Needed

Minimal protocol contract between orchestrator, mailroom, executor, and verifier:

- enqueue(task)
- claim(task)
- heartbeat(progress)
- complete(artifact)
- handoff(next-step)

All transitions must stay receipted and governed through capabilities (Cap-RPC path), not bypass endpoints.

## Concrete Missing Pieces

1. Agent task request schema (enqueue/claim/heartbeat/complete/handoff envelope).
2. Governed mailroom task capabilities for agent execution.
3. Workflow dependency schema (DAG-like metadata in orchestration manifest).
4. Gateway-exposed routing/delegation tools backed by canonical agent capabilities.
5. Agent health preflight gate that blocks unsafe scheduling.
6. Agent session/role binding lifecycle for claim/start/cleanup.

## Minimum Viable Autonomous Loop (V1)

1. Governed task lifecycle capabilities (`enqueue`, `claim`, `complete`).
2. Machine-readable workflow dependency schema and enforcement.
3. Agent health preflight gate.

Everything else (full domain MCP delegation, quotas, deadlock optimization) is a follow-on iteration.

## Mapping to Active Loop/Gaps

- Loop: `LOOP-SPINE-ROUTING-AND-DELEGATION-GLUE-V1-20260218`
- `GAP-OP-669`: gateway-first parity gap.
- `GAP-OP-670`: gateway agent discovery/routing tool exposure gap.
- `GAP-OP-671`: governed Cap-RPC task lifecycle gap.
- `GAP-OP-672`: workflow dependency and shared-helper enforcement gap.
- `GAP-OP-673`: governance doc parity gap.


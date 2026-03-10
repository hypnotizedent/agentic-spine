---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-13
scope: slash-command
---

# /ctx - Load Context

Load canonical session context for the current run.

## Actions

1. Read `AGENTS.md` (repo root) for the full agent contract.
2. Read `docs/governance/SESSION_PROTOCOL.md` for session protocol.
3. Read `docs/governance/HOST_DRIFT_POLICY.md` for drift policy.
4. Show current git branch and recent commits.
5. Run `./bin/ops status` for unified work status.
6. Run `./bin/ops loops list --open` to check open loops.
7. Check RAG availability: call `rag_health` (spine-rag MCP). Report "RAG: available" or "RAG: unavailable".

## Output

Summarize loaded context, active loop state, and RAG availability.

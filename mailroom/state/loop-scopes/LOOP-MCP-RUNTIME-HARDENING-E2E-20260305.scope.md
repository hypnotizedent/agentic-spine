---
loop_id: LOOP-MCP-RUNTIME-HARDENING-E2E-20260305
created: 2026-03-05
status: closed
owner: "@ronny"
scope: wave
priority: high
horizon: now
execution_readiness: runnable
execution_mode: orchestrator_subagents
objective: Harden MCP runtime governance end-to-end across contract, drift gate, health probe, config projection, and anti-drift cycle
---

# Loop Scope: LOOP-MCP-RUNTIME-HARDENING-E2E-20260305

## Objective

Harden MCP runtime governance end-to-end across contract, drift gate, health probe, config projection, and anti-drift cycle

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-MCP-RUNTIME-HARDENING-E2E-20260305`

## Phases
- Lane A: Fix D148 runtime binding drift permanently (ROOT resolution, plist crash safety)
- Lane B: Bring standalone MCP servers under governance (github, filesystem, docker in contract)
- Lane C: Generate Claude Desktop MCP config from contract (projection generator)
- Lane D: MCP process health enforcement + recovery (health probe fix, recovery action)
- Lane E: Anti-drift wiring + final reconcile/closeout

## Success Criteria
- D148 passes in worktree with BASH_SOURCE resolution
- All Claude Desktop MCP servers registered in contract v3
- mcp.config.generate --check PASS (projection parity)
- mcp.health.probe 15/15 REACHABLE
- Anti-drift cycle expanded with health + config checks
- All gaps filed and closed with fix references

## Definition Of Done
- Branch merged to main or ready for merge
- All gaps closed with fixed_in references
- verify.run fast 20/20 PASS
- Loop scope closed

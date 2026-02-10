---
loop_id: LOOP-JSONL-SCOPE-MIGRATION-20260210
status: active
severity: critical
owner: "@ronny"
created: 2026-02-10
---

# Loop Scope: JSONL→Scope File Migration (Critical Breakage)

## Problem

LOOP-MAILROOM-CONSOLIDATION-20260210 deleted `open_loops.jsonl` and rewrote
`ops loops list/show/close/summary` to use scope files. But 5 scripts still
hard-depend on the deleted JSONL file:

1. `ops/plugins/audit/bin/agent-session-closeout` — hard-fails (D61 requires every 48h)
2. `surfaces/verify/d61-session-loop-traceability-lock.sh` — D61 gate broken
3. `ops/plugins/loops/bin/loops-ledger-reduce` — entire script is JSONL-based
4. `ops/plugins/loops/bin/loops-reconcile` — reads JSONL to auto-close OL_* loops
5. `ops/commands/loops.sh` collect — writes to missing JSONL (deprecated)

Plus doc references in SESSION_PROTOCOL.md, MAILROOM_RUNBOOK.md, etc.

## Plan

- **Rewrite**: agent-session-closeout + d61 gate → read scope file frontmatter
- **Deprecate**: loops-ledger-reduce + loops-reconcile → stub with message (OL_* loops no longer generated)
- **Clean up**: loops.sh collect → full no-op, doc references updated

## Acceptance

- `ops cap run agent.session.closeout` succeeds
- `ops cap run spine.verify` passes D61
- No script references `open_loops.jsonl` as a required input

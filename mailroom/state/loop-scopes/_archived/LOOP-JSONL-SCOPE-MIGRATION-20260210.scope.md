---
loop_id: LOOP-JSONL-SCOPE-MIGRATION-20260210
status: closed
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

Additionally, the running mailroom bridge still served `/loops/open` from the
deleted `mailroom/state/open_loops.jsonl`, causing clients to see **zero open loops**
even when scope files exist.

## Plan

- **Rewrite**: agent-session-closeout + d61 gate → read scope file frontmatter
- **Deprecate**: loops-ledger-reduce + loops-reconcile → stub with message (OL_* loops no longer generated)
- **Clean up**: loops.sh collect → full no-op, doc references updated
- **Fix bridge**: mailroom bridge `/loops/open` → read scope file frontmatter

## Acceptance

- `ops cap run agent.session.closeout` succeeds
- `ops cap run spine.verify` passes D61
- Mailroom bridge `/loops/open` returns scope-backed open loops (no dependency on `open_loops.jsonl`)
- No runtime script depends on `open_loops.jsonl` as a required input

## Evidence

- Receipt (`spine.verify` PASS): `receipts/sessions/RCAP-20260210-161235__spine.verify__Ravuw72958/receipt.md`
- Receipt (`agent.session.closeout` PASS): `receipts/sessions/RCAP-20260210-160520__agent.session.closeout__Rlf7f68958/receipt.md`
- Receipt (restart bridge with new `/loops/open` implementation): `receipts/sessions/RCAP-20260210-161208__mailroom.bridge.start__Rcn9r72354/receipt.md`

---
loop_id: LOOP-MOBILE-COMMAND-CENTER-20260302
created: 2026-03-02
status: planned
owner: "@ronny"
scope: agentic-spine
horizon: later
execution_readiness: blocked
priority: medium
parent_loop: null
discovered_by: "SPINE-CONTROL-01-session-20260302"
---

# Loop Scope: Mobile Command Center

## Problem Statement

The mobile bridge currently provides read-only dashboard capabilities. From mobile (claude.ai, Claude iOS), users can:
- Query spine state via `surface.mobile.dashboard.status`
- Read loops, gaps, proposals via allowlisted caps
- Query RAG via `/rag/ask`
- Enqueue tasks via `POST /inbox/enqueue`

**However**, the full potential of mobile as a "command center" remains untapped:
1. **Task submission is under-exercised** — `/inbox/enqueue` exists but the flow from mobile → task → desktop execution is not fully validated
2. **Session bootstrap friction** — every mobile session cold-starts, requiring skill bootstrap and health checks
3. **Cap allowlist gaps** — strategic read-only caps (e.g., `loops.show <id>`, `receipts.recent`) would make mobile more self-sufficient

The highest leverage unlock is **turning mobile from a read-only dashboard into a true async command loop** where mobile can draft work that desktop executes.

## Deliverables

### D1: Mobile → Inbox → Desktop Execution Flow (End-to-End)
- Validate the `/inbox/enqueue` → mailroom worker → desktop pickup flow
- Create mobile-accessible task templates for common operations (file gap, create loop, submit proposal)
- Document the async command pattern in SESSION_PROTOCOL.md mobile section

### D2: Mobile Session Hot-Start (Optional Enhancement)
- Explore bridge-aware Claude memory/session protocol
- Reduce bootstrap friction for returning mobile sessions
- Consider lightweight "spine context" injection for mobile sessions

### D3: Cap Allowlist Expansion (Strategic)
- Evaluate and add high-value read-only caps to bridge allowlist:
  - `loops.show` (deep-dive specific loop)
  - `receipts.recent` (quick audit trail)
  - `gaps.show` (specific gap details)
  - `proposals.show` (specific proposal details)
- Maintain security boundary (read-only, no mutating caps via RPC)

## Acceptance Criteria

1. **D1 Complete**: From claude.ai mobile session, user can enqueue a task that desktop SPINE-EXECUTION-01 picks up and executes with receipt
2. **Flow Documented**: SESSION_PROTOCOL.md mobile section includes async command pattern with examples
3. **Templates Available**: At least 3 mobile task templates exist (gap, loop, proposal)
4. **Optional D2/D3**: If pursued, documented with receipts and verification

## Constraints

- **No direct mutating caps via bridge RPC** — all mutations flow through mailroom task queue
- **Maintain terminal isolation** — mobile enqueues, desktop executes
- **Security boundary preserved** — token auth required, no anonymous access
- **Horizon: later** — this is enhancement work, not blocking current operations

## Dependencies

- mailroom.bridge.* capabilities (active and verified)
- mailroom.task.worker.* capabilities (active)
- SPINE-EXECUTION-01 terminal (active)

## Linked Gaps

- GAP-OP-1320: Mobile task submission flow not end-to-end validated
- GAP-OP-1322: No mobile task templates for common operations
- GAP-OP-1321: Strategic cap allowlist gaps for mobile self-sufficiency

## Receipts

(To be populated during execution)

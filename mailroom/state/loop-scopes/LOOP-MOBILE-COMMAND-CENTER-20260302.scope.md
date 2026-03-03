---
loop_id: LOOP-MOBILE-COMMAND-CENTER-20260302
created: 2026-03-02
status: closed
owner: "@ronny"
scope: agentic-spine
horizon: now
execution_readiness: runnable
priority: medium
parent_loop: null
discovered_by: "SPINE-CONTROL-01-session-20260302"
closed_at: "2026-03-03"
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

## Execution Evidence

### W0: Baseline
- Bridge: running (PID 7454), health OK on local/tailnet/public
- Cap-RPC via bridge: `loops.status` returned done, exit_code=0
- Run keys: `CAP-20260302-185924__mailroom.bridge.status__Ri31438368`, `CAP-20260302-185925__mailroom.bridge.expose.status__Rhnr538644`

### W1: E2E Mobile Command Flow (GAP-OP-1320) - FIXED
- **Success test**: Task `TASK-20260303T042243Z-5ca8` → `done/` via `lifecycle.health`
  - Run key: `CAP-20260302-232554__lifecycle.health__R03k85144`
  - Receipt: `receipts/sessions/RCAP-20260302-232554__lifecycle.health__R03k85144/receipt.md`
- **Fail test**: Task `TASK-20260303T042250Z-641f` → `failed/` (capability_not_allowlisted)
- **Inbox test**: `S20260302-232352__w1-inbox-test__R522` → full lifecycle (enqueue → watcher → process → outbox)
- Worker contract allows 6 caps: verify.pack.run, verify.core.run, loops.progress, proposals.status, stability.control.snapshot, lifecycle.health

### W2: Template Pack (GAP-OP-1322) - FIXED
- 3 mobile templates created at `mailroom/templates/mobile/`:
  - `file-gap.template.json` — file operational gap via inbox
  - `create-loop.template.json` — create governed loop via inbox
  - `submit-proposal.template.json` — submit change proposal via inbox
- Each template includes: endpoint, headers, payload schema, filled example, expected receipt

### W3: Cap Allowlist Expansion (GAP-OP-1321) - FIXED
- 7 read-only caps added to `mailroom.bridge.consumers.yaml` allowlist:
  - `loops.list`, `loops.progress`, `gaps.aging`, `receipts.summary`, `receipts.search`, `receipts.trends`, `proposals.list`
- All added to monitor role for mobile access
- Consumers sync: OK, D116: 4/4 PASS
- Bridge restarted to load new allowlist (PID 7454)
- Total allowlist: 24 → 31 capabilities

### W4: Performance Measurements
| Capability | Median (3 runs) | Classification |
|---|---|---|
| loops.status | 0.64s | Fast |
| gaps.status | 1.83s | Normal |
| loops.list | 9.49s | Slow |
| loops.progress | 0.62s | Fast |
| gaps.aging | 0.72s | Fast |
| receipts.summary | 0.70s | Fast |
| receipts.search | 0.66s | Fast |
| receipts.trends | 0.70s | Fast |
| proposals.list | 0.76s | Fast |
| proposals.status | 2.49s | Normal |
| surface.mobile.dashboard.status | 106.24s | Heavy (runs spine.control.tick) |

- Recommendation: mobile clients should use specific read caps, not the heavy dashboard
- No deterministic perf defect to file (dashboard latency is inherent to aggregation scope)

### W5: Closeout
- verify.run -- fast: 10/10 PASS (run key: `CAP-20260302-233811__verify.run__Rw0ol34410`)
- All 3 gaps closed: GAP-OP-1320 (fixed), GAP-OP-1321 (fixed), GAP-OP-1322 (fixed)
- No orphan linkage (all gaps have parent_loop)

## Verify Results
- `verify.run -- fast`: 10/10 PASS
- D116 mailroom-bridge-consumers-registry-lock: 4/4 PASS

## Blocker Classification
- No blockers. All deliverables met.
- D2 (Mobile Session Hot-Start) was optional and not pursued — deferred as future enhancement.

## Cleanup Proof
- Bridge restarted with updated allowlist
- All gap statuses updated in operational.gaps.yaml
- Loop scope updated with full evidence

## Linkage
- GAP-OP-1320: fixed (W1 E2E)
- GAP-OP-1321: fixed (W3 allowlist)
- GAP-OP-1322: fixed (W2 templates)

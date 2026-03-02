# PLAN: Mobile Command Center — Async Command Loop

> **Loop:** LOOP-MOBILE-COMMAND-CENTER-20260302
> **Status:** planned (horizon: later)
> **Created:** 2026-03-02
> **Owner:** @ronny
> **Terminal:** SPINE-CONTROL-01

---

## Executive Summary

The mobile bridge (`https://spine.ronny.works`) currently provides read-only dashboard capabilities. This plan outlines the work to transform mobile from a **read-only dashboard** into a **true async command center** where mobile sessions can draft work that desktop terminals execute.

**Highest leverage unlock:** `/inbox/enqueue` → mailroom worker → desktop execution flow.

---

## Current State Analysis

### What's Already Working

| Capability | Status | Notes |
|------------|--------|-------|
| `surface.mobile.dashboard.status` | ✅ Active | JSON envelope from spine control tick |
| Bridge HTTP API | ✅ Active | `https://spine.ronny.works` via Cloudflare Tunnel |
| `/health` endpoint | ✅ Active | Unauthenticated liveness probe |
| `/loops/open` | ✅ Active | List open loops from scope files |
| `/outbox/read` | ✅ Active | Read outbox file contents |
| `/receipts/read` | ✅ Active | Read receipt files |
| `/rag/ask` | ✅ Active | Governed RAG query |
| `/cap/run` | ✅ Active | Execute 18 allowlisted caps |
| `/inbox/enqueue` | ✅ Active | Enqueue tasks into mailroom queue |
| CF Access Auth | ✅ Active | Service-token auth for hosted runtimes |

### Cap-RPC Allowlist (Current)

```
spine.verify, surface.mobile.dashboard.status, gaps.status, loops.status,
proposals.status, policy.runtime.audit, tenant.storage.audit,
version.compat.verify, evidence.export.plan, surface.readonly.audit,
mailroom.bridge.status, mailroom.task.enqueue, mailroom.task.claim,
mailroom.task.heartbeat, mailroom.task.complete, mailroom.task.fail,
aof.status, aof.version, aof.policy.show, aof.tenant.show, aof.verify,
media.health.check, media.service.status, media.nfs.verify
```

### Gaps Identified

| Gap ID | Description | Severity |
|--------|-------------|----------|
| GAP-OP-1320 | Mobile task submission flow not end-to-end validated | medium |
| GAP-OP-1322 | No mobile task templates for common operations | low |
| GAP-OP-1321 | Strategic cap allowlist gaps for mobile self-sufficiency | low |

---

## Deliverables

### D1: Mobile → Inbox → Desktop Execution Flow (PRIMARY)

**Goal:** Validate and document the complete async command loop.

**What's needed:**
1. **Validation Test**
   - From mobile/remote, enqueue a test task via `/inbox/enqueue`
   - Verify mailroom worker picks up the task
   - Verify desktop SPINE-EXECUTION-01 executes with receipt
   - Document the flow with receipts

2. **Task Templates**
   - Create 3 mobile-accessible task templates:
     - `mobile-task-gap.yaml` — file a gap from mobile
     - `mobile-task-loop.yaml` — create a loop scope from mobile
     - `mobile-task-proposal.yaml` — submit a proposal from mobile
   - Store in `mailroom/state/mobile-templates/`

3. **Documentation Update**
   - Update `docs/governance/SESSION_PROTOCOL.md` mobile section
   - Add async command pattern with examples
   - Include template usage guide

**Files to modify:**
- `mailroom/state/mobile-templates/` (new directory)
- `docs/governance/SESSION_PROTOCOL.md`
- `docs/governance/MAILROOM_BRIDGE.md`

### D2: Mobile Session Hot-Start (OPTIONAL)

**Goal:** Reduce bootstrap friction for returning mobile sessions.

**Approach:**
- Explore bridge-aware Claude memory/session protocol
- Consider lightweight "spine context" injection
- May require skill surface updates

**Status:** Deferred until D1 complete.

### D3: Cap Allowlist Expansion (OPTIONAL)

**Goal:** Make mobile sessions more self-sufficient.

**Proposed additions:**
- `loops.show` — deep-dive a specific loop
- `receipts.recent` — quick audit trail
- `gaps.show` — specific gap details
- `proposals.show` — specific proposal details

**Constraint:** Read-only only. No mutating caps via RPC.

**Status:** Deferred until D1 complete.

---

## Execution Waves

### Wave 1: Validation (D1.1)
- [ ] Test `/inbox/enqueue` from mobile/remote
- [ ] Verify mailroom worker processing
- [ ] Verify desktop execution with receipt
- [ ] Document validation results

### Wave 2: Templates (D1.2)
- [ ] Create `mailroom/state/mobile-templates/` directory
- [ ] Create `mobile-task-gap.yaml` template
- [ ] Create `mobile-task-loop.yaml` template
- [ ] Create `mobile-task-proposal.yaml` template
- [ ] Add template usage to MAILROOM_BRIDGE.md

### Wave 3: Documentation (D1.3)
- [ ] Update SESSION_PROTOCOL.md mobile section
- [ ] Add async command pattern with examples
- [ ] Add template usage guide
- [ ] Verify docs pass lint

### Wave 4 (Optional): D2/D3
- [ ] Evaluate hot-start approach
- [ ] Evaluate cap allowlist additions
- [ ] File separate gaps if pursued

---

## Verification

**D1 Complete when:**
- [ ] End-to-end flow validated with receipts
- [ ] 3 templates exist and are documented
- [ ] SESSION_PROTOCOL.md updated
- [ ] `./bin/ops cap run verify.core.run` passes

---

## Dependencies

| Dependency | Status | Notes |
|------------|--------|-------|
| mailroom.bridge.start | Active | Bridge running |
| mailroom.bridge.expose.enable | Active | Public HTTPS via CF Tunnel |
| mailroom.task.worker.start | Active | Worker daemon running |
| SPINE-EXECUTION-01 | Active | Desktop execution terminal |

---

## Security Considerations

- **Token auth required** for all non-health endpoints
- **CF Access service tokens** for hosted runtimes
- **No mutating caps via RPC** — all mutations through task queue
- **Terminal isolation** — mobile enqueues, desktop executes

---

## References

- `docs/governance/MAILROOM_BRIDGE.md`
- `docs/governance/SESSION_PROTOCOL.md`
- `ops/bindings/mailroom.bridge.yaml`
- `ops/bindings/mailroom.bridge.consumers.yaml`
- `ops/bindings/terminal.role.contract.yaml`

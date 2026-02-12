---
status: open
owner: "@ronny"
created: 2026-02-12
scope: loop-scope
loop_id: LOOP-MULTI-AGENT-ENTRY-ENFORCEMENT-20260212
severity: medium
---

# Loop Scope: LOOP-MULTI-AGENT-ENTRY-ENFORCEMENT-20260212

## Goal

Fix D66 parity drift (if any) and close the multi-agent session signaling gap.
Hotkey-launched terminals must not silently disrupt the system. Sessions need
liveness detection, stale pruning, concurrency signaling, and commit guards.

## GAP

GAP-OP-116: Multi-agent session signaling and enforcement missing.

## Boundary Rule

Spine + workbench repos only. No VM/infra changes.

## Success Criteria

1. D66 PASS.
2. Opening multiple sessions sets `SPINE_MULTI_AGENT=true` on second+ sessions.
3. Stale sessions are auto-pruned/archived.
4. Multi-agent banner appears in session entry hook.
5. Direct commit guard blocks unsafe commits in multi-agent mode.
6. GAP-OP-116 fixed and closed.

## Phases

### P0: Baseline
- [x] ops status: 0 loops, 0 gaps
- [x] spine.verify: PASS D1-D71
- [x] D66: PASS (currently clean)
- [x] 30 stale sessions in mailroom/state/sessions/

### P1: Immediate D66 repair
- [x] D66 PASS — no repair needed (already clean)

### P2: Session liveness + concurrency signal
- [ ] Add session pruning (dead PID + TTL > 4h → archive)
- [ ] Count active peer sessions with liveness check
- [ ] Export SPINE_ACTIVE_SESSION_COUNT and SPINE_MULTI_AGENT in env.sh

### P3: Hook warning upgrade
- [ ] Patch session-entry-hook to count active sessions
- [ ] Print hard warning banner when multi-agent active

### P4: Enforcement (commit guard)
- [ ] Patch pre-commit hook to detect multi-agent mode
- [ ] Block direct commits when multi-agent active unless apply-owner lock held
- [ ] Fail fast with clear remediation message

### P5: Verification + closeout
- [ ] spine.verify PASS
- [ ] ops status 0 open
- [ ] gaps.status 0 open
- [ ] Loop closed with evidence

# LOOP-AOF-CONSUMER-ROLLOUT-ACCEPTANCE-20260215

**Status:** closed
**Opened:** 2026-02-15
**Owner:** @ronny
**Terminal:** claude-code

## Objective

Prove end-to-end that the 5 AOF operator capabilities work through the live
mailroom bridge /cap/run endpoint, with proper RBAC scoping and receipted
evidence. This is the final acceptance gate before freezing AOF v1 baseline.

## Gaps

| Gap | Type | Severity | Description |
|-----|------|----------|-------------|
| GAP-OP-461 | runtime-bug | high | Live /cap/run smoke test: all 5 aof.* caps return 200 with valid JSON envelopes |
| GAP-OP-459 | runtime-bug | high | Monitor RBAC proof: monitor token gets 200 for aof.status+aof.version, 403 for the other 3 |
| GAP-OP-460 | runtime-bug | medium | Receipt chain validation: every bridge-invoked cap produces a valid receipt on disk with ledger linkage |

## Exit Criteria

- [ ] 5/5 aof.* caps succeed via live /cap/run with valid JSON envelopes
- [ ] Monitor gets 200 only for aof.status + aof.version, and 403 for the other 3
- [ ] Every bridge-invoked run produces a valid receipt on disk and ledger linkage
- [ ] One acceptance summary receipt capturing all evidence

## Closure

All 3 gaps closed. 15/15 acceptance tests passing.
Implementation commit: 37a1be9. spine.verify: all gates PASS.

Bonus fix: mailroom-bridge-start now auto-injects RBAC role tokens into
launchd plist from state files (monitor token was not being passed to bridge
subprocess).

## Post-Loop

AOF enters maintenance mode (v1 baseline frozen). Future changes are gap-driven only.

# LOOP-AOF-BRIDGE-CONSUMER-V12-20260215

**Status:** open
**Opened:** 2026-02-15
**Owner:** @ronny
**Terminal:** claude-code

## Objective

Expose the 5 read-only AOF operator capabilities (aof.status, aof.version,
aof.policy.show, aof.tenant.show, aof.verify) via the mailroom bridge /cap/run
endpoint. This completes the AOF consumer surface for remote agents (iPhone,
Claude.ai, monitoring dashboards).

## Gaps

| Gap | Type | Severity | Description |
|-----|------|----------|-------------|
| GAP-OP-449 | missing-entry | high | Add 5 aof.* caps to cap_rpc.allowlist in mailroom.bridge.yaml |
| GAP-OP-450 | missing-entry | medium | Add role-scoped RBAC entries (operator/monitor) for aof.* caps |
| GAP-OP-451 | runtime-bug | high | Integration tests: /cap/run for each AOF cap returns JSON envelope + receipt |
| GAP-OP-452 | stale-ssot | medium | Update MAILROOM_BRIDGE.md with AOF consumer examples and JSON contract |

## Constraints

- All 5 AOF caps are read-only — safe for bridge allowlist
- aof.verify runs drift gates (D91-D97) — timeout must accommodate gate execution
- Monitor role should get aof.status and aof.version only (minimal surface)
- Operator role gets all 5 AOF caps

## Success Criteria

- [ ] All 5 aof.* caps in allowlist and passing via /cap/run
- [ ] RBAC roles scoped correctly
- [ ] Integration tests passing
- [ ] Bridge docs updated with AOF examples

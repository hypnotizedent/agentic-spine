---
loop_id: LOOP-PIHOLE-BLOCKLIST-NORMALIZATION-20260223
created: 2026-02-23
status: closed
owner: "@ronny"
scope: pihole
priority: medium
objective: Normalize Pi-hole blocklist configuration across shop (infra-core) and home (pihole-home) instances, file gaps for missing secrets, API friction, and absent sync capability
---

# Loop Scope: LOOP-PIHOLE-BLOCKLIST-NORMALIZATION-20260223

## Objective

Normalize Pi-hole blocklist configuration across shop (infra-core) and home (pihole-home) instances, file gaps for missing secrets, API friction, and absent sync capability.

## Context

Hagezi Pro blocklist was added to both instances during this session. Several governance gaps were discovered:

1. Home Pi-hole password not in Infisical (GAP-OP-835)
2. Neither Pi-hole password in secrets.inventory.yaml (GAP-OP-836)
3. Pi-hole v6 API agent navigability friction (GAP-OP-837)
4. No blocklist congruence sync capability (GAP-OP-838)

## Completion Criteria

- All 4 gaps filed and linked to this loop
- Secrets normalized in Infisical and inventory (835/836)
- API gotchas documented for agent use (837)
- Sync capability gap tracked for future implementation (838)

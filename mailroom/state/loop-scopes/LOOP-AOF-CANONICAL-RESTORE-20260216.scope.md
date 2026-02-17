---
loop_id: LOOP-AOF-CANONICAL-RESTORE-20260216
created: 2026-02-16
status: closed
owner: "@ronny"
scope: agentic-spine
objective: One-shot canonical restore — fix latent D129 violations in home.device.registry.yaml and mirror terminal naming into entry surfaces.
---

## Context

Post-settlement canonical cleanup. home.device.registry.yaml has disallowed keys (vmid, notes) with no legacy exception — latent D129 violation. AGENTS.md and CLAUDE.md lack canonical terminal role references.

## Done Checks

- [x] home.device.registry.yaml vmid→vm_id, notes→description
- [x] Terminal naming block in AGENTS.md (outside D65 embed)
- [x] Terminal naming block in CLAUDE.md (outside D65 embed)
- [x] D129 gate audit PASS (0 violations)
- [x] verify.core.run 8/8 PASS
- [x] verify.domain.run aof 18/18 PASS
- [x] terminal.contract.status PASS (5 roles)
- [x] proposals.status 0 pending
- [x] GAP-OP-570 closed
- [x] Commit + push

## Result

All items resolved. D129 latent violation cleared. Terminal naming mirrored to entry surfaces outside D65 embed boundary.

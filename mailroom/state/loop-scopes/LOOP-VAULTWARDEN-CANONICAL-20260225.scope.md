---
loop_id: LOOP-VAULTWARDEN-CANONICAL-20260225
created: 2026-02-25
status: active
owner: "@ronny"
scope: vaultwarden
priority: high
objective: Establish canonical Vaultwarden governance: fix backup drift, create workbench home, define VW-Infisical contract, scaffold read-only audit capabilities
---

# Loop Scope: LOOP-VAULTWARDEN-CANONICAL-20260225

## Objective

Establish canonical Vaultwarden governance: fix backup drift, create workbench home, define VW-Infisical contract, scaffold read-only audit capabilities

## Linked Gaps

| Gap | Severity | Status | Description |
|-----|----------|--------|-------------|
| GAP-OP-878 | high | **fixed** | Backup script path drift (host + data dir) |
| GAP-OP-879 | high | open | No folders — flat namespace |
| GAP-OP-880 | medium | open | 336 items in trash (42%) |
| GAP-OP-881 | medium | open | Admin plaintext token not in Infisical |
| GAP-OP-882 | low | open | Only 2/422 logins have TOTP |

## Stage 1 Deliverables (repo-safe, no live mutations)

- [x] Fixed backup-path drift in `workbench/scripts/root/backup/backup-vaultwarden.sh`
- [x] Created canonical workbench home: `workbench/infra/compose/vaultwarden/`
- [x] Created Vaultwarden-Infisical SSOT contract: `docs/governance/VAULTWARDEN_INFISICAL_CONTRACT.md`
- [x] Scaffolded 3 read-only capabilities: vault.audit, item.list, backup.verify
- [x] Filed 5 gaps (878-882), closed 878

## Stage 2 (requires GO-LIVE-VAULTWARDEN approval)

- [ ] Vault folder creation (GAP-OP-879)
- [ ] Trash review and purge (GAP-OP-880)
- [ ] Admin token plaintext rotation into Infisical (GAP-OP-881)
- [ ] TOTP coverage review (GAP-OP-882)
- [ ] Overlap-zone reconciliation run

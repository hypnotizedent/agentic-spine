---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-17
scope: p1-wave-2b-governance-parity
parent_loop: LOOP-RONNY-OPS-FINAL-EXTRACTION-SWEEP-20260217
---

# P1 Governance Parity Reconciliation (2026-02-17)

## Source Extraction

Legacy references reviewed (read-only):

- `/Users/ronnyworks/ronny-ops/docs/runbooks/BACKUP_GOVERNANCE.md`
- `/Users/ronnyworks/ronny-ops/docs/runbooks/REBOOT_HEALTH_GATE.md`
- `/Users/ronnyworks/ronny-ops/docs/governance/SSOT_REGISTRY.yaml`

Current spine targets reviewed:

- `docs/governance/BACKUP_GOVERNANCE.md`
- `docs/governance/REBOOT_HEALTH_GATE.md`
- `docs/governance/SSOT_REGISTRY.yaml`
- `ops/bindings/governance.parity.reconcile.20260217.yaml`

## Delta Decisions (Explicit Accept/Reject)

| Area | Legacy Delta | Decision | Spine Action |
|---|---|---|---|
| Backup governance location | Legacy stored full runbook in `docs/runbooks/BACKUP_GOVERNANCE.md` | **Accept move** to cross-repo authority surface | Keep spine pointer stub at `docs/governance/BACKUP_GOVERNANCE.md` to workbench canonical doc; reject duplicating full runbook in spine |
| Backup tier language | Legacy included numeric tier table (1/2/3) in the runbook | **Reject direct carry-forward** | Keep current binding-driven classification contract (`critical/important/rebuildable` in `ops/bindings/backup.inventory.yaml`) |
| Reboot hard-stop checks | Legacy runbook had explicit STOP checks (ZFS degraded, vzdump active, migration, disk headroom) | **Accept** | Added `Hard Stop Conditions` section to `docs/governance/REBOOT_HEALTH_GATE.md` |
| Reboot diagnosis rule | Legacy note: VM stopped is not network outage | **Accept** | Added post-reboot runtime-state check note to `docs/governance/REBOOT_HEALTH_GATE.md` |
| SSOT registry backup/reboot paths | Legacy paths pointed at `docs/runbooks/*`; spine uses `docs/governance/*` and external authority for backup details | **Accept** | Keep spine registry as canonical for spine-scoped paths and cross-repo authority pointers |
| SSOT scope breadth | Legacy registry carried many non-spine operational entries | **Reject broad import** | Keep spine registry scope-limited; non-spine entries remain removed with rationale comments in `docs/governance/SSOT_REGISTRY.yaml` |

## Outcome

P1-15 parity deltas are reconciled with explicit decision trace. Backup, reboot, and SSOT-registry differences are either integrated into spine governance or intentionally rejected with bounded rationale.

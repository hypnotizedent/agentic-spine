---
loop_id: LOOP-PAPERLESS-STATEFUL-BACKUP-DESTRUCTIVE-GUARD-HARDENING-20260308
created: 2026-03-08
status: active
owner: "@ronny"
scope: backup
priority: critical
horizon: now
execution_readiness: runnable
objective: Reconstruct the Paperless wipe incident chain end-to-end and harden stateful backup, offsite, restore, and destructive-runtime safeguards across the Mint/finance/home-lab estate.
---

# Loop Scope: LOOP-PAPERLESS-STATEFUL-BACKUP-DESTRUCTIVE-GUARD-HARDENING-20260308

## Objective

Reconstruct the Paperless wipe incident chain end-to-end and harden stateful backup, offsite, restore, and destructive-runtime safeguards across the Mint/finance/home-lab estate.

## Problem Statement

A stateful finance service was wiped while backup transport had been silently failing for multiple days. Local artifacts were eligible for cleanup before verified offsite durability, restore posture was not current enough to prove recovery, and runtime/destructive paths did not force a sufficient break-glass flow. The failure class may extend beyond Paperless into other Proxmox-backed VMs and compose-managed stateful services.

## Deliverables

- Incident root-cause chain with evidence and exact causal links across runtime, backup execution, transport, posture/proof, and repo drift.
- Stateful service matrix covering VM 211, VM 212, VM 213, VM 214 if active, home-vm-100, and other relevant stateful services and storage lanes.
- Executable hardening across backup success criteria, offsite verification, restore proof visibility, and destructive-runtime safeguards.
- Canonical receipts/artifacts under `mailroom/state/` that allow another agent to answer where state lives, how it is protected, and what blocks unsafe destruction.

## Acceptance Criteria

- Paperless failure chain is documented with evidence, including why the wipe path succeeded and why backup/offsite/alerting did not stop it earlier.
- Every inspected critical stateful workload is classified as `safe`, `needs_backup_hardening`, `needs_restore_proof`, `needs_destructive_guard`, or `critical_risk`.
- Critical services no longer report success when offsite copy failed or cleanup would discard the newest recovery artifact.
- At least one representative destructive guard is verified to block unsafe stack actions without explicit break-glass intent.
- Restore-proof posture and backup freshness/offsite truth are visible from Spine for critical services.

## Constraints

- Preserve evidence and surviving recovery artifacts.
- Do not delete backups or make destructive infrastructure changes without exact proof.
- Prefer governed Spine surfaces; direct host changes require explicit receipts and rationale.
- Keep work authoritative: patch canonical bindings/docs/scripts instead of creating parallel truth surfaces.

## Guard Commands

- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Backup Domain Verify**: `./bin/ops cap run verify.run -- domain backup`
- **Finance Domain Verify**: `./bin/ops cap run verify.run -- domain finance`

## Canonical Artifacts

- `docs/governance/FINANCE_STACK_DOCTRINE_V1.md` — canonical finance stack governance rules
- `docs/governance/FINANCE_STACK_OPERATOR_CHECKLIST.md` — executable operator checklist
- `mailroom/state/paperless-backup-incident/root-cause-receipt-20260308.md`
- `mailroom/state/paperless-backup-incident/stateful-service-matrix-20260308.yaml`
- `mailroom/state/paperless-backup-incident/hardening-verification-20260308.yaml`

## Linked Gaps

- GAP-OP-1512

## Phases

- P1: incident chain reconstruction and evidence preservation
- P2: stateful workload risk sweep and posture matrix
- P3: backup/offsite/restore/destructive-guard hardening
- P4: verification, receipts, and repo/runtime authority alignment

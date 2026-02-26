---
loop_id: LOOP-MAIL-ARCHIVER-TAKEOUT-IMPORT-PLAN-20260226-20260226
created: 2026-02-26
status: active
owner: "@ronny"
scope: mail
priority: high
objective: Open focused execution loop for GAP-OP-922 with staged 200GB takeout import and validation plan before mutation.
---

# Loop Scope: LOOP-MAIL-ARCHIVER-TAKEOUT-IMPORT-PLAN-20260226-20260226

## Objective

Open focused execution loop for GAP-OP-922 with staged 200GB takeout import and validation plan before mutation.

## Steps
- Step 1: Source attestation + checksum baseline
- Step 2: Pilot chunk import with rollback guard
- Step 3: Full staged import windows with SLO monitoring
- Step 4: Post-import validation + archive hold decision

## Success Criteria
- Staged plan includes commands, evidence gates, and abort criteria
- GAP-OP-922 parent_loop points to focused loop

## Definition Of Done
- Loop scope contains runnable staged checklist

## Staged Import Plan

### Stage 0: Preconditions (no mutation)
- Confirm health and storage invariants:
  - `./bin/ops cap run communications.stack.status`
  - `./bin/ops cap run verify.pack.run communications`
  - `./bin/ops cap run services.health.status --id mail-archiver-vm214`
- Confirm backup posture:
  - `./bin/ops cap run backup.status`
  - verify latest `vm-214-communications-stack-primary` artifact freshness.
- Confirm source artifact exists and is stable:
  - `ssh docker-host "ls -lh /mnt/docker/mail-archive-import/All-mail.mbox"`
  - `ssh docker-host "shasum -a 256 /mnt/docker/mail-archive-import/All-mail.mbox > /tmp/all-mail-mbox.sha256"`

Abort criteria:
- Any communications gate fail.
- No fresh VM214 backup artifact.
- Source checksum command fails.

### Stage 1: Pilot import (bounded)
- Produce deterministic pilot slice (first 2GB equivalent message chunk) and import only pilot.
- Capture before/after counts:
  - mailbox count, imported message count, duplicate count, failed count.
- Hold cutover window to <= 30 minutes.

Abort criteria:
- Import error rate > 1%.
- Root usage increases beyond 80% or D233 fails post-pilot.
- Unexpected message duplication spike.

### Stage 2: Full import in windows
- Run import in fixed windows (4-hour blocks) with checkpoint after each block.
- After each block run:
  - `./bin/ops cap run communications.alerts.queue.status`
  - `./bin/ops cap run communications.alerts.queue.slo.status`
  - `./bin/ops cap run services.health.status --id mail-archiver-vm214`

Abort criteria:
- Any SLO incident in communications queue.
- mail-archiver health fails twice consecutively.
- storage quota incident threshold (85%) reached.

### Stage 3: Validation and hold
- Validation set:
  - source checksum unchanged vs Stage 0
  - import totals reconciled vs expected ranges
  - no open dead-letter in communications queue
  - communications pack PASS
- Keep source takeout under retention hold until attestation is signed.

## Evidence Required
- Session run keys for Stage 0/1/2/3 checkpoints.
- Import command transcript locations and checksum artifact path.
- Final validation receipt bundle in this loop scope.

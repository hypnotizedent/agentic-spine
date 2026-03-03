---
loop_id: LOOP-MEDIA-STACK-DISCONNECT-CANONICAL-TRACE-20260303
created: 2026-03-03
status: planned
owner: "@ronny"
scope: media
priority: high
horizon: later
execution_readiness: blocked
objective: Holistic forensic trace of media-stack disconnects mapped to migration history and shop-to-home successor planning (capture-only)
blocked_by:
  - "Runtime mutation intentionally out of scope for this forensic loop"
  - "Shop-to-home migration execution will run in successor loop after operator approval"
---

# Loop Scope: LOOP-MEDIA-STACK-DISCONNECT-CANONICAL-TRACE-20260303

## Objective

Produce a full forensic trace of media-stack disconnects that:
- maps current symptoms to historical migration decisions,
- identifies where contract-to-runtime drift re-entered after split,
- and hands off an execution-ready connector for a future shop-to-home migration loop.

This loop is governance-only and capture-only. No media runtime mutation.

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-MEDIA-STACK-DISCONNECT-CANONICAL-TRACE-20260303`

## Historical Lineage Reviewed

| Era | Artifact | What Landed | What Drifted |
|---|---|---|---|
| 2026-02-08 | `LOOP-MEDIA-STACK-SPLIT-20260208` | VM 201 split into VM 209 (download) + VM 210 (streaming) | Service-level path contracts did not stay normalized across app roots/download paths |
| 2026-02-08..10 | `LOOP-MEDIA-STACK-ARCH-20260208` | NFS/SQLite contention remediations and boot ordering hardening | Follow-through focused on infrastructure stability, not full app-layer status truth |
| 2026-03-01 | `LOOP-MEDIA-HISTORY-CANONICALIZATION-20260301` | Historical reconstruction and canonical host truth updates | Did not establish a continuous regression lock on ingest/request/library parity |
| 2026-03-01 | `LOOP-MEDIA-MAINTAINERR-SEER-HUNTARR-RD-20260301` | ARR/search pipeline remediation and Huntarr deprecation flow | User-facing availability parity still vulnerable when path contracts drift |
| 2026-03-03 | this loop | Current disconnect forensic capture | Pending successor execution loop for runtime fix + migration connector |

## Success Criteria
- Current media disconnects are captured as explicit gaps with evidence.
- Trace explicitly links current breakage to prior migration lineage.
- A machine-readable connector exists for successor shop-to-home planning.
- No runtime mutations are performed in this loop.

## Disconnect Inventory (Current)

| Gap ID | Category | Disconnect |
|---|---|---|
| GAP-OP-1387 | path-authority drift | Radarr root folder expects `/movies` while authoritative mount path is `/media/movies` |
| GAP-OP-1388 | path-authority drift | SAB/Radarr download path contract mismatch (`/downloads/complete/movies`) |
| GAP-OP-1389 | duplicate-truth | Jellyseerr `processing` while Radarr `hasFile=true` and file exists |
| GAP-OP-1390 | queue-reconciliation | Ghost queue items remain `downloadClientUnavailable` despite completed files |
| GAP-OP-1391 | migration contract drift | Split-era path assumptions were not fully normalized end-to-end |
| GAP-OP-1392 | verify blind spot | `hasFile=true` checks can report green while user-facing availability is still broken |
| GAP-OP-1393 | research friction | Stale background failure noise after superseded probe runs |

## Migration Connector (Shop -> Home)

This loop does not execute migration. It defines what must exist before migration work is runnable.

Successor planning anchor:
- `LOOP-MEDIA-SHOP-HOME-MIGRATION-CONNECTOR-20260303`

Required connector layers:
1. **Path authority contract**
   Every service path tuple must be explicit and parity-checked:
   `compose mount -> app root -> download client path -> library visibility path`.
2. **Status truth contract**
   Authority progression must be deterministic:
   `Radarr import complete -> Jellyseerr availability -> Jellyfin library visibility`.
3. **Cutover preflight baseline**
   Home-side target readiness must be declared: storage, network throughput, transcode posture, and backup/rollback surfaces.
4. **Transactional execution packet**
   Future migration loop must declare dry-run, cutover, rollback, and post-cutover verify matrix before mutation.

## Deliverables

- Updated loop scope with full forensic lineage and migration connector.
- Holistic forensic report:
  `mailroom/state/loop-scopes/MEDIA-STACK-HOLISTIC-FORENSIC-TRACE-20260303.md`
- Gap pack for missing shop-to-home migration connector surfaces (successor loop-linked).

## Definition Of Done
- Forensic artifacts are committed and linked.
- Gaps are linked to the appropriate forensic or successor planning loop.
- Runtime mutation remains deferred to successor execution loop(s).

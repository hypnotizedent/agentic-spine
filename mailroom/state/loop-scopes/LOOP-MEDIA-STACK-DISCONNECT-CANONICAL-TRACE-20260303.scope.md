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

| Gap ID | Category | Disconnect | Contract Reference |
|---|---|---|---|
| GAP-OP-1387 | path-authority drift | Radarr root folder expects `/movies` while authoritative mount path is `/media/movies` | `media.path.authority.contract.yaml` (Lane A runtime) |
| GAP-OP-1388 | path-authority drift | SAB/Radarr download path contract mismatch (`/downloads/complete/movies`) | `media.path.authority.contract.yaml` (Lane A runtime) |
| GAP-OP-1389 | duplicate-truth | Jellyseerr `processing` while Radarr `hasFile=true` and file exists | `media.availability.progression.contract.yaml` (Lane B D1) |
| GAP-OP-1390 | queue-reconciliation | Ghost queue items remain `downloadClientUnavailable` despite completed files | `media.queue.reconciliation.policy.yaml` (Lane B D2) |
| GAP-OP-1391 | migration contract drift | Split-era path assumptions were not fully normalized end-to-end | `media.path.authority.contract.yaml` (Lane A runtime) |
| GAP-OP-1392 | verify blind spot | `hasFile=true` checks can report green while user-facing availability is still broken | `media.e2e.verification.spec.yaml` (Lane B D3) |
| GAP-OP-1393 | research friction | Stale background failure noise after superseded probe runs | No contract (agent-behavior note update only, Lane B D4) |

## Contracts Authored (Lane B: Media Trace Normalization)

Lane B authored three draft contracts that define the deterministic availability,
reconciliation, and verification models. These contracts are authoring-only; runtime
enforcement is deferred to a successor execution loop.

| Deliverable | File | Addresses | Status |
|---|---|---|---|
| D1: Availability Progression Contract | `ops/bindings/media.availability.progression.contract.yaml` | GAP-OP-1389 (duplicate-truth), GAP-OP-1405 (connector gap) | draft v1.0 |
| D2: Queue Reconciliation Policy | `ops/bindings/media.queue.reconciliation.policy.yaml` | GAP-OP-1390 (queue ghosting) | draft v1.0 |
| D3: E2E Verification Spec | `ops/bindings/media.e2e.verification.spec.yaml` | GAP-OP-1392 (verify blind spot) | draft v1.0 |
| D4: Agent Task Supersession | (no contract; gap note update only) | GAP-OP-1393 (research friction) | assessed: not contract-worthy |

### D1 Summary: Availability Progression Contract

Enriched the skeleton from the migration connector loop into a full contract defining:
- 6-stage progression: requested, searching, downloading, import_complete, library_visible, request_fulfilled
- Per-stage authority source with API endpoint, pass criteria, and failure meaning
- 3 synchronization handshakes with timing bounds, failure causes, and reconciliation steps
- 5-entry failure taxonomy (AVAIL-F1 through AVAIL-F5) mapping symptoms to root causes
- 4-leg E2E verification chain integrated with the E2E spec

### D2 Summary: Queue Reconciliation Policy

Created a new policy defining:
- 5 queue item classifications (QUEUE-C1 through QUEUE-C5) based on status/hasFile combination
- Clear automation boundary: auto-remove is safe only for QUEUE-C1 (downloadClientUnavailable + hasFile=true) and QUEUE-C4 (completed + hasFile=true)
- Age threshold (72h) for stale warning items
- API-level action definitions for auto_remove and manual_review
- Never-automated boundary (bulk clear, blocklist, client restart)

### D3 Summary: E2E Verification Spec

Created a verification specification defining:
- 4-leg check chain: arr_hasfile, filesystem_exists, jellyfin_indexed, jellyseerr_fulfilled
- Per-leg pass/fail criteria, severity, and dependency ordering
- Verdict logic: AVAILABLE / UNAVAILABLE / DEGRADED / PARTIAL
- 3 sampling modes: targeted, sampled (10 random), full_audit
- Integration with existing media verify pack (D106/D107/D240) and proposed new gate

### D4 Assessment: Agent Task Supersession

GAP-OP-1393 describes research friction from stale background tasks producing
noise after corrected probes succeeded. This is an agent-behavior issue, not
a media pipeline contract issue. Assessment:
- **Not contract-worthy**: the fix is terminal/session-level task management, not a media domain contract
- **Recommended action**: update gap `notes` with "Contract assessment: agent-behavior issue outside media domain scope. Fix belongs in session management or terminal task lifecycle improvements."
- **Status should remain**: open (low severity, agent-behavior type)

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
- Lane B contracts: D1 (availability progression), D2 (queue reconciliation), D3 (E2E verification spec).

## Lane B Evidence

- **Execution role**: DOMAIN-MEDIA-01 Lane B (media trace normalization)
- **Scope**: contract/verification authoring ONLY, no runtime mutation
- **Override ref**: TERMINAL-3LANE-GOVERNANCE-BURNDOWN-20260303
- **Files created**: 2 new contracts (`media.queue.reconciliation.policy.yaml`, `media.e2e.verification.spec.yaml`)
- **Files modified**: 1 enriched contract (`media.availability.progression.contract.yaml` v0.1 pending -> v1.0 draft)
- **Gap assessment**: 4 gaps analyzed (1389/1390/1392/1393); all must remain open (contracts alone cannot close them)

## Definition Of Done
- Forensic artifacts are committed and linked.
- Gaps are linked to the appropriate forensic or successor planning loop.
- Runtime mutation remains deferred to successor execution loop(s).

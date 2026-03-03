---
loop_id: LOOP-MEDIA-RUNTIME-REPAIR-20260303
created: 2026-03-03
status: active
owner: "@ronny"
scope: media
priority: high
horizon: now
execution_readiness: runnable
execution_mode: single_worker
objective: Fix media runtime gaps covering path authority, queue hygiene, and chain verification (GAP-OP-1387..1393, 1404/1405).
blocked_by: []
---

# Loop Scope: LOOP-MEDIA-RUNTIME-REPAIR-20260303

## Objective

Resolve the highest-pain media runtime gaps identified in the operational gap registry:
path authority mismatches, downloader path mapping parity, Jellyseerr availability
progression, stale queue cleanup, and end-to-end chain verification.

## Guard Commands

- **Verify**: `./bin/ops cap run verify.run -- fast`

## Scope

In:
- GAP-OP-1387: Radarr root folder / path authority mismatch
- GAP-OP-1388: Downloader path mapping parity (SABnzbd/Radarr)
- GAP-OP-1389: Jellyseerr availability progression (processing to available)
- GAP-OP-1390: Stale/ghost queue item cleanup
- GAP-OP-1391: Radarr to Jellyseerr to Jellyfin chain verification
- GAP-OP-1392: Media service health probe coverage
- GAP-OP-1393: Media binding contract completeness
- GAP-OP-1404: Runtime contract completion (if reachable)
- GAP-OP-1405: Runtime contract completion (if reachable)

Out:
- Tax/Legal gaps (GAP-OP-1422..1446)
- Network security planning gaps
- Unrelated domain loops

## Execution Steps

- Step 1: Read and understand all target gaps from operational.gaps.yaml.
- Step 2: Fix path authority and downloader path mapping in media bindings.
- Step 3: Address queue hygiene and chain verification gaps.
- Step 4: Update media binding contracts for completeness.
- Step 5: Close resolved gaps with evidence.
- Step 6: Run verify fast and produce closeout report.

## Success Criteria

- All fixable gaps in range 1387..1393 resolved or have structured blocker metadata.
- Media binding contracts are consistent and complete.
- Fast verify passes with no introduced failures.

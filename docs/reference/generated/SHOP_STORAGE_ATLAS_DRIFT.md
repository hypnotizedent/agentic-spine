# Shop Storage Atlas Drift

- Generated at: `2026-03-17T07:09:54Z`
- Observed host: `pve` (`100.96.211.33`)
- Remote observed at: `2026-03-17T07:09:23Z`

## Pool Snapshot

- `media`: 95% used, 27.86TiB used, 1.24TiB free, health `ONLINE`
- `tank`: 80% used, 23.30TiB used, 5.81TiB free, health `ONLINE`
- `md1400`: 37% used, 16.30TiB used, 27.36TiB free, health `ONLINE`

## Findings

- `CRITICAL` `media-capacity-pressure`: The live media pool remains effectively full.
  live usage: 95% with 1.24TiB free
- `LOW` `local-lvm-active-runtime-exceptions`: Several active guests still have runtime disks on local-lvm; these are current exceptions, not target-state boringness.
  guests: immich(203, status=compliant), infra-core(204, status=accepted-risk), observability(205, status=accepted-risk), dev-tools(206, status=accepted-risk), ai-consolidation(207, status=accepted-risk), download-stack(209, status=compliant), streaming-stack(210, status=compliant), finance-stack(211, status=accepted-risk), mint-data(212, status=compliant), mint-apps(213, status=compliant), communications-stack(214, status=partial)

## Highest-Leverage Normalization Work

- Objective: Reduce remaining warm-lane pressure from /media/downloads and restore boring import flow without reintroducing namespace drift.
- /media remains single-lane and carries only the canonical media roots.
- /md1400/stage stays empty between waves.
- download-stack import automation stops reporting false zero-free-space conditions.
- media runway recovers below the guard threshold so hardware changes are not forced under capacity pressure.

- Rebuild atlas: `./bin/ops cap run infra.shop.storage.atlas.build`

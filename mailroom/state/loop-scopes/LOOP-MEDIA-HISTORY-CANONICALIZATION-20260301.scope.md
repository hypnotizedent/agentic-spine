---
loop_id: LOOP-MEDIA-HISTORY-CANONICALIZATION-20260301
created: 2026-03-01
status: active
owner: "@ronny"
scope: media
priority: medium
horizon: now
execution_readiness: runnable
objective: Historical reconstruction and canonical contract updates for media topology, storage tiering, and transfer workflow
---

# Loop Scope: LOOP-MEDIA-HISTORY-CANONICALIZATION-20260301

## Objective

Historical reconstruction and canonical contract updates for media topology, storage tiering, and transfer workflow

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-MEDIA-HISTORY-CANONICALIZATION-20260301`

## Phases
- Step 1: capture and classify findings
- Step 2: implement changes
- Step 3: verify and close out

## Success Criteria
- All linked gaps/proposals are captured and linked to this loop.
- Relevant verify pack(s) pass.

## Definition Of Done
- Scope artifacts updated and committed.
- Receipted verification run keys recorded.
- Loop status can be moved to closed.

## W0 Baseline (2026-03-01)
- verify.run fast: 10/10 PASS
- verify.pack.run media: 15/19 PASS (D108/D109/D223/D224 pre-existing — qBittorrent/autopulse down, Sonarr API key rotation)

## W1 Claim Validation Matrix

| # | Claim | Status | Evidence |
|---|-------|--------|----------|
| 1 | SAB home/shop eras | true | SABnzbd active on download-stack (VM 209). Home vs shop is Proxmox node distinction (100-199 vs 200-299). Media all runs on shop (pve). No home SAB instance found. |
| 2 | Transition to Gluetun + qBittorrent | true | Commit e09f72b (2026-02-26) wired qBittorrent as governed download client. Gluetun provides VPN tunnel for slskd. QB itself runs direct (QB-VPN-ROUTE-001). SABnzbd retained as primary. |
| 3 | VM 201 monolithic -> split VM 209/210 | true | LOOP-MEDIA-STACK-SPLIT-20260208, commit 04e1158. SAB I/O contention caused Jellyfin buffering. Split 2026-02-08, decom 2026-02-10. |
| 4 | WAN limits constrain bulk transfer | true | GAP-OP-865: Home WAN undocumented. Shop: T-Mobile 5G ~865/309 Mbps. sneakernet.sh existed (tombstone in workbench). |
| 5 | Shuttle workflow exists | stale | sneakernet.sh was cleaned to tombstone-only (GAP-OP-880 area). No active shuttle capability. Legacy body removed. |
| 6 | Synology role shifts needed | unknown | DS918+ registered as NAS (100.102.199.111). D139 enforces /volume1 backup lane. No evidence of role change plans. |
| 7 | New SAS drive intake | true | MD1400 SAS recovery complete (PM8072->SAS9300-8e). 12x ST4000NM0063 (3.6TB SAS) visible. LOOP-MD1400-CAPACITY-NORMALIZATION closed. Pool normalized into governed runtime. |
| 8 | Home ingest VM/CT role boundaries | unknown | No home-side ingest VM documented. All media processing is on shop pve (VMIDs 200+). Home side has Beelink+NAS only. |
| 9 | Tubifarry music adoption | false | Deferred (commit 51dd9c7). Soularr+Lidarr path retained. Music Assistant HA integration still pending (GAP-OP-906). |

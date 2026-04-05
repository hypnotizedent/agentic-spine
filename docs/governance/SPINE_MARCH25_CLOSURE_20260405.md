---
status: authoritative
owner: "@ronny"
scope: march25-post-v3-closure
as_of: "2026-04-05"
---

# March 25 Closure Program

## Closure Decision

As of `2026-04-05`, the March 25 post-V3 spine closure program is closed to governed truth.

The operator reporting boundary is now explicit:

- `L1_engine` is clean.
- `L2_shared_infrastructure` carries the remaining explicit operational residue.
- `L3_product_runtime` is clean on the active drift surface.

No remaining March 25 residue is left in silent warn-only limbo.

## What Counted As L1 And Is Now Closed

The following spine-coherence items are no longer open engine-integrity ambiguity:

- `D67` capability-map parity repaired in commit `8dd9300b9b7309f1bb6338bd8ddeffb650a78458`
- `D127` gate/topology assignment parity repaired in commit `8dd9300b9b7309f1bb6338bd8ddeffb650a78458`
- `D213` secrets registered-route enforcement promoted and locked in commit `0eb7f6395b5535ec668a3874658be737a53871c9`
- `D225` mint live-before-auth left on explicit governed hold, dated `2026-04-05`, in commit `0eb7f6395b5535ec668a3874658be737a53871c9`
- `D75` historical gap-mutation compliance resolved with commit-specific exemption in commit `33296bf5a5859efb76c2a1369a3f4aa55aa038c2`

## Reclassification Boundary

Layer-aware drift reporting now classifies remaining residue by governed layer instead of implying undifferentiated spine-core failure.

Authoritative layer outcomes on `2026-04-05`:

- `L1_engine`: clean
- `L2_shared_infrastructure`: residue present
- `L3_product_runtime`: clean

Specific reclassifications:

- `D62` is classified as `L2_shared_infrastructure`
  - rationale: GitHub mirror drift is publication/infrastructure advisory, not engine-integrity failure
- `D91` is classified as `L3_product_runtime`
  - rationale: AOF product foundation is product-runtime truth, not spine engine truth

## Gates Fixed In This Closure Pass

- `D69` fixed to green
  - restored truthful VM governance parity for `archive-smb`
  - repaired LXC backup-target matching, runtime-unit metadata matching, and host registry truth
- `D91` fixed to green
  - accepted the live `authority` plugin as the canonical carrier of tenant surfaces in `MANIFEST.yaml`
- `D92` fixed to green
  - HA config extract refreshed the governed workbench config mirror
- `D98` fixed to green
  - HA Z2M snapshot helper now promotes tracked output to `ops/bindings/domains/ha/z2m.devices.yaml`
- `D101` fixed to green
  - HA add-on snapshot helper now promotes tracked output to `ops/bindings/domains/ha/ha.addons.yaml`

## Gates Retired In This Closure Pass

- `D107` retired as of `2026-04-05`
  - rationale: `download-stack` and `streaming-stack` were decommissioned on `2026-03-23`; their NFS mount posture is no longer active runtime truth
  - governed truth:
    - `ops/bindings/vm.lifecycle.yaml`
    - `ops/bindings/services.health.yaml`
    - `ops/bindings/domains/media/media.services.yaml`

## Explicit Holds That Remain

- `D19` remains on explicit governed hold as of `2026-04-05`
  - posture: `hold_report_only`
  - exact blocker: `backup.posture.snapshot.build` now resolves canonical domain paths and `D19`'s stale false positives are removed, but `lane_collect_errors_total=1` remains because `nas-legacy-tombstones` is still probed as an active destination lane even though the inventory describes it as non-canonical quarantine residue
  - governed follow-up truth:
    - `ops/bindings/domains/backup/backup.inventory.yaml`
    - `ops/bindings/domains/backup/backup.posture.snapshot.yaml`
    - `ops/plugins/infra/backup/bin/backup-posture-snapshot-build`
    - `ops/plugins/infra/backup/bin/backup-status`

## Receipts And Runs

Key runtime receipts used in this closure:

- `CAP-20260405-153235__ha.config.extract__Rugfo4926`
  - receipt: `/Users/ronnyworks/code/.evidence/spine/sessions/RCAP-20260405-153235__ha.config.extract__Rugfo4926/receipt.md`
- `CAP-20260405-155225__ha.z2m.devices.snapshot__Rhl0653939`
  - receipt: `/Users/ronnyworks/code/.evidence/spine/sessions/RCAP-20260405-155225__ha.z2m.devices.snapshot__Rhl0653939/receipt.md`
- `CAP-20260405-155225__ha.addons.snapshot__Rlhiu53940`
  - receipt: `/Users/ronnyworks/code/.evidence/spine/sessions/RCAP-20260405-155225__ha.addons.snapshot__Rlhiu53940/receipt.md`
- `CAP-20260405-160019__verify.fast__Rq55f97912`
  - receipt: `/Users/ronnyworks/code/.evidence/spine/sessions/RCAP-20260405-160019__verify.fast__Rq55f97912/receipt.md`

## Commit Order

Closure chain in landing order:

1. `8dd9300b9b7309f1bb6338bd8ddeffb650a78458` — `D67` / `D127`
2. `0eb7f6395b5535ec668a3874658be737a53871c9` — `D213` / `D225` / infisical hardening
3. `33296bf5a5859efb76c2a1369a3f4aa55aa038c2` — `D75`
4. `b09405e446a356ece3755c60d1ca5017237a5ad2` — layer-aware drift reporting, Cluster A fixes, Cluster B closure truth

## Final Operator Read

If `drift-gate` is non-green after this closure, it should no longer be read as undifferentiated spine failure.

Read it this way:

- `L1_engine`: clean
- `L2_shared_infrastructure`: explicit residue only (`D19` governed hold, `D62` publication mirror advisory)
- `L3_product_runtime`: clean

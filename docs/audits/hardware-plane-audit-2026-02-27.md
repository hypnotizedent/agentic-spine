# Hardware Plane Audit - 2026-02-27

## Executive Summary
- Scope audited: `pve` and `proxmox-home` using `ops/bindings/hardware.inventory.yaml`, `ops/bindings/operational.gaps.yaml`, and `ops/bindings/gate.registry.yaml`.
- `pve` storage pools are `ONLINE`; current capacities are `md1400=1%`, `media=81% (WARN >=80)`, `tank=41%`.
- H1 reconciliation landed: `hardware.inventory` now declares `md1400` as `intended_state: pooled` with `zfs_pool: md1400` and `last_verified: 2026-02-27`.
- No non-boot orphan disks were found (`0` non-boot unpooled serials on both audited hosts).
- Scrub recency is within policy (media `4.13d`, tank `4.65d`, threshold `14d`); md1400 has no scrub yet and was created ~`0.06d` before audit timestamp.
- Multipath remains ungoverned on `pve`: dual-path shelf observed (12 serials, 2 paths each) while `multipath` userspace tooling is absent.
- Open gap linkage exists for capacity-utilization drift (`GAP-OP-1036`), and successor gaps (`GAP-OP-1047/1048/1049`) now include wave execution notes; hardware gates remain draft until operator adoption.

## Current Hardware Plane Status Line
`HW: pools[md1400=1% ONLINE; media=81% WARN; tank=41% ONLINE] | idle_shelves=0(observed+declared) | orphan_disks=0(non-boot) | multipath=UNRESOLVED(rc=127, dual_path_shelf=md1400) | scrubs[max_age=4.65d OK; md1400=no-scan,pool_age=0.06d]`

## Observed vs Declared Inventory
| Item | Declared | Observed | Drift | Evidence |
|---|---|---|---|---|
| `pve` MD1400 pool attachment | `intended_state: pooled`, `zfs_pool: md1400`, status pooled/active | `md1400` pool exists and `ONLINE` | Reconciled in H1 (pending operator acceptance for gap closure) | `ops/bindings/hardware.inventory.yaml` (`external_shelves.md1400`); `mailroom/outbox/reports/hardware-plane-audit/2026-02-27/raw/pve-evidence.txt:4065`; `.../pve-evidence.txt:9321` |
| MD1400 device cardinality | `drive_count: 12`, `block_device_count: 24`, `dual_path: true` | 12 serials with path multiplicity 2 (24 sd* paths) | Match on topology; governance gap on multipath stack | `ops/bindings/hardware.inventory.yaml:96-102`; `.../pve-evidence.txt:163`; `.../pve-evidence.txt:175`; `.../pve-evidence.txt:208` |
| Multipath declaration | `multipath_configured: false` | `multipath -ll` not installed (`RC 127`) | Known-but-unresolved runtime risk | `ops/bindings/hardware.inventory.yaml:102`; `.../pve-evidence.txt:3006-3007` |
| Controller lineage | PM8072 historical failure path; replacement SAS9300 listed | Two live SAS3008 controllers detected; no PM8072 PCI function observed | Match (replacement complete) | `ops/bindings/hardware.inventory.yaml:45-73`; `.../pve-evidence.txt:22`; `.../pve-evidence.txt:26` |
| `proxmox-home` storage | No shelves/controllers declared | No SAS/HBA hits; no zpools; NVMe SMART healthy | Match | `ops/bindings/hardware.inventory.yaml:129-143`; `.../proxmox-home-evidence.txt:17-18`; `.../proxmox-home-evidence.txt:478`; `.../proxmox-home-evidence.txt:547` |

## Drift Signals
1. Severity: `high`  
   Signal: `media` pool is above warn threshold while md1400 capacity exists and utilization lane is still open.  
   Evidence: `media=81%` (`.../pve-evidence.txt:4066`), md1400 free `43.2T` (`.../pve-evidence.txt:4065`), open `GAP-OP-1036` (`ops/bindings/operational.gaps.yaml:13067-13077`).  
   Duration estimate: at least since `2026-02-27T03:55:29Z` (gap filed).  
   Impacted tenants: media workloads on `pve` (download/streaming pipeline and related datasets).

2. Severity: `high`  
   Signal: dual-path shelf present without multipath runtime tooling.  
   Evidence: inventory says dual path true + multipath false (`ops/bindings/hardware.inventory.yaml:101-102`), duplicate serial paths visible (`.../pve-evidence.txt:163`, `.../pve-evidence.txt:175`), `multipath` missing (`.../pve-evidence.txt:3006-3007`).  
   Duration estimate: at least since last inventory verify `2026-02-23` (~4 days).  
   Impacted tenants: infra storage reliability and failover behavior.

3. Severity: `medium`  
   Signal: SMART warning detail on `/dev/sdl` despite overall PASS.  
   Evidence: `/dev/sdl` SMART PASS (`.../pve-evidence.txt:6363`) with `Reallocated_Sector_Ct = 8` (`.../pve-evidence.txt:6403`) and `Device Error Count: 1` (`.../pve-evidence.txt:6466`).  
   Duration estimate: historical error occurred at drive lifetime hour `5004` (`.../pve-evidence.txt:6482`).  
   Impacted tenants: media pool resilience margin.

4. Severity: `info`  
   Signal: declared-vs-observed md1400 shelf state drift was present at audit intake and is now normalized in H1 governance updates.  
   Evidence: inventory now declares pooled state (`ops/bindings/hardware.inventory.yaml` md1400 shelf block), while prior evidence still shows the original mismatch at capture time (`.../pve-evidence.txt:4065`; `.../pve-evidence.txt:9321`).  
   Duration estimate: mismatch window from pool create time `2026-02-26 23:13:59` to reconciliation update `2026-02-27`.  
   Impacted tenants: governance-only (SSOT correctness), not current runtime health.

## Gate Proposals
- Draft file: `mailroom/outbox/reports/hardware-plane-audit/2026-02-27/draft.hardware.drift.gates.yaml`
- `D-next.hardware-capacity-utilization-lock` (critical): fail on active shelf `zfs_pool: null` past idle window without owned gap; fail on warn/fail pools with non-boot unpooled capacity; fail on declared dual-path shelves lacking multipath evidence.
- `D-next.zfs-pool-health-lock` (critical): fail on any pool `health != ONLINE` or `cap >= 85`.
- `D-next.scrub-recency-lock` (high): fail when scrub age exceeds 14 days (unless pool age <14 days).
- `D-next.successor-gap-enforcement` (high/process): closing hardware/storage gaps requires successor gap or utilization attestation.

## Multipath Acceptance Criteria (H2)
1. `multipath` userspace tooling installed on `pve` and executable (`multipath -ll` exit `0`).
2. Every md1400 dual-path serial resolves to a single `dm-*` mapping with two active paths.
3. `hardware.inventory`/audit evidence contains both:
   - command evidence for `multipath -ll`, and
   - path cardinality evidence (`lsscsi -g` or equivalent) showing no unmanaged duplicate-path ambiguity.
4. If criteria 1-3 fail at any audit run, `GAP-OP-1048` must remain open with fresh notes.

## SMART Watch Policy (H3)
1. Target disk: `/dev/sdl` (`Seagate ST8000AS0002`), evidence counters: `Reallocated_Sector_Ct=8`, `Device Error Count=1`.
2. Trigger thresholds:
   - `critical`: SMART overall status not `PASSED`, or reallocated sectors increase by `>=1` since last audit, or device error count increases by `>=1`.
   - `warning`: no increase but non-zero counters persist (current state).
3. Cadence:
   - daily quick check: `smartctl -A /dev/sdl` evidence capture.
   - weekly extended check: `smartctl -x /dev/sdl` included in hardware-plane audit bundle.
4. Owner and escalation:
   - owner role: `SPINE-EXECUTION-01`
   - escalate to `GAP-OP-1049` critical handling immediately on threshold breach; otherwise keep policy note current with next review date.

## Gap Actions
1. Existing gap linkage confirmed: `GAP-OP-1036` remains open and correctly linked to active normalization loop.  
   Owner terminal role: `SPINE-EXECUTION-01` (current canonical owner in `terminal.role.contract`).  
   Due window: `48-72h` to complete utilization migration milestones and reduce `media` below warning threshold.

2. Filed successor gap: `GAP-OP-1047` (`stale-ssot`) for md1400 declaration drift (`zfs_pool`/status stale in inventory).  
   Owner terminal role: `SPINE-EXECUTION-01`.  
   Due window: `24h`.  
   Status: reconciliation edits landed in H1; pending operator acceptance for closure.  
   Filing evidence: `CAP-20260227-005637__gaps.file__R4ibb27171`.

3. Filed successor gap: `GAP-OP-1048` (`runtime-bug`) for multipath governance enablement on dual-path MD1400 shelf.  
   Owner terminal role: `SPINE-EXECUTION-01`.  
   Due window: `72h`.  
   Status: H2 acceptance criteria and gate-draft checks added; runtime lane still open pending multipath enablement evidence.  
   Filing evidence: `CAP-20260227-005645__gaps.file__R144q28787`.

4. Filed successor gap: `GAP-OP-1049` (`runtime-bug`) for SMART watch policy on `/dev/sdl` warning counters.  
   Owner terminal role: `SPINE-EXECUTION-01`.  
   Due window: `7d`.  
   Status: H3 policy thresholds/cadence documented; lane remains open pending repeated check evidence.  
   Filing evidence: `CAP-20260227-005651__gaps.file__Rpo3e29530`.

5. H4 governance closeout packaging completed with residual blockers retained in `GAP-OP-1036` (no closure attempted).  
   Evidence: `docs/planning/HARDWARE_PLANE_WAVE_EXECUTION_RECEIPT_20260227.md`; replacement proposal envelope `mailroom/outbox/proposals/CP-20260227-014245__hardware-plane-governance-wave-closeout-fullscope-replacement-20260227/` (replaces narrowed apply record `CP-20260227-011200__hardware-plane-governance-wave-closeout-20260227`); wave close `CAP-20260227-011244__orchestration.wave.close__Rae8q54239` (`READY_FOR_ADOPTION=false` due to preflight status anomalies).

## 2026-02-27 Live Closure Evidence Update
- evidence bundle: `mailroom/outbox/reports/hardware-plane-audit/2026-02-27/closure-evidence-20260227T065051Z/`
- `GAP-OP-1036`: still open (`media=81%`, `md1400=2%`); in-flight copy-first migration observed at `67%` (`xfr#1622`) with `md1400/stage` now `931G`.
- `GAP-OP-1048`: still open; `multipath -ll` remains unavailable (`rc=127`), while dual-path cardinality is confirmed (`12` serials, `24` paths, all dual-path).
- `GAP-OP-1049`: recurring SMART cycle now captured in live evidence (`/dev/sdl` health `PASSED`, `Reallocated_Sector_Ct=8`, `Device Error Count=1`, no increment across cycle samples).
- machine summary artifact: `mailroom/outbox/reports/hardware-plane-audit/2026-02-27/closure-evidence-20260227T065051Z/hardware-gap-closure-summary.json`.

Requires Attestation before non-read-only follow-on:
- `ALLOW_MEDIA_UTILIZATION_PRUNE` for post-copy source-prune/cutover required to drop `media` below warning threshold.
- `ALLOW_MULTIPATH_ENABLEMENT` for multipath package/config enablement and md1400 dm-map activation.

## Loop Steps
- Loop ID: `LOOP-INFRA-HARDWARE-PLANE-AUDIT-20260227` (active/background on `SPINE-EXECUTION-01`, weekly + inventory-change + storage-gap-close triggers).  
  Activation evidence: `CAP-20260227-005812__loops.background.start__Rxibh35439`.
- Phase 1: run read-only hardware audit capability and refresh `hardware.capacity.audit.json` artifacts.
- Phase 2: reconcile inventory vs observed (especially shelf pool binding + intent fields).
- Phase 3: enforce new gates + successor-gap closure contract.
- Phase 4: execute remediation lanes (multipath, capacity migration, SMART governance), then re-audit.
- Phase 5: close only when new gates pass and session.start line is hardware-aware and non-UNKNOWN.

## Tombstones / Replacements
- PM8072-era mutating capabilities are now legacy relative to declared hardware state:
  - `network.md1400.pm8072.stage`
  - `network.md1400.bind_test`
- Evidence: PM8072 marked historical failure and replaced by SAS9300 (`ops/bindings/hardware.inventory.yaml:63-73`, `:45-61`), while legacy capabilities remain active (`ops/capabilities.yaml:5155-5173`).
- Replacement direction: one canonical read-only hardware audit capability (`infra.hardware.capacity.audit`) plus explicit attested provisioning capability boundary.

## Requires Attestation / Stop Gates
- This audit executed read-only only; no destructive action was attempted.
- If follow-on requires `wipefs`, `sgdisk`, or `zpool create`, require explicit stop-gate attestation (`ALLOW_MD1400_PROVISION` pattern) and approved WWN allowlist before execution.
- Prior precedent evidence: `ALLOW_MD1400_PROVISION` gate and destructive stop/resume flow in loop scope (`mailroom/state/loop-scopes/LOOP-MD1400-CAPACITY-NORMALIZATION-20260227-20260227.scope.md:63`, `:69-73`).

## Artifact Drafts
- `mailroom/outbox/reports/hardware-plane-audit/2026-02-27/hardware.capacity.audit.json`
- `mailroom/outbox/reports/hardware-plane-audit/2026-02-27/draft.hardware.drift.gates.yaml`
- `docs/planning/HARDWARE_PLANE_WAVE_EXECUTION_RECEIPT_20260227.md`
- `mailroom/outbox/proposals/CP-20260227-014245__hardware-plane-governance-wave-closeout-fullscope-replacement-20260227/`
- Historical narrow apply record: `mailroom/outbox/proposals/CP-20260227-011200__hardware-plane-governance-wave-closeout-20260227/`
- Raw evidence bundle:
  - `mailroom/outbox/reports/hardware-plane-audit/2026-02-27/raw/pve-evidence.txt`
  - `mailroom/outbox/reports/hardware-plane-audit/2026-02-27/raw/proxmox-home-evidence.txt`

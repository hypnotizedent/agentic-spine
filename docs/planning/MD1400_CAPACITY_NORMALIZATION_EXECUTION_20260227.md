---
status: working
owner: "@ronny"
created: 2026-02-27
scope: md1400-capacity-normalization
loop_id: LOOP-MD1400-CAPACITY-NORMALIZATION-20260227-20260227
---

# MD1400 Capacity Normalization Execution (Wave Receipts)

## Executive State

- Waves 0-4 executed with receipts and artifact evidence.
- Wave 5 copy-first migration is in progress (non-destructive, source retained).
- `md1400` pool is provisioned and online (12-disk raidz2).
- Post-wave verify is green for infra (`41/41`) and media (`16/16`).
- `GAP-OP-1033`, `GAP-OP-1034`, and `GAP-OP-1035` are fixed.
- `GAP-OP-1036` remains open for utilization/copy completion.
- No source data was deleted.

## Loop + Gap Registration

- Loop ID: `LOOP-MD1400-CAPACITY-NORMALIZATION-20260227-20260227`
- Gap IDs:
  - `GAP-OP-1033` (runtime-bug, high): MD1400 idle with stale DDF metadata
  - `GAP-OP-1034` (stale-ssot, medium): stale pm80xx config drift risk
  - `GAP-OP-1035` (missing-entry, medium): D188 stale observed feeds cadence
  - `GAP-OP-1036` (runtime-bug, high): media 80% while MD1400 unused

## Wave 0 Receipts (Baseline + Drift)

- `CAP-20260226-225229__session.start__Rqmns59757`
- `CAP-20260226-225246__infra.hypervisor.identity__Rrnm565483`
- `CAP-20260226-225251__infra.proxmox.maintenance.precheck__Rim0h65784`
- `CAP-20260226-225304__network.shop.audit.canonical__Rbfdx66962`
- `CAP-20260226-225304__media.status__Ri85r66964`
- `CAP-20260226-225304__media.pipeline.trace__Ruml766963`
- `CAP-20260226-225340__verify.pack.run__Rx2yq70481` (non-blocking; D188 stale feed fail)
- `CAP-20260226-225419__verify.pack.run__Rdc6081959` (media pass)
- `CAP-20260226-225419__gaps.status__Ra99381969`

## Wave 1 Receipts (Governance Lane)

- `CAP-20260226-225459__loops.create__Rn7ga87197`
- `CAP-20260226-225503__loops.background.start__Rv04487779`
- `CAP-20260226-225508__gaps.quick__Rngws88679` -> `GAP-OP-1033`
- `CAP-20260226-225516__gaps.quick__Rap3989427` -> `GAP-OP-1034`
- `CAP-20260226-225521__gaps.quick__Rnl0x90172` -> `GAP-OP-1035`
- `CAP-20260226-225529__gaps.quick__R9ebn90925` -> `GAP-OP-1036`

## Wave 2 Evidence Pack (Read-Only)

- `CAP-20260226-225541__infra.storage.audit.snapshot__R6d9q93895`
- Artifact bundle: [`docs/planning/_artifacts/md1400-normalization-20260227/`](docs/planning/_artifacts/md1400-normalization-20260227/)
  - [`01-zpool-list.txt`](docs/planning/_artifacts/md1400-normalization-20260227/01-zpool-list.txt)
  - [`02-lsblk-st4000nm0063.txt`](docs/planning/_artifacts/md1400-normalization-20260227/02-lsblk-st4000nm0063.txt)
  - [`03-md1400-target-wipefs-smart.txt`](docs/planning/_artifacts/md1400-normalization-20260227/03-md1400-target-wipefs-smart.txt)
  - [`04-zfs-list-media.txt`](docs/planning/_artifacts/md1400-normalization-20260227/04-zfs-list-media.txt)

Wave 2 key observations:

- Existing pools: `media` at 80% and `tank` at 41%.
- `md1400` pool is not present yet.
- All 12 MD1400 target WWNs are visible as `sdo`-`sdz` and duplicated multipath aliases `sdaa`-`sdal`.
- All 12 target drives still carry stale `ddf_raid_member` signatures.
- SMART health on all 12 targets reports `OK`.

## Wave 3 Receipts (Drift Hygiene)

- `CAP-20260226-225711__domain-inventory-refresh__Rda9997576`
- `CAP-20260226-225824__verify.pack.run__R4qtk1777` (`infra` 41/41 PASS; D188 PASS)
- Host drift cleanup artifact:
  - [`05-pm80xx-post-cleanup.txt`](docs/planning/_artifacts/md1400-normalization-20260227/05-pm80xx-post-cleanup.txt)

Wave 3 key observations:

- `/etc/modprobe.d/pm80xx.conf` and `/etc/modules-load.d/pm80xx.conf` removed from active paths.
- Backup retained at `/root/md1400-normalize-backup/pm80xx.conf`.
- Remaining pm80xx references are only `*.bak.*` files.

## Wave 4 Receipts (MD1400 Capacity Activation)

Pre-approval stop snapshot:

- Gate check recorded: `ALLOW_MD1400_PROVISION=<unset>` (destructive block held)
- `CAP-20260226-230033__verify.pack.run__Rzx969303` (`media` 16/16 PASS)
- `CAP-20260226-230033__gaps.status__Rsj7o9304` (0 orphaned gaps; MD1400 gaps open/linked)

Approved execution path:

- Operator approval received: `ALLOW_MD1400_PROVISION=yes`
- Preflight receipt: `CAP-20260226-230842__infra.storage.audit.snapshot__Ralj748827`
- Initial destructive attempt stopped on non-zero `sgdisk` return (gate honored).
- Explicit operator override received to treat `sgdisk` warning as non-blocking when `wipefs` signatures are clear.
- Continued destructive execution completed:
  - wiped/zapped all 12 approved MD1400 WWN targets
  - created `md1400` raidz2 pool
  - set dataset properties (`compression=lz4`, `atime=off`, `xattr=sa`, `acltype=posixacl`)
  - created datasets: `md1400/media-cold`, `md1400/backup-cold`, `md1400/stage`

Post-wave verification receipts:

- `CAP-20260226-231428__verify.pack.run__Rr4z464656` (`infra` 41/41 PASS)
- `CAP-20260226-231428__verify.pack.run__Rpncx64657` (`media` 16/16 PASS)
- `CAP-20260226-231428__gaps.status__Rd2dt64670`
- `CAP-20260226-231523__gaps.status__R4g6373598`
- `CAP-20260226-231523__loops.status__Rz8bg73597`

Wave 4 artifact additions:

- [`06-wave4-preflight-zpool-status-P.txt`](docs/planning/_artifacts/md1400-normalization-20260227/06-wave4-preflight-zpool-status-P.txt)
- [`07-wave4-preflight-wwn-paths.txt`](docs/planning/_artifacts/md1400-normalization-20260227/07-wave4-preflight-wwn-paths.txt)
- [`08-wave4-preflight-collision-check.txt`](docs/planning/_artifacts/md1400-normalization-20260227/08-wave4-preflight-collision-check.txt)
- [`09-wave4-precreate-wipefs.txt`](docs/planning/_artifacts/md1400-normalization-20260227/09-wave4-precreate-wipefs.txt)
- [`10-wave4-post-zpool-list.txt`](docs/planning/_artifacts/md1400-normalization-20260227/10-wave4-post-zpool-list.txt)
- [`11-wave4-post-zpool-status-md1400.txt`](docs/planning/_artifacts/md1400-normalization-20260227/11-wave4-post-zpool-status-md1400.txt)
- [`12-wave4-post-zfs-list-md1400.txt`](docs/planning/_artifacts/md1400-normalization-20260227/12-wave4-post-zfs-list-md1400.txt)
- [`13-wave4-post-wipefs-targets.txt`](docs/planning/_artifacts/md1400-normalization-20260227/13-wave4-post-wipefs-targets.txt)

Wave 4 key observations:

- `md1400` pool now present: `43.7T` raw (`zpool list`).
- `md1400` datasets mounted with `36.0T` available.
- Target-drive post-check shows `12/12` drives with no stale `ddf_raid_member` signatures.

## Post-Validation Non-Destructive Closure Update

- `CAP-20260226-230652__gaps.close__Rvdxw30728` closed `GAP-OP-1034` as fixed.
- `CAP-20260226-230659__gaps.close__Rx7vj31589` closed `GAP-OP-1035` as fixed.
- `CAP-20260226-230705__gaps.status__R35y632744` confirms `GAP-OP-1033` and `GAP-OP-1036` remain open.
- `CAP-20260226-230705__loops.status__Re8si32751` confirms loop remains `active/background`.
- Auto-commits produced by `gaps.close`:
  - `28b0c42` (`GAP-OP-1034`)
  - `9c33f38` (`GAP-OP-1035`)

Wave 4 follow-up gap status:

- `GAP-OP-1033` closure completed by operator:
  - `CAP-20260226-231925__gaps.close__Rapck1117`
  - post-close status: `CAP-20260226-231937__gaps.status__R56tz1732`
  - post-close verify: `CAP-20260226-231801__verify.pack.run__Rd8dl91088` (`infra`), `CAP-20260226-231801__verify.pack.run__Rqawc91089` (`media`)
  - commit: `931db2a` (operational.gaps.yaml only)

## Wave 5 Receipts (Copy-First Utilization Upgrade, In Progress)

- Wave 5 entry receipt:
  - `CAP-20260226-232501__infra.storage.audit.snapshot__R4drt6444`
- Forensic source snapshot:
  - snapshot name: `forensic-20260226-2325`
  - artifacts:
    - [`14-wave5-snapshot-name.txt`](docs/planning/_artifacts/md1400-normalization-20260227/14-wave5-snapshot-name.txt)
    - [`15-wave5-snapshot-tail.txt`](docs/planning/_artifacts/md1400-normalization-20260227/15-wave5-snapshot-tail.txt)
- Dry-run copy baseline:
  - artifact: [`16-wave5-rsync-dryrun-stats.txt`](docs/planning/_artifacts/md1400-normalization-20260227/16-wave5-rsync-dryrun-stats.txt)
  - summary:
    - files: `6,207` (`5,044` regular, `1,163` dirs)
    - total size: `2,737,447,548,582` bytes
    - deletions: `0`
- Full copy execution (non-destructive):
  - started in background on `pve`:
    - artifact: [`17-wave5-rsync-start.txt`](docs/planning/_artifacts/md1400-normalization-20260227/17-wave5-rsync-start.txt)
    - supervisor pid: `1713927`
    - rsync pid: `1713932`
  - live state/progress artifacts:
    - [`18-wave5-rsync-process.txt`](docs/planning/_artifacts/md1400-normalization-20260227/18-wave5-rsync-process.txt)
    - [`19-wave5-rsync-progress-tail.txt`](docs/planning/_artifacts/md1400-normalization-20260227/19-wave5-rsync-progress-tail.txt)
  - latest observed progress at capture time: `~6%` (log tail, transfer active)
- Closeout watcher attempt recorded:
  - artifacts:
    - [`23-wave5-closeout-watcher.pid`](docs/planning/_artifacts/md1400-normalization-20260227/23-wave5-closeout-watcher.pid)
    - [`23-wave5-closeout-watcher.log`](docs/planning/_artifacts/md1400-normalization-20260227/23-wave5-closeout-watcher.log)
  - status: local watcher process did not remain active; closeout block `20`-`22` and `24`-`27` remains pending until rsync completion is detected in-session.
- Source deletion status in Wave 5 so far:
  - none (copy-first only; no `--delete`)

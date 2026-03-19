---
status: authoritative
owner: "@ronny"
last_verified: 2026-03-18
scope: managed-machine-filesystem-contract
---

# MACHINE FILESYSTEM CONTRACT

Purpose: make every managed machine boring to read. A path must tell the operator what kind of thing it is, whether it is active, and whether it is safe to clean up.

## Core Rules

1. One path class per directory. Config, data, runtime, logs, cache, backup, archive, and tombstone surfaces must not be mixed.
2. Unknown durable path = defect. If a kept directory does not fit this contract, it must either be documented as a temporary exception or removed.
3. Active stack roots belong under `/opt/stacks/<stack>` on managed Linux guests.
4. Home-directory stack roots are not boring. They are only allowed as named transitional exceptions with an exit criterion.
5. Downloads are staging, not residence. Any long-lived payload under a downloads path is contract drift.
6. Bind mounts must be explicit. Every non-trivial bind mount must have an owner, purpose, backup story, and source path that belongs to a declared class.
7. Retired systems keep one restore story, not a shadow runtime. Tombstones must not appear in startup, deploy, or green-health surfaces.

## Path Classes

### Config
- Meaning: declarative stack inputs, service config, environment files, small static assets.
- Canonical roots:
  - `/etc/...`
  - `/opt/stacks/<stack>/...`
  - `/srv/config/<stack>/...`
- Rules:
  - Config stays small and readable.
  - Config does not become the main payload store.

### Data
- Meaning: durable mutable runtime state.
- Canonical roots:
  - `/srv/data/<stack>/...`
  - `pve:/tank/docker/<stack>/...`
  - `synology918:/volume1/...` when the NAS is the declared authority plane
- Rules:
  - Data must have one declared authority host and one declared backup story.
  - Data does not live in random home directories or ad hoc mountpoints.

### Runtime
- Meaning: live process state, sockets, PID files, container runtime internals.
- Canonical roots:
  - `/run/...`
  - `/var/lib/docker/...`
  - `/var/lib/containers/...`
- Rules:
  - Runtime paths are not long-term storage.
  - Runtime state is rebuildable from config + data + image, or it is misclassified.

### Logs
- Meaning: operator-readable history and service diagnostics.
- Canonical roots:
  - `/var/log/...`
  - journald
- Rules:
  - Logs are append-only operational evidence.
  - Logs are not a substitute for canonical data export or backup.

### Cache / Tmp
- Meaning: disposable acceleration surfaces.
- Canonical roots:
  - `/var/cache/...`
  - `/tmp/...`
  - `/var/tmp/...`
- Rules:
  - Cache/tmp may be deleted without data-loss claims.
  - No contract may rely on cache/tmp for authoritative payload.

### Backup
- Meaning: recoverable copies of canonical state.
- Canonical roots:
  - `/srv/backups/<stack>/...` for local staging only
  - `pve:/md1400/backup-cold/...`
  - `synology918:/volume1/backups/...`
- Rules:
  - Backup paths are not active runtime roots.
  - Backup freshness must be represented in posture/proof surfaces, not implied by directory existence.

### Archive
- Meaning: retained cold payload not needed for normal day-to-day runtime.
- Canonical roots:
  - `pve:/md1400/archive/...`
  - `/srv/archive/<stack>/...` only when no shared archive plane exists
- Rules:
  - Archive is retrievable, not interactive by default.
  - Archive is not the default watch/playback surface for home media UX.

### Tombstone / Retired
- Meaning: dead runtime kept only for recovery, extraction, or evidence.
- Canonical roots:
  - `pve:/md1400/tombstones/...`
  - documented cold restore artifacts such as `vm-200-docker-host-primary`
- Rules:
  - No startup entry.
  - No active deploy method.
  - No health-green claim.
  - One restore procedure, one review/expiry story.

## Active, Parked, Retired

### Active
- Runtime is intended to exist now.
- Stack root and data paths are declared.
- Backup admission and health posture must be explicit.

### Parked
- Runtime is intentionally stopped.
- Data/config may remain, but no operator should confuse the host with a live surface.
- Parked paths keep a restart story and a reason.

### Retired / Tombstoned
- Runtime is dead by policy.
- Files may remain only for restore/extraction.
- Any surface that makes a retired runtime look startable-by-default is a defect.

## Stack Root Rules

- Canonical active stack root on guests: `/opt/stacks/<stack>`.
- `/opt/stacks/<stack>` may be a thin entrypoint symlink to `/srv/config/<stack>` when the guest is normalized into `/srv/config|data|runtime/<stack>`.
- A stack root must contain stack config and small stack-local assets, not the whole payload archive.
- Durable payload belongs on declared data planes, then bind-mounts into the stack.
- Stack names must match repo truth. If the machine path and repo stack id disagree, repo truth is wrong or runtime is wrong.

### Normalized Example

- `surveillance-stack`
  - Compose authority: `/srv/config/surveillance`
  - Thin stack entrypoint: `/opt/stacks/surveillance` -> `/srv/config/surveillance`
  - Durable data: `/srv/data/surveillance/*` backed by the dedicated `/mnt/data` disk
  - Runtime cache: `/srv/runtime/surveillance/cache`

## Bind-Mount Discipline

- Every bind mount must answer four questions:
  - What is the source path?
  - What class is that source path?
  - Which stack/service consumes it?
  - What is the backup/archive contract?
- Bind mounts must not hop between ambiguous or unnamed roots.
- Examples now considered canonical:
  - `pve:/tank/docker/download-stack` -> `download-stack` VM
  - `pve:/tank/docker/streaming-stack` -> `streaming-stack` VM
  - `pve:/md1400/archive/live-share/ronny-projects` -> `archive-smb` LXC
  - `pve:/md1400/archive/live-share/mint-legacy` -> `archive-smb` LXC
  - `synology918:/volume1/media-staging` -> `media-home` VM

## Machine-Specific Canonical Roots

### `pve` / 730XD
- `/tank/docker/<stack>` = active externalized shop runtime state
- `/media` = legacy warm payload / pressure lane, not the long-term home watch authority
- `/md1400/backup-cold` = canonical shop cold backup plane
- `/md1400/archive` = canonical shop cold archive plane
- `/md1400/stage` = controlled staging / import / reconciliation lane
- `/md1400/tombstones` = retired runtime residue and post-cleanup evidence lane

### `proxmox-home`
- `local-lvm` = boot/root disks for home VMs/LXCs
- Hypervisor local disks are not the canonical payload archive
- No mystery durable app piles should accumulate directly on the hypervisor filesystem

### `synology918`
- `/volume1/backups/proxmox_backups/dump` = canonical home VM/LXC backup lane
- `/volume1/backups/_legacy_tombstones` = explicit retired backup subtree
- `/volume1/media-staging/...` = canonical active home media import surface and the only live share currently consumed by `media-home` VM 106
- `/volume1/media-holds/...` = canonical hold/review/overflow lane, not the primary playback library
- Empty placeholder names such as `/volume1/media-home`, `/volume1/media`, `/volume1/hot-media`, `/volume1/live-library`, and `/volume1/library-home` are defects, not canonical roots

## Operator Rule

When a directory cannot be explained in one sentence using this contract, it is not boring enough yet.

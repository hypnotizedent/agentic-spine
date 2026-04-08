---
status: authoritative
owner: "@ronny"
last_verified: 2026-03-19
scope: local-mac-control-plane-contract
---

# Local Control-Plane Contract

What local paths mean on the Mac operator workstation.

## Workspace Root: `/Users/ronnyworks/code`

Everything the operator touches lives here or under `~/.codex`.

### Source Repos

| Path | Role | Branch policy |
|------|------|---------------|
| `agentic-spine/` | Governance control plane | Main checkout stays on `main`; managed worktrees are the execution lanes for wave/feature work. |
| `workbench/` | Operator tooling | Feature branches OK in primary checkout. |
| `mint-modules/` | Business service source | Main checkout stays on `main`. |
| `ronny-products/` | Product repos | Main checkout stays on `main`. |
| `agentic-foundation/` | Reusable implementation source | Main checkout stays on `main`. |

**Rule**: `agentic-spine` primary checkout must be on `main` and clean for daily operation. All wave/feature work happens in managed worktrees, and agent startup is doc-first plus CLI-first: read `NORTH_STAR.md`, `docs/governance/SPINE.md`, `docs/governance/SESSION_PROTOCOL.md`, then run `./bin/ops status --json`, `./bin/ops verify --core-only`, and `./bin/ops cap list`.

### Non-Source Roots

| Path | Class | What belongs | What doesn't |
|------|-------|-------------|--------------|
| `.evidence/` | Evidence | Cap-run receipts, verify outputs, audit reports, wave evidence | Source code, runtime state, backups |
| `.runtime/` | Runtime temp | Managed worktrees, execution state, tmp outputs | Evidence, source, backups |
| `.data/` | Business data | Governed writable domain data (calendar, comms, finance) | Source code, evidence, runtime state |
| `.backups/` | Backup / tombstone | Preserved repo archives, retired payloads | Active source, runtime state |
| `.wt/` | Worktree root | Manual/canonical worktrees (documented alternative to `.runtime/`) | Evidence, backups, source |

### Managed Worktree Convention

Active managed worktrees live at:
```
.runtime/spine/tmp/worktrees/{repo}/{branch-slug}
```

Naming: directory name matches the branch name with `/` replaced by `-`.

**Lifecycle**:
1. Created by wave/loop execution
2. Used for isolated feature branch work
3. Pruned after branch merges to main, the owner has an explicit disposition (`landed|deferred|superseded|abandoned`), and the worktree is confirmed clean
4. Dirty worktrees must be reviewed before pruning

### Codex Runtime: `~/.codex`

| Path | Purpose |
|------|---------|
| `AGENTS.md` | Symlink → `agentic-spine/AGENTS.md` |
| `config.toml` | Symlink → `workbench/dotfiles/codex/config.toml` |
| `rules/default.rules` | Codex behavior rules |
| `skills/` | Codex skills |
| `logs_1.sqlite` | Codex log database |
| `state_5.sqlite` | Codex state database |
| `history.jsonl` | Command history |

**Rule**: Codex runtime is not operator-managed. Do not hand-edit SQLite files. Config changes go through `workbench/dotfiles/codex/`.

## What Should Never Be in a Repo Checkout

- Runtime state (`recovery/state/attempts/`, `recovery/state/cooldown/`)
- Session receipts (they live in `.evidence/`)
- Large binary evidence (they live in `.evidence/`)
- Domain data snapshots that change on every run (use `.gitignore`)
- Secrets (`.env`, credentials, tokens)

## Dirty Checkout Rules

### Acceptable Dirty State

- `workbench/` on a feature branch with in-progress changes — this is an operator tools repo, feature branch work is expected
- Automated snapshot files (`*.snapshot.yaml`) that accumulated during a session — commit as `sync:` or discard before switching branches

### Unacceptable Dirty State

- `agentic-spine/` on a feature branch as the primary checkout — keep the checkout boring and use a managed worktree for branch work
- Untracked runtime state directories appearing in `git status` — add to `.gitignore`
- Any repo's primary checkout diverged from `origin/main` by >1 day without an active reason

## Evidence Retention

| Evidence type | Path | Retention |
|---------------|------|-----------|
| Session receipts | `.evidence/spine/sessions/` | 30 days (prune older) |
| Verify reports | `.evidence/spine/verify/` | Indefinite (they document system state at points in time) |
| Loop closeouts | `.evidence/spine/loop-closeouts/` | Indefinite |
| Domain evidence | `.evidence/spine/verify/{domain}/` | Indefinite |

## Claude Redirect Surface

`~/.claude/CLAUDE.md` is a redirect surface only. It must not become a second governance system.

- Point operators back to the spine repo governance docs.
- Use one lean startup flow:

```bash
cd ~/code/agentic-spine
./bin/ops status --json
./bin/ops verify --core-only
./bin/ops cap list
```

- Keep path references lowercase under `~/code/...`.

The shim should direct operators to:

1. `AGENTS.md` for the thin entry stub.
2. `docs/governance/SPINE.md` for the minimal operating contract.
3. `docs/governance/SESSION_PROTOCOL.md` when deeper session behavior is needed.

## Managed Machine Filesystem Contract

Purpose: make every managed machine boring to read. A path must tell the operator what kind of thing it is, whether it is active, and whether it is safe to clean up.

### Core Rules

1. One path class per directory. Config, data, runtime, logs, cache, backup, archive, and tombstone surfaces must not be mixed.
2. Unknown durable path equals defect. If a kept directory does not fit this contract, it must either be documented as a temporary exception or removed.
3. Active stack roots belong under `/opt/stacks/<stack>` on managed Linux guests.
4. Home-directory stack roots are transitional exceptions only and must carry an exit criterion.
5. Downloads are staging, not residence. Any long-lived payload under a downloads path is contract drift.
6. Every non-trivial bind mount must declare owner, purpose, backup story, and a source path that belongs to a declared class.
7. Retired systems keep one restore story, not a shadow runtime. Tombstones must not appear in startup, deploy, or green-health surfaces.

### Path Classes

- Config: declarative stack inputs, service config, environment files, and small static assets. Canonical roots: `/etc/...`, `/opt/stacks/<stack>/...`, `/srv/config/<stack>/...`.
- Data: durable mutable runtime state. Canonical roots: `/srv/data/<stack>/...`, `pve:/tank/docker/<stack>/...`, `synology918:/volume1/...` when the NAS is the declared authority plane.
- Runtime: live process state, sockets, PID files, and container runtime internals. Canonical roots: `/run/...`, `/var/lib/docker/...`, `/var/lib/containers/...`.
- Logs: operator-readable history and service diagnostics. Canonical roots: `/var/log/...` and journald.
- Cache / Tmp: disposable acceleration surfaces. Canonical roots: `/var/cache/...`, `/tmp/...`, `/var/tmp/...`.
- Backup: recoverable copies of canonical state. Canonical roots: `/srv/backups/<stack>/...`, `pve:/md1400/backup-cold/...`, `synology918:/volume1/backups/...`.
- Archive: retained cold payload not needed for normal runtime. Canonical roots: `pve:/md1400/archive/...`, `/srv/archive/<stack>/...` when no shared archive plane exists.
- Tombstone / Retired: dead runtime kept only for recovery, extraction, or evidence. Canonical roots: `pve:/md1400/tombstones/...` and documented cold restore artifacts such as `vm-200-docker-host-primary`.

### Shared Storage Scaffold Classes

Every cross-device storage map should project durable roots into the same small scaffold model so agents see semantic symmetry even when literal directory names differ.

- `backup_primary`: canonical primary backup or restore authority for an active plane.
- `backup_secondary`: declared secondary or offsite copy, not the primary authority.
- `archive_cold`: canonical cold archive plane for retained payload.
- `intake_stage`: controlled staging or reconciliation lane with drain and expiry expectations.
- `review_hold`: explicit hold or review lane retained on purpose.
- `tombstone_retained`: retired non-canonical residue kept for review, extraction, or evidence.
- `personal_live`: active home-personal payload surface that remains canonical.
- `review_pending`: durable surface intentionally retained but not yet fully classified for cleanup or canon.
- `defect_cruft`: generated clutter or placeholder residue with no canonical authority claim.
- `drained_retired`: previously used root that is now intentionally drained and no longer canonical.

The authoritative machine-readable projection for these classes is `ops/bindings/storage.scaffold.authority.yaml`.

### Active, Parked, Retired

- Active: runtime is intended to exist now, stack roots and data paths are declared, and backup admission plus health posture are explicit.
- Parked: runtime is intentionally stopped, data and config may remain, and the host must not be confused with a live surface.
- Retired / Tombstoned: runtime is dead by policy, files may remain only for restore or extraction, and any surface that makes it look startable by default is a defect.

### Stack Root Rules

- Canonical active stack root on guests: `/opt/stacks/<stack>`.
- `/opt/stacks/<stack>` may be a thin entrypoint symlink to `/srv/config/<stack>` when the guest is normalized into `/srv/config|data|runtime/<stack>`.
- A stack root contains stack config and small stack-local assets, not the whole payload archive.
- Durable payload belongs on declared data planes and then bind-mounts into the stack.
- Stack names must match repo truth. If the machine path and repo stack id disagree, repo truth is wrong or runtime is wrong.

### Bind-Mount Discipline

- Every bind mount must answer four questions: source path, source-path class, consuming stack or service, and backup or archive contract.
- Bind mounts must not hop between ambiguous or unnamed roots.
- Canonical examples:
  - `pve:/tank/docker/download-stack` -> `download-stack` VM
  - `pve:/tank/docker/streaming-stack` -> `streaming-stack` VM
  - `pve:/md1400/archive/live-share/ronny-projects` -> `archive-smb` LXC
  - `pve:/md1400/archive/live-share/mint-legacy` -> `archive-smb` LXC
  - `synology918:/volume1/media-staging` -> `media-home` VM

### Machine-Specific Canonical Roots

#### `pve` / 730XD

- `/tank/docker/<stack>` = active externalized shop runtime state
- `/media` = legacy warm payload or pressure lane, not the long-term watch authority
- `/md1400/backup-cold` = canonical shop cold backup plane
- `/md1400/archive` = canonical shop cold archive plane
- `/md1400/stage` = controlled staging, import, and reconciliation lane
- `/md1400/tombstones` = retired runtime residue and post-cleanup evidence lane

#### `proxmox-home`

- `local-lvm` = boot and root disks for home VMs and LXCs
- Hypervisor local disks are not the canonical payload archive
- No mystery durable app piles should accumulate directly on the hypervisor filesystem

#### `synology918`

- `/volume1/backups/proxmox_backups/dump` = canonical home VM/LXC backup lane
- `/volume1/backups/apps/media-config` = canonical primary media-home config backup lane
- `/volume1/backups/_legacy_tombstones` = explicit retired backup subtree
- `/volume1/media-staging/...` = canonical active home media import surface and the only live share currently consumed by `media-home` VM 106
- `/volume1/media-holds/...` = canonical hold or review lane, not the primary playback library
- `/volume1/documents` = drained retired root; no longer a canonical business payload surface
- `/volume1/homelab` = review-pending durable residue; not implicitly canonical
- Empty placeholder names such as `/volume1/media-home`, `/volume1/media`, `/volume1/hot-media`, `/volume1/live-library`, and `/volume1/library-home` are defects, not canonical roots

### Operator Rule

When a directory cannot be explained in one sentence using this contract, it is not boring enough yet.

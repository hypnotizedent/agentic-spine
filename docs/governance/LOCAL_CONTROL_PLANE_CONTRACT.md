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
| `agentic-spine/` | Governance control plane | Main checkout stays on `main`. Feature work uses managed worktrees. |
| `workbench/` | Operator tooling | Feature branches OK in primary checkout. |
| `mint-modules/` | Business service source | Main checkout stays on `main`. |
| `ronny-products/` | Product repos | Main checkout stays on `main`. |
| `agentic-foundation/` | Reusable implementation source | Main checkout stays on `main`. |

**Rule**: `agentic-spine` primary checkout must be on `main` and clean for daily operation. All wave/feature work happens in managed worktrees.

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
3. Pruned after branch merges to main and worktree is confirmed clean
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

- `agentic-spine/` on a feature branch as the primary checkout — all cap runs, verify, and session.start execute against this checkout
- Untracked runtime state directories appearing in `git status` — add to `.gitignore`
- Any repo's primary checkout diverged from `origin/main` by >1 day without an active reason

## Evidence Retention

| Evidence type | Path | Retention |
|---------------|------|-----------|
| Session receipts | `.evidence/spine/sessions/` | 30 days (prune older) |
| Verify reports | `.evidence/spine/verify/` | Indefinite (they document system state at points in time) |
| Loop closeouts | `.evidence/spine/loop-closeouts/` | Indefinite |
| Domain evidence | `.evidence/spine/verify/{domain}/` | Indefinite |

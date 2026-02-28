# W60 Phase 0 Baseline

Date: 2026-02-28 (UTC)
Supervisor terminal: `SPINE-CONTROL-01`
Wave: `LOOP-SPINE-W60-SUPERVISOR-CANONICAL-UPGRADE-20260227-20260302`
Subloops:
- `LOOP-SPINE-W60-TRUTH-VERIFICATION-20260227-20260302`
- `LOOP-SPINE-W60-CLEANUP-EXECUTION-20260227-20260302`
- `LOOP-SPINE-W60-REGRESSION-LOCKS-20260227-20260302`

## Mandatory Startup Evidence

- `./bin/ops cap run session.start`
  - run key: `CAP-20260227-194245__session.start__R2m857165`
- `./bin/ops cap run loops.status`
  - run key: `CAP-20260227-194304__loops.status__R69t513988`
- `./bin/ops cap run gaps.status`
  - run key: `CAP-20260227-194305__gaps.status__Ruyqc7163`

Protected-lane visibility at startup:
- Background loop present (untouched): `LOOP-MAIL-ARCHIVER-MICROSOFT-DEEP-IMPORT-20260226`
- Open protected gap present (untouched): `GAP-OP-973`
- Background MD1400 loop present (untouched): `LOOP-MD1400-CAPACITY-NORMALIZATION-20260227-20260227`

## Snapshot A (Pre-Branch, on `main`)

Captured from direct git commands before branch creation.

### `/Users/ronnyworks/code/agentic-spine`
- branch: `main`
- head: `578a50383a8faeb76c0d810541f3e73c31cd8107`
- parity:
  - `origin/main` ahead=0 behind=0
  - `github/main` ahead=0 behind=0
  - `share/main` ahead=0 behind=0
- worktrees: 1
- stashes: 0
- dirty entries: 0
- untracked count: 0

### `/Users/ronnyworks/code/workbench`
- branch: `main`
- head: `14b1d1374b2fde1f72bad3a77095d4e607d91cb3`
- parity:
  - `origin/main` ahead=0 behind=0
  - `github/main` ahead=0 behind=0
- worktrees: 1
- stashes: 0
- dirty entries: 0
- untracked count: 0

### `/Users/ronnyworks/code/mint-modules`
- branch: `main`
- head: `a07bc8124c86b5b3cd2345e6b681a947d5ea3acc`
- parity:
  - `origin/main` ahead=0 behind=0
  - `github/main` ahead=0 behind=0
- worktrees: 1
- stashes: 0
- dirty entries: 0
- untracked count: 0

## Snapshot B (Wave Branch Isolation)

Branch created in each repo:
- `codex/w60-supervisor-canonical-upgrade-20260227`

### `/Users/ronnyworks/code/agentic-spine`
- branch: `codex/w60-supervisor-canonical-upgrade-20260227`
- head: `578a50383a8faeb76c0d810541f3e73c31cd8107`
- parity:
  - `origin/codex/w60-supervisor-canonical-upgrade-20260227` missing (not pushed yet)
  - `github/codex/w60-supervisor-canonical-upgrade-20260227` missing (not pushed yet)
  - `share/codex/w60-supervisor-canonical-upgrade-20260227` missing (not pushed yet)
- worktrees: 1
- stashes: 0
- dirty entries: 0

### `/Users/ronnyworks/code/workbench`
- branch: `codex/w60-supervisor-canonical-upgrade-20260227`
- head: `14b1d1374b2fde1f72bad3a77095d4e607d91cb3`
- parity:
  - `origin/codex/w60-supervisor-canonical-upgrade-20260227` missing (not pushed yet)
  - `github/codex/w60-supervisor-canonical-upgrade-20260227` missing (not pushed yet)
- worktrees: 1
- stashes: 0
- dirty entries: 0

### `/Users/ronnyworks/code/mint-modules`
- branch: `codex/w60-supervisor-canonical-upgrade-20260227`
- head: `a07bc8124c86b5b3cd2345e6b681a947d5ea3acc`
- parity:
  - `origin/codex/w60-supervisor-canonical-upgrade-20260227` missing (not pushed yet)
  - `github/codex/w60-supervisor-canonical-upgrade-20260227` missing (not pushed yet)
- worktrees: 1
- stashes: 0
- dirty entries: 0

## Evidence Commands

- Startup and status:
  - `./bin/ops cap run session.start`
  - `./bin/ops cap run loops.status`
  - `./bin/ops cap run gaps.status`
- Pre-branch and branch snapshots:
  - `git branch --show-current`
  - `git rev-parse HEAD`
  - `git rev-list --left-right --count <remote>/<branch>...HEAD`
  - `git worktree list --porcelain`
  - `git stash list`
  - `git status --porcelain=v1`
  - `git ls-files --others --exclude-standard`

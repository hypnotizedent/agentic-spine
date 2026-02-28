# W55_PROMOTION_AND_MIGRATION_REPORTONLY_MASTER_RECEIPT_20260227

## Lifecycle Status
- Historical pre-delete receipt (report-only phase)
- Superseded by: `W56E_TOKEN_GATED_BRANCH_ZERO_RECEIPT_20260228.md`

## Decision
READY_FOR_CLEANUP_PHASE

## Branches + SHAs (before/after)

### `main`
- Precheck baseline (Phase 1 creation point): `4d6d8e7` (`docs(w56): update receipt with final communications green rerun`)
- Latest `origin/main` observed before final FF merge: `42c9379` (`docs(w56c): add token-gated branch prune receipt`)
- Promotion push parity proof point (local/origin/github/share): `5c86eaf68c393fa06b18679a573d6cd28a14cf41`
- Concurrent post-promotion advancement (protected MD1400 lane): `794ff1f1694f5c3536f670596c651718da99b01e`

### `codex/w55-worktree-lifecycle-governance-20260227`
- Before lane (fetched source): `b497e146cc2badb48cfe22d39911d06272fb3b2d`
- After required normalization commit: `7c66992`
- After rebase onto moving latest `origin/main` + final force-with-lease push: `5c86eaf68c393fa06b18679a573d6cd28a14cf41`

### `codex/w55-promote-20260227` (integration lane)
- Recreated from latest `origin/main`: `42c9379`
- FF-only merged with W55 lane: `5c86eaf68c393fa06b18679a573d6cd28a14cf41`

## Rebase Result + Conflict List

### Rebase pass 1 (onto then-current `origin/main`)
- Status: completed with manual conflict resolution, then `git rebase --continue` success.
- Conflict files:
  - `docs/planning/W55_WORKTREE_LIFECYCLE_CANONICALIZATION_MASTER_RECEIPT.md`
  - `ops/bindings/gate.registry.yaml`
  - `ops/bindings/worktree.lifecycle.contract.yaml`
  - `ops/plugins/ops/bin/worktree-lifecycle-cleanup`
- Resolution policy: conservative upstream-preserving conflict resolution (`main` side retained in conflict hunks), then continued rebase.

### Rebase pass 2 (after `origin/main` moved during lane)
- Status: clean success; no conflicts.
- Resulting branch tip: `5c86eaf68c393fa06b18679a573d6cd28a14cf41`

## Exact `archive_root` Patch Proof

Patched contract target:
- `ops/bindings/worktree.lifecycle.contract.yaml`

Proof (`rg -n "archive_root|/code/_closeout_backups" ops/bindings/worktree.lifecycle.contract.yaml`):
```text
39:  archive_root: "~/.local/state/agentic-spine/worktree-lifecycle-archive"
```
- No `/code/_closeout_backups` match remains in this contract.

## Verify Run Keys + Pass/Fail

### Required hard verify block
- `gate.topology.validate`
  - Run Key: `CAP-20260227-185116__gate.topology.validate__Rvwc758846`
  - Result: PASS
- `verify.pack.run secrets`
  - Run Key: `CAP-20260227-185120__verify.pack.run__Rn1f859120`
  - Result: PASS
- `verify.pack.run mint` (first run in isolated promotion worktree)
  - Run Key: `CAP-20260227-185120__verify.pack.run__Rjbcn59121`
  - Result: FAIL (`D205` missing local external snapshot/index runtime artifacts in isolated worktree)
- `verify.pack.run mint` (rerun after local runtime snapshot/index materialization)
  - Run Key: `CAP-20260227-185403__verify.pack.run__Rs0x181923`
  - Result: PASS

### Baseline comparison check
- `verify.pack.run mint` on canonical repo main
  - Run Key: `CAP-20260227-185213__verify.pack.run__R7h3g74252`
  - Result: PASS

## Main Push Parity (local/origin/github/share)

### At promotion push proof moment
- Local `HEAD`: `5c86eaf68c393fa06b18679a573d6cd28a14cf41`
- `origin/main`: `5c86eaf68c393fa06b18679a573d6cd28a14cf41`
- `github/main`: `5c86eaf68c393fa06b18679a573d6cd28a14cf41`
- `share/main`: `5c86eaf68c393fa06b18679a573d6cd28a14cf41`

### Current parity snapshot (post-lane concurrent MD1400 commit)
- `origin/main`: `794ff1f1694f5c3536f670596c651718da99b01e`
- `github/main`: `794ff1f1694f5c3536f670596c651718da99b01e`
- `share/main`: `794ff1f1694f5c3536f670596c651718da99b01e`
- Ancestry check: `5c86eaf` is an ancestor of `794ff1f` (promotion preserved).

## Report-Only Mapping Table (old_path -> new_path)

Report-only commands executed:
- `worktree.lifecycle.cleanup -- --mode report-only --json`
  - Run Key (canonical root execution): `CAP-20260227-185702__worktree.lifecycle.cleanup__R872y96154`
- `worktree.lifecycle.reconcile -- --json`
  - Run Key (canonical root execution): `CAP-20260227-185709__worktree.lifecycle.reconcile__R4yyc96453`

Mapping candidates extracted from report-only/root-violation evidence:

| old_path | canonical_new_path (`~/.wt/<repo>/<lane>`) | classification |
|---|---|---|
| `/Users/ronnyworks/code/agentic-spine-w55-promote` | `~/.wt/agentic-spine/w55-promote` | noncanonical worktree-root candidate |

Candidate count: `1`

## Invariant Check (No Mutation)

### `/Users/ronnyworks/code` top-level directories
- `README.md`
- `agentic-spine`
- `mint-modules`
- `workbench`

### Registered worktrees by repo
- `agentic-spine`
  - `/Users/ronnyworks/code/agentic-spine` (`main`, `794ff1f1694f5c3536f670596c651718da99b01e`)
- `mint-modules`
  - `/Users/ronnyworks/code/mint-modules` (`main`, `0c7d06ad28d138959886f69e9ef1c2e68f7179ea`)
- `workbench`
  - `/Users/ronnyworks/code/workbench` (`main`, `14b1d1374b2fde1f72bad3a77095d4e607d91cb3`)

## Protected Lane Attestation (Untouched)

No direct branch mutation, delete command, or lifecycle cleanup delete/archive mode was executed by this lane against protected no-touch lanes:
- `LOOP-MAIL-ARCHIVER-MICROSOFT-DEEP-IMPORT-20260226`
- `GAP-OP-973`
- EWS import lane
- MD1400 lane

Observed concurrently (external to this lane):
- `main` advanced to `794ff1f` with message `docs(w56a): normalize recovered md1400 loop-scope vocabulary for D145`.

## Invariant Statement: No Delete/Archive Execution Performed

Explicit attestation:
- No `worktree.lifecycle.cleanup -- --mode archive-only ...` was run.
- No `worktree.lifecycle.cleanup -- --mode delete ...` was run.
- No `git worktree remove` was executed in this lane.
- All lifecycle cleanup invocations in-lane were report-only classification runs.

# W52R Drift Reconciliation Receipt (2026-02-27)

## Branch Head
- branch: `codex/w52-reconcile-from-snapshot-20260227`
- head_sha: `0197352064258eb5d4e36af6d1d017ac697c67a2`
- base_snapshot: `codex/w52-drift-snapshot-20260227-041806 @ 6a82eda04a879ac70853c1774a25179ac9e5d4f9`

## Cherry-Pick Chain (Old -> New)
- `5905692` -> `166a3e9` (`w52: capture containment automation + homarr planning and gate drafts`)
- `d1e22d6` -> `16852a2` (`w52: capture gate topology and registry updates`)
- `9c9a49d` -> `38ddc25` (`w52: capture additional in-flight homarr and gate profile updates`)
- `5f3e791` -> `0197352` (`w52: capture canonical docs path trigger coverage`)

## Verify Commands (Required 4)
1. `./bin/ops cap run d245-media-tier-aware-health-severity-lock`
- result: `FAIL` (command-level)
- run_key: none (capability not registered)
- detail: `Unknown capability: d245-media-tier-aware-health-severity-lock`

2. `./bin/ops cap run verify.pack.run media`
- result: `FAIL`
- run_key: `CAP-20260227-042047__verify.pack.run__Ra5th17987`
- summary: `pass=14 fail=3`
- failing gates: `D108`, `D191`, `D192`

3. `./bin/ops cap run gate.topology.validate`
- result: `PASS`
- run_key: `CAP-20260227-042111__gate.topology.validate__Ric1j28147`

4. `./bin/ops cap run verify.pack.run mint`
- result: `PASS`
- run_key: `CAP-20260227-042113__verify.pack.run__Rma3g29211`
- summary: `pass=26 fail=0`

## D245 Registration / Runnable State
- Registered in gate topology/packs: `yes` (executed as `D245 PASS` within media pack).
- Runnable as direct capability command: `no` (not in capability map).
- Runnable as gate script: `yes` (`bash surfaces/verify/d245-media-tier-aware-health-severity-lock.sh` => `PASS with WARNINGS`).

## Remaining Failures and Classification
- `D108` fail (`tdarr` endpoint returned `000000`): external/runtime endpoint reachability issue.
- `D191` fail (media content snapshot stale >24h): baseline data freshness issue.
- `D192` fail (snapshot stale contract violation): baseline data freshness issue.
- No reconciliation conflicts occurred during cherry-picks.

## Attestation
- No protected lane mutation performed:
  - `LOOP-MAIL-ARCHIVER-MICROSOFT-DEEP-IMPORT-20260226`
  - `GAP-OP-973`
  - `EWS import lane`
  - `MD1400 rsync lane`
- No destructive cleanup performed (`reset`, `prune`, `delete`, `hard cleanup` not used).
- No local `main` used as source for replay; source commits were cherry-picked by explicit SHA only.

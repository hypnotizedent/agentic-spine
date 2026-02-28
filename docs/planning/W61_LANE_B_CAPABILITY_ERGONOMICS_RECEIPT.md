# W61 Lane B Capability Ergonomics Receipt

Date: 2026-02-28 (UTC)
Wave: `LOOP-SPINE-W61-AGENT-FRICTION-CONSOLIDATION-20260228-20260303`
Lane: B (`capability ergonomics`)

## Implemented

1. `cap show` now exposes actionable capability metadata for high-friction surfaces via capability contract fields (`flags`, `modes`, `examples`).
2. Mode auto-injection enabled for high-friction Proxmox maintenance capabilities:
   - `infra.proxmox.maintenance.precheck` -> command now includes `--mode precheck`
   - `infra.proxmox.maintenance.shutdown` -> command now includes `--mode shutdown`
   - `infra.proxmox.maintenance.startup` -> command now includes `--mode startup`
3. Updated `infra-maintenance-window` to stop redundantly passing explicit `--mode` flags.
4. `gaps.file` lock/throughput ergonomics hardening:
   - fixed `--batch` YAML root detection parser compatibility
   - added lock retry window (`--wait-seconds`, default 15)
   - retained atomic lock behavior while reducing immediate contention failure loops
5. `loops.create` default scaffold vocabulary normalized to Step-based structure (`Step 1/2/3`).

## Timing Snapshot (before/after evidence)

- Baseline (from `GAP-OP-1099`): repeated sequential `gaps.file` calls observed at ~3-5s each in operator flow.
- Current wave measurements:
  - `show_precheck_elapsed_ms=93`
  - `show_gaps_file_elapsed_ms=89`
  - `gaps_file_empty_batch rc=2 elapsed_ms=237` (parser path no longer fails with yq lexer syntax)
  - `gaps_file_lock_wait rc=1 elapsed_ms=2297` with `--wait-seconds 2` (retry window works as designed)

## Command UX Examples

- Precheck (no manual mode flag needed):
  - `./bin/ops cap run infra.proxmox.maintenance.precheck -- --host-id pve`
- Shutdown (mode auto-injected):
  - `./bin/ops cap run infra.proxmox.maintenance.shutdown -- --host-id pve --execute --poweroff`
- Gap filing with enforced linkage + retry window:
  - `./bin/ops cap run gaps.file -- --id auto --type runtime-bug --severity high --description "..." --discovered-by LOOP-... --parent-loop LOOP-... --wait-seconds 15`

## Evidence Files

- `ops/capabilities.yaml`
- `ops/plugins/infra/bin/infra-maintenance-window`
- `ops/plugins/loops/bin/gaps-file`
- `ops/plugins/lifecycle/bin/loops-create`

---
status: draft
owner: "@ronny"
last_verified: 2026-02-17
scope: aof-workbench-normalization-implementation
parent_loop: LOOP-WORKBENCH-AOF-NORMALIZATION-IMPLEMENT-20260217
---

# AOF Workbench Normalization Implementation Plan (2026-02-17)

## Objective
Convert the 3-lane audit findings into governed remediation batches that can be applied safely in multi-agent mode.

## Inputs
- Verification report summary: 21 findings total (P0=3, P1=9, P2=9) across L1/L2/L3.
- Contract authority: `/Users/ronnyworks/code/workbench/infra/contracts/workbench.aof.contract.yaml`.
- Domain gate evidence:
  - `CAP-20260217-075153__stability.control.snapshot__R0dd681186`
  - `CAP-20260217-075153__verify.core.run__Rtfz181187`
  - `CAP-20260217-075249__verify.domain.run__Rr54i96992` (workbench failed D72/D73/D79/D80)
  - `CAP-20260217-075249__verify.domain.run__R8gnc96993` (aof pass)
  - `CAP-20260217-075249__verify.domain.run__Rtbfk96994` (secrets pass)

## Current Constraints
- Multi-agent mode is active; use proposal flow only for tracked-file changes.
- Existing pending proposal already covers extraction-sweep synthesis: `CP-20260217-071243__aof-final-ronny-ops-extraction-sweep-execution--lane-audits--synthesis--gap-registration--proxmox-alignment-backlog`.
- `GAP-OP-590` is open and currently unlinked; link to parent loop before closeout.
- `spine.audit.triage` is currently broken (`CAP-20260217-075326__spine.audit.triage__Re9ze5109`: `AttributeError: 'Loop' object has no attribute 'description'`). Treat as runtime bug and register before fix.

## Execution Batches

### Batch A (P0 blockers, immediate)
1. Workbench compose safety baseline
- Enforce logging, resource limits, restart policy, healthcheck start period, depends_on conditions.
- Normalize bind exposure to `127.0.0.1:` unless explicitly allowlisted.
- Target surfaces: `workbench/infra/compose/**`, `workbench/infra/cloudflare/tunnel/**`.

2. Schema normalization in authoritative inventories/docs
- `vmid` -> `vm_id`
- `last_snapshot` / `snapshot_date` -> `last_verified`
- Ensure `parent_loop` is canonical loop linkage field.
- Apply required frontmatter (`status`, `owner`, `last_verified`, `scope`) for governed docs in active paths.

3. Secrets canonicalization hard-block set
- Remove deprecated project routing (`finance-stack`, `mint-os-vault`) in active scripts/docs.
- Normalize deprecated key aliases (`FIREFLY_ACCESS_TOKEN`, `HA_TOKEN`, `PAPERLESS_SECRET_KEY`) to canonical keys in contract.

### Batch B (P1 remediation)
1. Workbench gate failures from forced domain verify
- D72: MacBook hotkey SSOT drift (`sync_laptop_hotkeys_docs.sh --write-spine` alignment path).
- D73: Hammerspoon `Ctrl+Shift+O` routing contract.
- D79: register `scripts/root/aof/workbench-aof-check.sh` or move to sanctioned surface.
- D80: remove active-surface `docs/legacy/` reference in strict authority trace.

2. Runtime alignment and naming parity backlog
- Resolve `pve-shop` / `proxmox-shop` / `pve-home` alias drift in workbench inventories to canonical `pve` / `proxmox-home`.
- Confirm vm/ssh coverage parity against spine SSOT for active VMs.

### Batch C (P2 and deferred)
1. Keep transitional exceptions in allowlist only
- `docs/legacy` remains warn-only through `2026-12-31` per contract.

2. Defer non-blocking archival and historical doc harmonization
- Execute after P0/P1 cut.

## Proposal Sequence
1. Submit one proposal per batch to keep review/apply atomic and reversible.
2. Each proposal must include receipt notes with:
- affected files
- contract clauses satisfied
- verify evidence run keys
3. Apply proposals in order: Batch A -> Batch B -> Batch C.

## Verification and Exit
1. Re-run:
- `./bin/ops cap run stability.control.snapshot`
- `./bin/ops cap run verify.core.run`
- `./bin/ops cap run verify.domain.run workbench --force`
- `./bin/ops cap run verify.domain.run aof --force`
- `./bin/ops cap run verify.domain.run secrets --force`
2. Add domain impact notes via `docs.impact.note` for touched domains.
3. Link and close residual gap artifacts (`GAP-OP-590`, plus triage capability bug gap once filed/fixed).

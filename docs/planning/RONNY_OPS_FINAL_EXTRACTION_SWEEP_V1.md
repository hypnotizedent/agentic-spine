---
status: draft
owner: "@ronny"
last_verified: 2026-02-17
scope: ronny-ops-final-extraction-sweep-v1
parent_loop: LOOP-RONNY-OPS-FINAL-EXTRACTION-SWEEP-20260217
---

# Ronny-Ops Final Extraction Sweep (v1)

## Objective

Run one final, exhaustive extraction/debt sweep of `/Users/ronnyworks/ronny-ops` so all remaining authoritative assets are moved into `/Users/ronnyworks/code/*`, legacy debt is registered, and the legacy repo can be retired to read-only archive.

## Why This Is Highest Leverage

1. Removes final hidden legacy dependencies.
2. Prevents future agent confusion about source-of-truth.
3. Aligns all active execution (spine/workbench/proxmox/product repos) to the AOF model.

## Scope

In scope:
1. Legacy discovery and classification from `/Users/ronnyworks/ronny-ops/**`.
2. Extraction backlog for `agentic-spine`, `workbench`, `mint-modules`, and VM/runtime surfaces.
3. Proxmox alignment baseline for all active clusters/VM contracts.
4. Gap registration for unresolved legacy debt.

Out of scope:
1. Secret value rotation.
2. Mass rewrites of legacy docs (use `archive_then_delete` policy instead).
3. New drift gate creation.

## Lane Model (Parallel OpenCode Terminals)

1. `LANE-A` Legacy Census + Routing
   - Full tree census of `ronny-ops`.
   - Classify each top-level subtree: `extract`, `archive`, `drop`.

2. `LANE-B` Runtime/Infra/Compose Debt
   - Compare legacy compose/deploy scripts with workbench canonical stacks.
   - Identify missing service ownership, restart/logging/resource patterns.

3. `LANE-C` Domain/Product/Runbook Debt
   - Compare legacy domain docs/runbooks with active workbench+spine docs.
   - Identify missing high-value knowledge still stranded in legacy.

4. `LANE-D` Proxmox AOF Alignment
   - Validate VM authority across `vm.lifecycle*`, `ssh.targets`, backups, runbooks.
   - Produce mismatch list per cluster (`pve`, `pve-shop`, `proxmox-home`).

## Required Outputs

Write only to:
`/Users/ronnyworks/code/agentic-spine/docs/governance/_audits/RONNY_OPS_FINAL_EXTRACTION_INBOX_20260217/`

Required files:
1. `L1_LEGACY_CENSUS.md`
2. `L2_RUNTIME_INFRA_DIFF.md`
3. `L3_DOMAIN_DOCS_DIFF.md`
4. `L4_PROXMOX_ALIGNMENT_DIFF.md`
5. `SYNTHESIS.md`
6. `EXTRACTION_BACKLOG.md`

## Acceptance Criteria

1. Every top-level `ronny-ops` folder has explicit disposition (`extract|archive|drop`).
2. All non-trivial missing assets are registered as gaps with severity + target repo.
3. Proxmox alignment mismatches are enumerated with exact SSOT file targets.
4. A sequenced extraction backlog is ready for execution without rediscovery.
5. Legacy repo retirement decision can be made from one synthesis artifact.

## Execution Sequence

1. Run all four lanes in parallel (read-only discovery only).
2. Consolidate to `SYNTHESIS.md` + `EXTRACTION_BACKLOG.md`.
3. Register gaps for unresolved debt.
4. Open follow-on implementation loop(s) by priority:
   - P0 authoritative runtime drift
   - P1 extraction missing knowledge
   - P2 archive/deletion cleanup

---
status: working
owner: "@ronny"
created: 2026-02-25
scope: mint-cleanup-execution-map
authority: ORCHESTRATOR-MINT-BUILDABILITY-TRIAGE-20260225
---

# Mint Cleanup Execution Map (2026-02-25)

Canonical runtime-truth policy:
`/Users/ronnyworks/code/agentic-spine/docs/planning/MINT_RUNTIME_TRUTH_CANONICAL_20260225.md`

## Queue Construction Rules Applied

1. Dedupe by objective: one task appears in one queue only.
2. Loop-first ownership: map to existing Mint loops before proposing any new loop.
3. `A2/A3` items are listed but marked non-coding/deferred.

## 1) Repo Cleanup Queue

| task_id | scope | source_findings | autonomy | target_loop_id |
|---|---|---|---|---|
| RC-01 | Create shared Mint probe target binding and refactor `modules-health`, `runtime-proof`, `deploy-status` to consume it. | F-003, F-004 | A0 | LOOP-MINT-RUNTIME-PROBE-CONSISTENCY-20260225 |
| RC-02 | Align `ops/plugins/mint/bin/loop-daily` output to include Mint-specific verify lane run-key capture and consistency summary. | F-003, F-015 | A0 | LOOP-MINT-RUNTIME-PROBE-CONSISTENCY-20260225 |
| RC-03 | Normalize legacy runtime annotations across `docker.compose.targets` + Mint docs (legacy duplicate stack marked non-authoritative). | F-005, F-006, F-014 | A0 | LOOP-MINT-LEGACY-RUNTIME-DETACH-CLEANUP-20260225 |
| RC-04 | Add anti-duplicate checklist snippet to Mint planning docs (must reference `REJECTED_DUPLICATE` table before any build task). | F-015 | A0 | LOOP-MINT-SSOT-DOC-RUNTIME-ALIGNMENT-20260225 |

## 2) Doc Cleanup Queue

| task_id | scope | source_findings | autonomy | target_loop_id |
|---|---|---|---|---|
| DC-01 | Publish canonical Mint runtime-truth doc with trusted baseline + explicit defers. | F-001, F-012 | A0 | LOOP-MINT-SSOT-DOC-RUNTIME-ALIGNMENT-20260225 |
| DC-02 | Reclassify module wording to `APPROVED_BY_RONNY` / `BUILT_NOT_STAMPED` / `NOT_BUILT` across transition and roadmap docs. | F-002, F-012 | A0 | LOOP-MINT-RONNY-APPROVAL-STAMP-LANE-20260225 |
| DC-03 | Add cross-links from roadmap/execution queue/transition docs to canonical runtime-truth source. | F-001, F-012 | A0 | LOOP-MINT-SSOT-DOC-RUNTIME-ALIGNMENT-20260225 |
| DC-04 | Add explicit policy text: no "works/live" claims without run key + Ronny stamp. | F-002, F-013 | A0 | LOOP-MINT-RONNY-APPROVAL-STAMP-LANE-20260225 |

## 3) Runtime Cleanup Queue

| task_id | scope | source_findings | autonomy | target_loop_id |
|---|---|---|---|---|
| RT-01 | Run 3 consecutive timed probe sets (`health`, `deploy`, `proof`) in one runtime window and publish discrepancy table. | F-003, F-004 | A0 | LOOP-MINT-RUNTIME-PROBE-CONSISTENCY-20260225 |
| RT-02 | Payment env preflight on VM 213 + targeted `payment` deploy sync. | F-007 | A1 | LOOP-MINT-PAYMENT-RUNTIME-READINESS-20260225 |
| RT-03 | Payment safe smoke path capture (checkout create + webhook receive validation) with binary status output only. | F-007 | A1 | LOOP-MINT-PAYMENT-RUNTIME-READINESS-20260225 |
| RT-04 | Suppliers stock parity fix/proof cycle (`/stock` endpoint behavior). | F-010 | A1 | LOOP-MINT-RUNTIME-PROBE-CONSISTENCY-20260225 |
| RT-05 | Artwork upload prepare parity fix/proof cycle (`/files/upload/prepare` behavior). | F-011 | A1 | LOOP-MINT-RUNTIME-PROBE-CONSISTENCY-20260225 |
| RT-06 | Operator-approved detach of legacy docker-host duplicate module runtime paths with before/after receipts. | F-005, F-006 | A1 | LOOP-MINT-LEGACY-RUNTIME-DETACH-CLEANUP-20260225 |

## 4) Regression Gate Queue

| task_id | scope | source_findings | autonomy | target_loop_id |
|---|---|---|---|---|
| RG-01 | Add Mint live-claim stamp lock gate (`run key + Ronny stamp` required for live wording). | F-013 | A0 | LOOP-MINT-SSOT-DOC-RUNTIME-ALIGNMENT-20260225 |
| RG-02 | Add no-legacy-authority lock gate (block mint runtime-truth claims sourced from docker-host/`ronny-ops`). | F-014 | A0 | LOOP-MINT-LEGACY-RUNTIME-DETACH-CLEANUP-20260225 |
| RG-03 | Extend Mint baseline status output to include canonical target IDs/hosts used during probe evaluation. | F-003, F-004 | A0 | LOOP-MINT-RUNTIME-PROBE-CONSISTENCY-20260225 |
| RG-04 | Add Mint lane closeout check requiring `verify.pack.run mint` + `verify.core.run` evidence keys in receipts. | F-015 | A0 | LOOP-MINT-SSOT-DOC-RUNTIME-ALIGNMENT-20260225 |

## 5) Contract Completion Queue

| task_id | scope | source_findings | autonomy | target_loop_id |
|---|---|---|---|---|
| CC-01 | Build Ronny stamp matrix for built components only; include operator test steps + evidence fields. | F-002 | A1 | LOOP-MINT-RONNY-APPROVAL-STAMP-LANE-20260225 |
| CC-02 | Publish payment runtime readiness contract (`NOT_LIVE` vs `READY_FOR_RONNY_STAMP`) with explicit blockers. | F-007 | A0 | LOOP-MINT-PAYMENT-RUNTIME-READINESS-20260225 |
| CC-03 | Publish "Current Contract vs Needed Contract" table for built-only lanes. | F-001, F-012 | A0 | LOOP-MINT-SSOT-DOC-RUNTIME-ALIGNMENT-20260225 |
| CC-04 | Keep deferred contract register for auth extraction and payment->finance bridge (explicit no-build state). | F-008, F-009 | A3 | LOOP-MINT-SSOT-DOC-RUNTIME-ALIGNMENT-20260225 |

## 6) Enforcement Joint Queue

| task_id | scope | source_findings | autonomy | target_loop_id |
|---|---|---|---|---|
| EJ-01 | Add execution-map ledger mapping each first-wave task to exactly one loop ID. | F-015 | A0 | LOOP-MINT-SSOT-DOC-RUNTIME-ALIGNMENT-20260225 |
| EJ-02 | Add pre-task duplicate-build check step against `REJECTED_DUPLICATE` domains/endpoints. | F-015 | A0 | LOOP-MINT-SSOT-DOC-RUNTIME-ALIGNMENT-20260225 |
| EJ-03 | Require `loops.status` + `gaps.status` snapshots at Mint closeout to prevent orphan work. | F-016 | A0 | LOOP-MINT-SSOT-DOC-RUNTIME-ALIGNMENT-20260225 |
| EJ-04 | Keep auth and supplier mutation lanes explicitly deferred in every execution artifact. | F-008, F-009 | A3 | LOOP-MINT-SSOT-DOC-RUNTIME-ALIGNMENT-20260225 |

## 7) Boundary / No-Legacy Queue

| task_id | scope | source_findings | autonomy | target_loop_id |
|---|---|---|---|---|
| BN-01 | Tag `docker-host` module-equivalent runtime as `LEGACY_ONLY` and non-authoritative for Mint truth. | F-005, F-006 | A0 | LOOP-MINT-LEGACY-RUNTIME-DETACH-CLEANUP-20260225 |
| BN-02 | Add explicit boundary statement: `/Users/ronnyworks/ronny-ops` is reference-only, never live truth source. | F-014 | A0 | LOOP-MINT-LEGACY-RUNTIME-DETACH-CLEANUP-20260225 |
| BN-03 | Maintain legacy Mint probes as disabled and documented as non-authoritative. | F-006 | A0 | LOOP-MINT-LEGACY-RUNTIME-DETACH-CLEANUP-20260225 |
| BN-04 | Add route/runtime claim check: no conflation between old docker-host and mint-apps/mint-data truth path. | F-014 | A0 | LOOP-MINT-LEGACY-RUNTIME-DETACH-CLEANUP-20260225 |

## Queue Totals

- Repo Cleanup Queue: 4 tasks
- Doc Cleanup Queue: 4 tasks
- Runtime Cleanup Queue: 6 tasks
- Regression Gate Queue: 4 tasks
- Contract Completion Queue: 4 tasks
- Enforcement Joint Queue: 4 tasks
- Boundary/No-Legacy Queue: 4 tasks
- Total deduped tasks: 30

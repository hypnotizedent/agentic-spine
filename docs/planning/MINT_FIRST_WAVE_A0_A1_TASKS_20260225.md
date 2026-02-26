---
status: working
owner: "@ronny"
created: 2026-02-25
scope: mint-first-wave-a0-a1
authority: ORCHESTRATOR-MINT-BUILDABILITY-TRIAGE-20260225
---

# Mint First-Wave A0/A1 Tasks (2026-02-25)

## Candidate Filter Applied

- Included: `A0` and `A1` only.
- Excluded: auth build, payment->finance bridge build, supplier mutation tooling, and any unbuilt module extraction (`A2/A3`).
- Loop rule: mapped to existing Mint loops only.

## A0 Candidates (Autonomous Now)

### A0-01 Canonical Runtime Truth + Cross-Link Normalization
- exact files to edit:
  - `/Users/ronnyworks/code/agentic-spine/docs/planning/MINT_RUNTIME_TRUTH_CANONICAL_20260225.md` (new)
  - `/Users/ronnyworks/code/mint-modules/docs/ARCHITECTURE/MINT_TRANSITION_STATE.md`
  - `/Users/ronnyworks/code/mint-modules/docs/PLANNING/MINT_ORDER_AGENT_ROADMAP_SSOT.md`
  - `/Users/ronnyworks/code/mint-modules/docs/PLANNING/MINT_MODULE_EXECUTION_QUEUE.md`
- reason: resolves conflicting "live" wording and aligns all docs to one trusted baseline.
- tests/gates to run:
  - `./bin/ops cap run verify.pack.run mint`
  - `./bin/ops cap run verify.core.run`
  - `rg -n "APPROVED_BY_RONNY|BUILT_NOT_STAMPED|NOT_BUILT" /Users/ronnyworks/code/mint-modules/docs /Users/ronnyworks/code/agentic-spine/docs/planning`
- done condition: one canonical runtime-truth doc exists and all listed docs reference it.
- why not duplicate build evidence: doc-only scope; queue already marks 23 endpoints `REJECTED_DUPLICATE`.
- target_loop_id: `LOOP-MINT-SSOT-DOC-RUNTIME-ALIGNMENT-20260225`

### A0-02 Shared Probe Target Manifest + Script Refactor
- exact files to edit:
  - `/Users/ronnyworks/code/agentic-spine/ops/bindings/mint.probe.targets.yaml` (new)
  - `/Users/ronnyworks/code/agentic-spine/ops/plugins/mint/bin/modules-health`
  - `/Users/ronnyworks/code/agentic-spine/ops/plugins/mint/bin/runtime-proof`
  - `/Users/ronnyworks/code/agentic-spine/ops/plugins/mint/bin/deploy-status`
  - `/Users/ronnyworks/code/agentic-spine/ops/plugins/mint/bin/mint-live-baseline-status`
- reason: removes probe target drift and makes health/deploy/proof comparable in one runtime window.
- tests/gates to run:
  - `./bin/ops cap run mint.modules.health`
  - `./bin/ops cap run mint.deploy.status`
  - `./bin/ops cap run mint.runtime.proof`
  - `./bin/ops cap run mint.live.baseline.status`
- done condition: all Mint probe scripts resolve host/port targets from one binding and print target IDs in output.
- why not duplicate build evidence: orchestration-only change in spine; no module extraction or rebuild.
- target_loop_id: `LOOP-MINT-RUNTIME-PROBE-CONSISTENCY-20260225`

### A0-03 Add Gate: Mint Live-Claim Stamp Lock
- exact files to edit:
  - `/Users/ronnyworks/code/agentic-spine/surfaces/verify/d226-mint-live-claim-stamp-lock.sh` (new)
  - `/Users/ronnyworks/code/agentic-spine/ops/bindings/gate.registry.yaml`
  - `/Users/ronnyworks/code/agentic-spine/ops/bindings/gate.execution.topology.yaml`
  - `/Users/ronnyworks/code/agentic-spine/ops/bindings/gate.domain.profiles.yaml`
- reason: enforces "no live claim without run key + Ronny stamp" policy in CI/verify lane.
- tests/gates to run:
  - `./bin/ops cap run verify.pack.run mint`
  - `./bin/ops cap run verify.core.run`
- done condition: gate is registered, mapped to Mint domain, and fails when unsupported live wording appears.
- why not duplicate build evidence: governance gate only; prevents duplicate runtime truth claims.
- target_loop_id: `LOOP-MINT-SSOT-DOC-RUNTIME-ALIGNMENT-20260225`

### A0-04 Add Gate: No-Legacy-Authority Lock
- exact files to edit:
  - `/Users/ronnyworks/code/agentic-spine/surfaces/verify/d227-mint-no-legacy-authority-lock.sh` (new)
  - `/Users/ronnyworks/code/agentic-spine/ops/bindings/gate.registry.yaml`
  - `/Users/ronnyworks/code/agentic-spine/ops/bindings/gate.execution.topology.yaml`
  - `/Users/ronnyworks/code/agentic-spine/ops/bindings/gate.domain.profiles.yaml`
- reason: enforces boundary that `docker-host` and `/Users/ronnyworks/ronny-ops` are not authoritative Mint runtime truth.
- tests/gates to run:
  - `./bin/ops cap run verify.pack.run mint`
  - `./bin/ops cap run verify.core.run`
- done condition: gate fails on legacy-authoritative wording and passes on reference-only wording.
- why not duplicate build evidence: boundary enforcement only; no new module behavior added.
- target_loop_id: `LOOP-MINT-LEGACY-RUNTIME-DETACH-CLEANUP-20260225`

### A0-05 Mint Daily Loop Evidence Alignment
- exact files to edit:
  - `/Users/ronnyworks/code/agentic-spine/ops/plugins/mint/bin/loop-daily`
- reason: standardizes daily loop output so runtime proof and verify evidence are captured consistently.
- tests/gates to run:
  - `./bin/ops cap run mint.loop.daily -- --summary`
  - `./bin/ops cap run loops.status`
  - `./bin/ops cap run gaps.status`
- done condition: summary includes health/deploy/proof and closeout-friendly evidence markers.
- why not duplicate build evidence: operational wrapper change only.
- target_loop_id: `LOOP-MINT-RUNTIME-PROBE-CONSISTENCY-20260225`

### A0-06 Anti-Duplicate Checklist Injection
- exact files to edit:
  - `/Users/ronnyworks/code/mint-modules/docs/PLANNING/MINT_MODULE_EXECUTION_QUEUE.md`
  - `/Users/ronnyworks/code/mint-modules/docs/PLANNING/MINT_ORDER_AGENT_ROADMAP_SSOT.md`
- reason: forces explicit check against already covered domains before any new coding task is accepted.
- tests/gates to run:
  - `./bin/ops cap run verify.pack.run mint`
  - `rg -n "REJECTED_DUPLICATE|no duplicate rebuild" /Users/ronnyworks/code/mint-modules/docs/PLANNING`
- done condition: both docs contain a first-step duplicate-screen checklist tied to the 23-endpoint table.
- why not duplicate build evidence: this task only blocks duplicate work; it does not add runtime code.
- target_loop_id: `LOOP-MINT-SSOT-DOC-RUNTIME-ALIGNMENT-20260225`

### A0-07 Payment Runtime Readiness Contract Artifact
- exact files to edit:
  - `/Users/ronnyworks/code/agentic-spine/docs/planning/MINT_PAYMENT_RUNTIME_READINESS_CONTRACT_20260225.md` (new)
  - `/Users/ronnyworks/code/agentic-spine/mailroom/state/loop-scopes/LOOP-MINT-PAYMENT-RUNTIME-READINESS-20260225.scope.md` (link update)
- reason: removes ambiguous payment status language by requiring binary outcome (`NOT_LIVE` or `READY_FOR_RONNY_STAMP`).
- tests/gates to run:
  - `./bin/ops cap run verify.pack.run mint`
  - `./bin/ops cap run verify.core.run`
- done condition: contract includes required run keys and blocked dependency declaration (payment->finance bridge deferred).
- why not duplicate build evidence: contract/doc only; no payment feature implementation.
- target_loop_id: `LOOP-MINT-PAYMENT-RUNTIME-READINESS-20260225`

### A0-08 Ronny Stamp Matrix Template Scaffold
- exact files to edit:
  - `/Users/ronnyworks/code/agentic-spine/docs/planning/MINT_RONNY_STAMP_MATRIX_20260225.md` (new)
- reason: prepares built-module-only stamp lane without claiming new live truth.
- tests/gates to run:
  - `./bin/ops cap run verify.core.run`
- done condition: template enumerates built surfaces with required fields (test steps, run key, stamp state).
- why not duplicate build evidence: template only; no runtime mutation.
- target_loop_id: `LOOP-MINT-RONNY-APPROVAL-STAMP-LANE-20260225`

## A1 Candidates (Autonomous With Operator Env/Approval)

### A1-01 Populate Ronny Stamp Matrix With Operator Executed Tests
- exact files to edit:
  - `/Users/ronnyworks/code/agentic-spine/docs/planning/MINT_RONNY_STAMP_MATRIX_20260225.md`
- reason: converts `BUILT_NOT_STAMPED` into explicit stamped/not-stamped statuses per module.
- tests/gates to run:
  - `./bin/ops cap run mint.modules.health`
  - `./bin/ops cap run mint.runtime.proof`
  - module-specific operator test script references recorded per row
- done condition: every built module has `APPROVED_BY_RONNY` or `BUILT_NOT_STAMPED` with run key evidence.
- why not duplicate build evidence: validates existing builds; no new module implementation.
- target_loop_id: `LOOP-MINT-RONNY-APPROVAL-STAMP-LANE-20260225`

### A1-02 Payment Env Provision + Targeted Deploy + Safe Smoke
- exact files to edit:
  - `/opt/stacks/mint-apps/.env` (operator-managed runtime env)
  - `/Users/ronnyworks/code/agentic-spine/docs/planning/MINT_PAYMENT_RUNTIME_READINESS_CONTRACT_20260225.md`
- reason: payment is built but blocked from runtime readiness by env/deploy preconditions.
- tests/gates to run:
  - `./bin/ops cap run mint.deploy.sync -- --modules payment`
  - `./bin/ops cap run mint.modules.health`
  - `./bin/ops cap run mint.runtime.proof`
  - `./bin/ops cap run mint.live.baseline.status`
- done condition: payment health reachable and readiness classified with no end-to-end order-lifecycle claim.
- why not duplicate build evidence: runtime enablement of existing payment module only.
- target_loop_id: `LOOP-MINT-PAYMENT-RUNTIME-READINESS-20260225`

### A1-03 Suppliers Stock Parity Runtime Remediation
- exact files to edit:
  - `/Users/ronnyworks/code/mint-modules/suppliers/src/routes/suppliers.ts`
  - `/Users/ronnyworks/code/mint-modules/suppliers/src/services/supplier-repository.ts`
  - `/Users/ronnyworks/code/mint-modules/suppliers/src/__tests__/suppliers.test.ts`
- reason: resolves `BLOCKER-SUPPLIERS-STOCK-PARITY` where stock lookup can fail after successful search.
- tests/gates to run:
  - `cd /Users/ronnyworks/code/mint-modules && npm --prefix suppliers test`
  - `./bin/ops cap run mint.runtime.proof`
  - `./bin/ops cap run mint.live.baseline.status`
- done condition: search-returned SKU consistently resolves stock endpoint with expected response shape.
- why not duplicate build evidence: parity fix inside existing suppliers module (already extracted).
- target_loop_id: `LOOP-MINT-RUNTIME-PROBE-CONSISTENCY-20260225`

### A1-04 Artwork Upload Prepare Parity Runtime Remediation
- exact files to edit:
  - `/Users/ronnyworks/code/mint-modules/artwork/src/routes/files.ts`
  - `/Users/ronnyworks/code/mint-modules/artwork/src/services/upload.ts`
  - `/Users/ronnyworks/code/mint-modules/artwork/src/__tests__/presign.test.ts`
  - `/Users/ronnyworks/code/mint-modules/artwork/API.md` (if contract wording changes)
- reason: resolves `BLOCKER-ARTWORK-UPLOAD-PREPARE` while preserving working `/api/v1/upload/presigned` path.
- tests/gates to run:
  - `cd /Users/ronnyworks/code/mint-modules && npm --prefix artwork test`
  - `./bin/ops cap run mint.runtime.proof`
  - `./bin/ops cap run mint.live.baseline.status`
- done condition: `/api/v1/files/upload/prepare` returns valid payload for accepted request body and parity is documented.
- why not duplicate build evidence: bugfix in existing artwork module, not new extraction.
- target_loop_id: `LOOP-MINT-RUNTIME-PROBE-CONSISTENCY-20260225`

### A1-05 Operator-Approved Legacy Duplicate Runtime Detach
- exact files to edit:
  - `/home/docker-host/mint-modules-prod/docker-compose.yml` (runtime stack control path)
  - `/Users/ronnyworks/code/agentic-spine/ops/bindings/docker.compose.targets.yaml`
  - `/Users/ronnyworks/code/agentic-spine/ops/bindings/services.health.yaml`
  - `/Users/ronnyworks/code/mint-modules/docs/ARCHITECTURE/MINT_TRANSITION_STATE.md`
- reason: removes split-brain risk from module-equivalent duplicate runtime on docker-host.
- tests/gates to run:
  - `./bin/ops cap run mint.deploy.status`
  - `./bin/ops cap run mint.modules.health`
  - `./bin/ops cap run mint.live.baseline.status`
  - `./bin/ops cap run loops.status`
- done condition: duplicate legacy module containers are not authoritative runtime and docs/bindings match that state.
- why not duplicate build evidence: retirement of duplicate runtime, not new build.
- target_loop_id: `LOOP-MINT-LEGACY-RUNTIME-DETACH-CLEANUP-20260225`

## Loop Mapping (First Wave Only)

| loop_id | first-wave task_ids |
|---|---|
| LOOP-MINT-RONNY-APPROVAL-STAMP-LANE-20260225 | A0-08, A1-01 |
| LOOP-MINT-RUNTIME-PROBE-CONSISTENCY-20260225 | A0-02, A0-05, A1-03, A1-04 |
| LOOP-MINT-LEGACY-RUNTIME-DETACH-CLEANUP-20260225 | A0-04, A1-05 |
| LOOP-MINT-PAYMENT-RUNTIME-READINESS-20260225 | A0-07, A1-02 |
| LOOP-MINT-SSOT-DOC-RUNTIME-ALIGNMENT-20260225 | A0-01, A0-03, A0-06 |

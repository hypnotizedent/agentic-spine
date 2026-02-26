---
status: working
owner: "@ronny"
created: 2026-02-25
scope: mint-autonomous-buildability
authority: ORCHESTRATOR-MINT-BUILDABILITY-TRIAGE-20260225
---

# Mint Autonomous Buildability Matrix (2026-02-25)

## Trusted Baseline (Restated)

Only this flow is currently trusted as live truth until Ronny stamps additional lanes:
1. Quote form submit
2. Ronny receives email
3. Files visible in MinIO

Anything else is `BUILT_NOT_STAMPED`, `CONTRACT_ONLY`, `LEGACY_ONLY`, or `DUPLICATE_RISK`.

## Normalized Findings Matrix

| finding_id | domain | evidence file/run key | current_state | duplicate_check (mint-modules / spine) | autonomy_level | recommended_action | target_loop_id |
|---|---|---|---|---|---|---|---|
| F-001 | boundaries | `docs/planning/MINT_CAPTURE_ONLY_LOOP_REGISTER_20260225.md` | BUILT_STAMPED | mint-modules: YES (`docs/PLANNING/MINT_ORDER_AGENT_ROADMAP_SSOT.md` trusted channel framing)<br>spine: YES (`docs/planning/MINT_CAPTURE_ONLY_LOOP_REGISTER_20260225.md`) | A0 | Publish one canonical runtime-truth statement and cross-link all Mint planning docs to it. | LOOP-MINT-SSOT-DOC-RUNTIME-ALIGNMENT-20260225 |
| F-002 | contracts | `mailroom/state/loop-scopes/LOOP-MINT-RONNY-APPROVAL-STAMP-LANE-20260225.scope.md` | BUILT_NOT_STAMPED | mint-modules: YES (`docs/ARCHITECTURE/MINT_TRANSITION_STATE.md` module table)<br>spine: YES (`mailroom/state/loop-scopes/LOOP-MINT-RONNY-APPROVAL-STAMP-LANE-20260225.scope.md`) | A1 | Build and maintain Ronny stamp matrix for built modules only; block unstamped "live" phrasing. | LOOP-MINT-RONNY-APPROVAL-STAMP-LANE-20260225 |
| F-003 | runtime cleanup | `docs/planning/MINT_CAPTURE_ONLY_LOOP_REGISTER_20260225.md` conflicting probes | DUPLICATE_RISK | mint-modules: YES (`docs/ARCHITECTURE/MINT_TRANSITION_STATE.md` runtime claims)<br>spine: YES (`ops/plugins/mint/bin/modules-health`, `ops/plugins/mint/bin/runtime-proof`, run key `CAP-20260225-181634__session.start__R1ojp7963`) | A0 | Add a single probe-consistency capture path (3 consecutive runs, same targets) and publish one truth table per module. | LOOP-MINT-RUNTIME-PROBE-CONSISTENCY-20260225 |
| F-004 | enforcement joints | `ops/plugins/mint/bin/modules-health`, `runtime-proof`, `deploy-status` | CONTRACT_ONLY | mint-modules: YES (`docs/ARCHITECTURE/MINT_TRANSITION_STATE.md` host/port truth)<br>spine: YES (`ops/bindings/ssh.targets.yaml`, `ops/bindings/docker.compose.targets.yaml`) | A0 | Introduce a shared `mint.probe.targets` binding and refactor probe scripts to consume it. | LOOP-MINT-RUNTIME-PROBE-CONSISTENCY-20260225 |
| F-005 | runtime cleanup | `docs/ARCHITECTURE/MINT_TRANSITION_STATE.md` (legacy duplicate stack) | DUPLICATE_RISK | mint-modules: YES (`docs/ARCHITECTURE/MINT_TRANSITION_STATE.md` legacy runtime section)<br>spine: YES (`ops/bindings/docker.compose.targets.yaml` `docker-host` -> `mint-modules-prod`) | A1 | Operator-approved detach/retire duplicate legacy module runtime paths; keep receipt-backed rollback path. | LOOP-MINT-LEGACY-RUNTIME-DETACH-CLEANUP-20260225 |
| F-006 | boundary/no-legacy | `ops/bindings/services.health.yaml` + `ops/bindings/docker.compose.targets.yaml` | DUPLICATE_RISK | mint-modules: YES (`docs/ARCHITECTURE/MINT_TRANSITION_STATE.md` legacy hold notes)<br>spine: YES (`ops/bindings/services.health.yaml` legacy probes disabled, compose target still present) | A0 | Align compose/binding language to mark docker-host module-equivalent stack as non-authoritative legacy hold only. | LOOP-MINT-LEGACY-RUNTIME-DETACH-CLEANUP-20260225 |
| F-007 | payment readiness | `docs/ARCHITECTURE/MINT_TRANSITION_STATE.md` payment row, `docs/PLANNING/MINT_ORDER_AGENT_ROADMAP_SSOT.md` phase 1 remaining work | BUILT_NOT_STAMPED | mint-modules: YES (`payment/`, payment runtime notes in planning docs)<br>spine: YES (`ops/plugins/mint/bin/runtime-proof` payment env/health checks) | A1 | Provision payment env on mint-apps, deploy payment lane, run safe smoke checks, then classify `NOT_LIVE` or `READY_FOR_RONNY_STAMP`. | LOOP-MINT-PAYMENT-RUNTIME-READINESS-20260225 |
| F-008 | contracts | `docs/PLANNING/MINT_ORDER_AGENT_ROADMAP_SSOT.md` disconnect 1 + bridge section | CONTRACT_ONLY | mint-modules: YES (`docs/CANONICAL/MINT_PAYMENT_ORDER_BRIDGE_CONTRACT_V1.md` referenced by queue/roadmap)<br>spine: YES (`ops/agents/mint-agent.contract.md` current scope excludes new bridge features) | A3 | Defer payment->finance bridge implementation until explicit approval; keep as contract artifact only. | LOOP-MINT-PAYMENT-RUNTIME-READINESS-20260225 |
| F-009 | boundaries | `ops/bindings/mint.module.sequence.contract.yaml` + D225 gate script | CONTRACT_ONLY | mint-modules: YES (`docs/PLANNING/MINT_MODULE_EXECUTION_QUEUE.md` `BLOCKED_BY_D225` marker)<br>spine: YES (`surfaces/verify/d225-mint-live-before-auth-lock.sh`) | A3 | Keep auth extraction deferred; only maintain guardrail evidence and queue markers. | LOOP-MINT-SSOT-DOC-RUNTIME-ALIGNMENT-20260225 |
| F-010 | runtime cleanup | `docs/PLANNING/MINT_MODULE_EXECUTION_QUEUE.md` (`BLOCKER-SUPPLIERS-STOCK-PARITY`) | BUILT_NOT_STAMPED | mint-modules: YES (`suppliers/` module + queue blocker)<br>spine: YES (`ops/plugins/mint/bin/runtime-proof` suppliers search/stock checks) | A1 | Fix suppliers stock parity in module code if probe mismatch persists; validate with runtime-proof and baseline status. | LOOP-MINT-RUNTIME-PROBE-CONSISTENCY-20260225 |
| F-011 | runtime cleanup | `docs/PLANNING/MINT_MODULE_EXECUTION_QUEUE.md` (`BLOCKER-ARTWORK-UPLOAD-PREPARE`) | BUILT_NOT_STAMPED | mint-modules: YES (`artwork/` module + queue blocker)<br>spine: YES (`ops/plugins/mint/bin/runtime-proof` artwork upload/prepare check) | A1 | Restore/verify upload prepare parity without breaking `/upload/presigned`; re-run proofs. | LOOP-MINT-RUNTIME-PROBE-CONSISTENCY-20260225 |
| F-012 | doc cleanup | `docs/ARCHITECTURE/MINT_TRANSITION_STATE.md` vs `docs/planning/MINT_CAPTURE_ONLY_LOOP_REGISTER_20260225.md` | DUPLICATE_RISK | mint-modules: YES (`MINT_TRANSITION_STATE.md`, roadmap, queue docs)<br>spine: YES (capture register + loop scopes) | A0 | Normalize wording to one status taxonomy (`APPROVED_BY_RONNY`, `BUILT_NOT_STAMPED`, `NOT_BUILT`). | LOOP-MINT-SSOT-DOC-RUNTIME-ALIGNMENT-20260225 |
| F-013 | regression gates | Missing explicit lock for stamp-required live language in Mint docs | CONTRACT_ONLY | mint-modules: YES (runtime/planning docs contain live wording)<br>spine: YES (gate registry currently ends at D225 for Mint lane) | A0 | Add new verify lock to fail if Mint docs claim live/verified without run key + Ronny stamp evidence block. | LOOP-MINT-SSOT-DOC-RUNTIME-ALIGNMENT-20260225 |
| F-014 | boundary/no-legacy | `/Users/ronnyworks/ronny-ops` remains legacy source candidate only (policy) | CONTRACT_ONLY | mint-modules: YES (execution queue points to legacy extraction evidence only)<br>spine: YES (AGENTS runtime policy + loop scopes require no legacy authority conflation) | A0 | Add explicit no-legacy-authority clause in Mint docs and boundary gate checks. | LOOP-MINT-LEGACY-RUNTIME-DETACH-CLEANUP-20260225 |
| F-015 | duplicate prevention | `docs/PLANNING/MINT_MODULE_EXECUTION_QUEUE.md` (`REJECTED_DUPLICATE` 23 endpoints/7 domains) | DUPLICATE_RISK | mint-modules: YES (`MINT_MODULE_EXECUTION_QUEUE.md` fully covered domains table)<br>spine: YES (`ops/plugins/mint/bin/deploy-sync-from-main` single-module deploy guard) | A0 | Add queue-driven anti-duplicate checklist to first-wave task specs and verify notes. | LOOP-MINT-SSOT-DOC-RUNTIME-ALIGNMENT-20260225 |
| F-016 | coordination | Run keys: `CAP-20260225-181658__loops.status__Rchrd15249`, `CAP-20260225-181703__gaps.status__Rvkk715513`, `./bin/ops status` anomaly list | DUPLICATE_RISK | mint-modules: NO direct runtime artifact<br>spine: YES (`loops.status`, `gaps.status`, unlinked gaps/anomalies) | A2 | Manual control-plane cleanup for unlinked gaps to reduce planning churn; do not open new Mint loops unless ownership gap is proven. | LOOP-MINT-SSOT-DOC-RUNTIME-ALIGNMENT-20260225 |

## Autonomy Legend

- `A0`: autonomous now (no secrets/routing/operator mutation)
- `A1`: autonomous with operator-provided env/approval
- `A2`: manual-only
- `A3`: defer

## Capture-Lane Verification Evidence (Post-Artifact)

- `CAP-20260225-183139__mint.modules.health__Rp4ak51777` -> `status: OK (all components healthy)`
- `CAP-20260225-183201__mint.live.baseline.status__R5zhy57019` -> `status: OK (baseline green)`
- `CAP-20260225-183242__verify.pack.run__Rv1w869349` -> `pass=11 fail=0`
- `CAP-20260225-183318__verify.core.run__R819u80994` -> `FAILED (D63: communications.send.execute missing requires secrets.binding + secrets.auth.status)`
- `CAP-20260225-183326__loops.status__Rpx6o82298` -> `Open loops: 9`
- `CAP-20260225-183329__gaps.status__Rt5z382794` -> `Open gaps: 17 (5 standalone)`

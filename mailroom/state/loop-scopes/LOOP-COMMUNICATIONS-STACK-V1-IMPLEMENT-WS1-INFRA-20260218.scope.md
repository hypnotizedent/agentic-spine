---
loop_id: LOOP-COMMUNICATIONS-STACK-V1-IMPLEMENT-WS1-INFRA-20260218
created: 2026-02-18
status: closed
owner: "@ronny"
scope: communications
priority: high
objective: Execute WS1 infrastructure foundation for Communications Stack V1 (Stalwart lane) with dry-run-first provisioning and canonical spine wiring.
---

# Loop Scope: LOOP-COMMUNICATIONS-STACK-V1-IMPLEMENT-WS1-INFRA-20260218

## Objective

Execute WS1 infrastructure foundation for Communications Stack V1 (Stalwart lane) with dry-run-first provisioning and canonical spine wiring.

## Parent Gap

- GAP-OP-665

## Scope

- Add canonical communications domain wiring in spine bindings.
- Introduce pilot-safe communications capability surfaces (read-first, mutating send-test behind manual approval).
- Add infra dry-run path for `communications-stack` target (no production mutation in WS1).
- Produce execution receipts and close gap/loop when WS1 acceptance passes.

## Out Of Scope

- Production VM provisioning/bootstrapping (non-dry-run).
- Mail migration from existing providers.
- DNS cutover and DMARC enforcement beyond pilot defaults.

## Execution Pack

1. Baseline and route:
   - `./bin/ops status`
   - `./bin/ops cap run stability.control.snapshot`
   - `./bin/ops cap run verify.route.recommend`
2. Communications bindings + plugin surfaces:
   - Add/extend communications contracts in `ops/bindings/`.
   - Add scripts in `ops/plugins/communications/bin/` for:
     - `communications.stack.status`
     - `communications.mailboxes.list`
     - `communications.mail.search`
     - `communications.mail.send.test` (manual approval)
   - Register capabilities in `ops/capabilities.yaml` and `ops/bindings/capability_map.yaml`.
3. Domain wiring:
   - Update `ops/bindings/gate.execution.topology.yaml`
   - Update `ops/bindings/gate.domain.profiles.yaml`
   - Update `ops/bindings/docs.impact.contract.yaml`
   - Update `ops/bindings/capability.domain.catalog.yaml`
4. Infra dry-run certification:
   - `./bin/ops cap run infra.vm.provision --target communications-stack --profile spine-ready-v1 --vm-id 214 --dry-run`
   - `./bin/ops cap run infra.vm.bootstrap --target communications-stack --profile spine-ready-v1 --vm-id 214 --dry-run`
5. Verification:
   - `./bin/ops cap run verify.core.run`
   - `./bin/ops cap run verify.domain.run aof --force`
   - `./bin/ops cap run verify.pack.run loop_gap`
6. Lifecycle close:
   - `echo "yes" | ./bin/ops cap run gaps.close --id GAP-OP-665 --status fixed --fixed-in "<run-keys>"`
   - `./bin/ops loops close LOOP-COMMUNICATIONS-STACK-V1-IMPLEMENT-WS1-INFRA-20260218`

## Acceptance

- Communications capability surfaces are registered and executable with expected safety/approval modes.
- Domain/binding parity checks pass (including capability map, docs impact routes, and topology/profile updates).
- Infra dry-run commands succeed with receipts.
- Gap and loop close with receipt-linked evidence.

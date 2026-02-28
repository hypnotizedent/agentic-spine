# W57_RECEIPT_CLOSEOUT_CANONICALIZATION_MASTER_RECEIPT_20260227

- decision: COMPLETE
- scope: contract/gate normalization only (no runtime/infra mutation)
- objective: eliminate receipt crumbs and enforce atomic closeout before lifecycle delete

## Implemented Controls

1. New gate: `D274 receipt-closeout-completeness-lock`
   - script: `surfaces/verify/d274-receipt-closeout-completeness-lock.sh`
   - behavior: fails on untracked planning receipt crumbs matching governed pattern

2. New atomic capability: `wave.closeout.finalize`
   - script: `ops/plugins/ops/bin/wave-closeout-finalize`
   - behavior:
     - validates run-key presence in supplied receipts
     - stages expected receipts only
     - enforces D274 prior to commit
     - commits and push-parity checks remotes

3. Cleanup delete hard prechecks (`worktree.lifecycle.cleanup`)
   - script: `ops/plugins/ops/bin/worktree-lifecycle-cleanup`
   - enforced before delete:
     - D274 pass required (contract-driven)
     - candidate worktree `git status` clean required
   - classifier now records `worktree_clean` and blocks dirty candidates with reason `dirty_worktree`

4. Canonical closeout contract
   - file: `ops/bindings/wave.closeout.contract.yaml`
   - governs:
     - run key regex + minimum count per receipt
     - crumb detection regex
     - delete precheck toggles
     - finalize defaults (remotes, gate hook, index cleanliness)

## Governance Wiring Updated

- `ops/bindings/gate.registry.yaml` (D274 added; gate counts advanced)
- `ops/bindings/gate.execution.topology.yaml` (D274 assignment + core path triggers)
- `ops/bindings/gate.agent.profiles.yaml` (core-operator includes D274)
- `ops/bindings/gate.domain.profiles.yaml` (core profile includes D274 and new triggers)
- `ops/capabilities.yaml` (`wave.closeout.finalize`)
- `ops/bindings/capability_map.yaml` (`wave.closeout.finalize`)
- `ops/bindings/routing.dispatch.yaml` (`wave.closeout.finalize`)
- `ops/plugins/MANIFEST.yaml` (ops plugin script/capability inventory)
- `docs/planning/W55_WORKTREE_LIFECYCLE_RUNBOOK_V1.md` (closeout checkpoint + D274)

## Verification Evidence

- `gate.topology.validate`: `CAP-20260227-192038__gate.topology.validate__Rjdy427119` PASS
- `verify.pack.run secrets`: `CAP-20260227-192047__verify.pack.run__Rxszz30848` PASS
- `verify.pack.run core`: `CAP-20260227-192047__verify.pack.run__Rtw6430847` FAIL (pre-existing D163 baseline unrelated to W57 scope)
- direct gates:
  - `D264` PASS
  - `D265` PASS
  - `D266` PASS
  - `D267` PASS
  - `D274` PASS (report + enforce)

## Attestation

- No protected runtime lane mutation.
- No VM/infra changes.
- This wave only updated contracts/gates/capability wiring and runbooks.

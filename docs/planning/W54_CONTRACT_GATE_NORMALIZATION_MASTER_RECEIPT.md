# W54_CONTRACT_GATE_NORMALIZATION_MASTER_RECEIPT

- branch: `codex/w54-contract-normalization-20260227`
- base/head: `47756c1` -> pending commit in this wave
- scope: contract/gate normalization only (no VM/infra/runtime mutation)
- final decision: `MERGE_READY_WITH_BASELINE_EXCEPTION`

## Wave Goal

Normalize governance contract targets and gate behavior so ambient drift no longer blocks scope cleanup waves, and prevent `_audits` write-target regressions.

## Implemented

1. `_audits` write-target normalization to receipts path:
   - moved report outputs/defaults from `docs/governance/_audits` to `receipts/audits/governance` in:
     - `ops/plugins/verify/bin/calendar-surface-audit`
     - `ops/plugins/verify/bin/surface-audit-full`
     - `ops/plugins/surface/bin/surface-boundary-reconcile-plan`
     - `ops/plugins/slo/bin/slo-evidence-daily`
     - `ops/plugins/verify/bin/schema-conventions-audit`
   - aligned contracts/docs/metadata:
     - `ops/bindings/spine.schema.conventions.yaml`
     - `ops/bindings/spine.boundary.baseline.yaml`
     - `ops/bindings/mailroom.runtime.contract.yaml`
     - `docs/governance/SPINE_SCHEMA_CONVENTIONS.md`
     - `ops/capabilities.yaml`
     - `ops/bindings/capability_map.yaml`
     - `ops/bindings/routing.dispatch.yaml`
     - `ops/bindings/gate.registry.yaml` (D150 description)
     - `surfaces/verify/d150-code-root-hygiene-lock.sh`

2. New gate `D263` (governance audit write-target lock):
   - added: `surfaces/verify/d263-governance-audits-write-target-lock.sh`
   - wired to contracts/profiles/topology:
     - `ops/bindings/gate.registry.yaml`
     - `ops/bindings/gate.execution.topology.yaml`
     - `ops/bindings/gate.domain.profiles.yaml`
     - `ops/bindings/gate.agent.profiles.yaml`
   - gate uses script-root resolution to avoid `SPINE_ROOT` cross-worktree bleed.

3. Scope-clean preflight + ambient drift ledger:
   - new contract: `ops/bindings/orchestration.preflight.scope.contract.yaml`
   - `ops/commands/wave.sh` now:
     - enforces `scope_clean_required`
     - keeps ambient drift non-blocking/report-only
     - emits ambient drift ledger markdown to configured runtime path
   - aligned descriptors:
     - `ops/bindings/wave.lifecycle.yaml`
     - `ops/capabilities.yaml`
     - `ops/bindings/capability_map.yaml`
     - `ops/bindings/routing.dispatch.yaml`

4. Explicit `.spine-link` policy contract:
   - new policy: `ops/bindings/project.attach.link.policy.yaml`
   - policy-consumer updates:
     - `bin/generators/gen-project-attach.sh`
     - `surfaces/verify/d153-project-attach-parity.sh`
     - `ops/bindings/workbench.ssh.attach.contract.yaml`

5. Ownership registry updates:
   - `ops/bindings/registry.ownership.yaml` updated with new W54 binding files.

## Validation

- `session.start` PASS:
  - `CAP-20260227-154904__session.start__Rze4f13705`
- `D263` enforce script PASS:
  - direct: `./surfaces/verify/d263-governance-audits-write-target-lock.sh --policy enforce`
- `gate.topology.validate` PASS:
  - `CAP-20260227-154915__gate.topology.validate__Rihr216594`
- `verify.pack.run core`:
  - `CAP-20260227-154922__verify.pack.run__Re1wo17207`
  - result: `14 pass / 1 fail`
  - fail: `D153` (`media-agent` missing `spine_link_version`), unchanged vs `origin/main`
- `orchestration.preflight.fast` (scope contract proof):
  - pass execution with scope/ambient reporting: `CAP-20260227-154945__orchestration.preflight.fast__Rhdxe19760`
  - expected `no-go` on this in-progress branch due scope dirty count before commit (`26 > 10`)

## Baseline Exception

- `D153` remains a pre-existing baseline issue on current lineage (`ops/bindings/workbench.project.attach.yaml` unchanged in this wave).
- W54 did not introduce new D153 regressions.

## Files Changed (W54)

- `bin/generators/gen-project-attach.sh`
- `docs/governance/SPINE_SCHEMA_CONVENTIONS.md`
- `ops/bindings/capability_map.yaml`
- `ops/bindings/gate.agent.profiles.yaml`
- `ops/bindings/gate.domain.profiles.yaml`
- `ops/bindings/gate.execution.topology.yaml`
- `ops/bindings/gate.registry.yaml`
- `ops/bindings/mailroom.runtime.contract.yaml`
- `ops/bindings/orchestration.preflight.scope.contract.yaml` (new)
- `ops/bindings/project.attach.link.policy.yaml` (new)
- `ops/bindings/registry.ownership.yaml`
- `ops/bindings/routing.dispatch.yaml`
- `ops/bindings/spine.boundary.baseline.yaml`
- `ops/bindings/spine.schema.conventions.yaml`
- `ops/bindings/wave.lifecycle.yaml`
- `ops/bindings/workbench.ssh.attach.contract.yaml`
- `ops/capabilities.yaml`
- `ops/commands/wave.sh`
- `ops/plugins/slo/bin/slo-evidence-daily`
- `ops/plugins/surface/bin/surface-boundary-reconcile-plan`
- `ops/plugins/verify/bin/calendar-surface-audit`
- `ops/plugins/verify/bin/schema-conventions-audit`
- `ops/plugins/verify/bin/surface-audit-full`
- `surfaces/verify/d150-code-root-hygiene-lock.sh`
- `surfaces/verify/d153-project-attach-parity.sh`
- `surfaces/verify/d263-governance-audits-write-target-lock.sh` (new)

## Attestation

- no VM mutation
- no infra mutation
- no runtime write against external systems
- contract/gate normalization + local receipts only

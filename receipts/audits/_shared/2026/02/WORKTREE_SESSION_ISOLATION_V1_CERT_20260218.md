# WORKTREE SESSION ISOLATION V1 CERT (2026-02-18)

## Scope
- Loop: `LOOP-WORKTREE-SESSION-ISOLATION-V1-20260218`
- Gap: `GAP-OP-656`
- Objective: Enforce non-main branch isolation to managed worktrees with explicit session identity.

## Implementation
- Added contract: `ops/bindings/worktree.session.isolation.yaml`
- Added status capability script: `ops/plugins/ops/bin/worktree-session-status`
- Added drift gate: `surfaces/verify/d140-worktree-session-isolation.sh`
- Wired gate + topology:
  - `ops/bindings/gate.registry.yaml` (added D140)
  - `ops/bindings/gate.execution.topology.yaml` (assigned D140 to core)
- Wired runtime entry/preflight enforcement:
  - `ops/hooks/session-entry-hook.sh`
  - `ops/commands/preflight.sh`
- Wired capability registry:
  - `ops/capabilities.yaml`
  - `ops/bindings/capability_map.yaml`
  - `ops/plugins/MANIFEST.yaml`

## Verification Evidence
- `CAP-20260217-205829__verify.core.run__R2kpj79306` -> PASS (8/8)
- `CAP-20260217-210231__verify.domain.run__Rzotu27632` -> PASS (19/19, AOF)
- `CAP-20260217-205825__worktree.session.status__R34le79097` -> PASS
- `CAP-20260217-210253__gaps.close__Rmwma34380` -> GAP-OP-656 fixed

## Notes
- D128 provenance lock required boundary advancement commit for this lane:
  - `95e0e94` updated `ops/bindings/d128-gate-mutation-policy.yaml`.

## Result
- `GAP-OP-656`: fixed
- `LOOP-WORKTREE-SESSION-ISOLATION-V1-20260218`: closed

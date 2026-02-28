# W62-B Verify Interface Canonicalization

Status: final
Wave: LOOP-SPINE-W62B-LEARNING-SYSTEM-20260228
Owner: @ronny

## Canonical Interface Decision

- Agent-facing verify command is `verify.run`.
- Supported scopes:
  - `./bin/ops cap run verify.run fast`
  - `./bin/ops cap run verify.run domain <domain>`
  - `./bin/ops cap run verify.run release`
- Legacy verify surfaces remain callable for internal orchestration only:
  - `verify.core.run`
  - `verify.domain.run`
  - `verify.pack.run`
  - `verify.pack.explain`
  - `verify.pack.list`

## Contract + Routing Updates Applied

- `ops/plugins/verify/bin/verify-topology`
  - `verify.route.recommend` now emits `verify.run` commands.
- `ops/bindings/entry.boot.surface.contract.yaml`
  - Post-work verify commands moved to `verify.run` fast/domain.
- `ops/bindings/entry.surface.contract.yaml`
  - Startup forbidden-line and post-work guidance aligned to `verify.run`.
- `AGENTS.md`
  - Post-work verify examples switched to `verify.run`.
- `CLAUDE.md`
  - Post-work verify examples switched to `verify.run`.
- `docs/governance/SESSION_PROTOCOL.md`
  - Execution matrix + verify tiers switched to `verify.run` semantics.
- `ops/bindings/verify.interface.contract.yaml`
  - Canonical agent-facing surface + internal legacy allowances codified.

## Evidence

- `docs.projection.sync`: `CAP-20260227-231913__docs.projection.sync__Rfqj81003`
- `docs.projection.verify`: `CAP-20260227-231924__docs.projection.verify__Rr3711875`
- `verify.route.recommend`: `CAP-20260227-232042__verify.route.recommend__Rhi3e4969`
  - Output recommends only `verify.run` invocations.
- `verify.run fast`: `CAP-20260227-232049__verify.run__Rdgck6081` (PASS)
- `verify.run domain communications`: `CAP-20260227-232049__verify.run__R1bg36082` (PASS)

## Enforcement Notes

- Agent documentation and entry contracts are now aligned on one entry command surface.
- Legacy verify commands are retained to preserve internal compatibility and existing automated flows.

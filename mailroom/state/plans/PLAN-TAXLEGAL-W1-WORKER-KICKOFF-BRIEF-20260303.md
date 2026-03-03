# PLAN-TAXLEGAL-W1-WORKER-KICKOFF-BRIEF-20260303

> Canonical worker kickoff brief for Tax-Legal Wave 1.
> Lane: mailroom planning (design-only).
> Authority anchor: `LOOP-TAX-LEGAL-OPS-WORKER-SPEC-20260303`.

## Containment Contract

This kickoff brief is intentionally stored in:

- `mailroom/state/plans/`

so planning artifacts, order locks, and packet dependencies remain in one governed container.

No implementation actions are authorized from this brief alone.

## Primary Artifacts

1. Program plan:
   - `mailroom/state/plans/PLAN-TAX-LEGAL-OPS-WORKER-20260303.md`
2. Order lock:
   - `mailroom/state/plans/PLAN-TAXLEGAL-W1-ORDER-LOCK-20260303.md`
3. Loop scopes:
   - `mailroom/state/loop-scopes/LOOP-TAXLEGAL-W1-BUSINESS-LIFECYCLE-PLAYBOOKS-20260303.scope.md`
   - `mailroom/state/loop-scopes/LOOP-TAXLEGAL-W1-AGENT-BOUNDARY-CONTRACTS-20260303.scope.md`
   - `mailroom/state/loop-scopes/LOOP-TAXLEGAL-W1-BINDINGS-CONTRACT-PACK-20260303.scope.md`
   - `mailroom/state/loop-scopes/LOOP-TAXLEGAL-W1-DOMAIN-ROUTING-INTEGRATION-20260303.scope.md`

## Locked Sequence

1. `LOOP-TAXLEGAL-W1-BUSINESS-LIFECYCLE-PLAYBOOKS-20260303`
2. `LOOP-TAXLEGAL-W1-AGENT-BOUNDARY-CONTRACTS-20260303`
3. `LOOP-TAXLEGAL-W1-BINDINGS-CONTRACT-PACK-20260303`
4. `LOOP-TAXLEGAL-W1-DOMAIN-ROUTING-INTEGRATION-20260303`

## Deferred Plan IDs (Dependency Chain)

1. `PLAN-TAXLEGAL-W1-LIFECYCLE-PLAYBOOKS`
2. `PLAN-TAXLEGAL-W1-AGENT-BOUNDARY` (depends on lifecycle loop)
3. `PLAN-TAXLEGAL-W1-BINDINGS-PACK` (depends on agent/boundary loop)
4. `PLAN-TAXLEGAL-W1-DOMAIN-ROUTING` (depends on bindings loop)

## Gap Inventory

- Lifecycle packet: `GAP-OP-1438..1443`
- Agent/boundary packet: `GAP-OP-1422..1425`
- Bindings packet: `GAP-OP-1426..1431`
- Domain routing packet: `GAP-OP-1432..1436`

## Worker Guardrails

1. Treat external AI transcript claims as hypotheses only until primary-source verification.
2. Preserve privacy as public-record minimization, not legal/federal concealment.
3. Do not implement runtime scripts/capabilities in this planning lane.
4. Close gaps with receipts before packet promotion.

## Promotion Preflight (Future Worker)

```bash
./bin/ops cap run session.start
./bin/ops cap run planning.plans.list -- --owner @ronny --horizon later
./bin/ops cap run verify.run -- fast
```

## Drift Prevention

If execution artifacts appear outside the above loop/plan/gap set, file a gap before proceeding.

## Known Friction Blocker (Captured)

Gap filing lane is currently partially blocked by schema strictness drift:

1. `ops/bindings/operational.gaps.yaml` contains unsupported key `blocked_case` (at `GAP-OP-1352`).
2. New `gaps.file` attempts can fail on `schema.conventions.audit` until this key is normalized or schema is updated.
3. Evidence of blocked filing attempt:
   - `CAP-20260303-033718__gaps.file__R399e35886`
4. Additional drift observed:
   - `planning.plans.list` intermittently reverts to baseline 5-plan index (Tax-Legal plan entries disappear from `mailroom/state/plans/index.yaml` after registration attempts).

Impact:

- Friction items may need temporary plan-level capture if `gaps.file` rejects writes.
- Tracked friction gaps:
  - `GAP-OP-1444` (`gaps.file --id auto` ID-collision/overwrite behavior)
- Planning-level friction capture pending stable gap write for kickoff-lane contract:
  - missing explicit governance contract for canonical kickoff-brief lane (`mailroom/state/plans` vs handoff surfaces)

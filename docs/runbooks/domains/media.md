# media Runbook

## Scope
Primary recovery flow for domain `media`.

## Detect
1. `./bin/ops cap run spine.log.query -- --since-hours 24 --domain media --status failed`
2. Run scoped media domain health readback: `./bin/ops cap run verify.run -- domain media`

## Diagnose
1. Review latest failing run key receipt in `~/code/.evidence/spine/sessions/`.
2. Review `ops/bindings/domains/media/media.path.authority.contract.yaml`, `ops/bindings/domains/media/media.archive.flow.policy.yaml`, and `ops/bindings/media.quality.policy.yaml` before touching any historical migration packet or profile policy.
3. Review domain contract and plugin scripts for the failing surface.
4. Confirm runtime path usage resolves through `ops/lib/spine-paths.sh`.

## Recover
1. Apply the minimal fix in the owning plugin/contract.
2. Re-run targeted media domain health readback.
3. Re-run `verify.infra.run`.

## Exit Criteria
- Media domain health readback has zero blocking failures.
- Estate verify has zero blocking failures.
- Failure cause and remediation are reflected in commit and receipt evidence.

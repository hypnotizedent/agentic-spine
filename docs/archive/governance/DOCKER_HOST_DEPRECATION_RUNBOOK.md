---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-26
scope: docker-host-safe-deprecation-execution
loop: LOOP-SPINE-GOVERNANCE-NORMALIZATION-SEQUENCE-20260226-20260226
---

# Docker-Host Deprecation Runbook

## Purpose

Run safe deprecation for docker-host (VM 200) without crossing Mint-OS runtime ownership boundaries.

Contract authority:
- `ops/bindings/docker-host.deprecation.contract.yaml`

## Scope

In scope:
- Cleanup of non-authoritative legacy fragments that are already migrated or stale.

Out of scope:
- Mint-OS runtime decommission actions (owned by Mint loops/agents).

## Normalized Action Classes

1. `safe_cleanup_now`
- Remove stale artifacts with before/after receipts.

2. `verify_first`
- Require dependency proof before deletion/disable.

3. `defer_mint_lane`
- Do not mutate in this runbook.

## Execution Sequence

1. Baseline status
```bash
./bin/ops cap run infra.docker_host.status
./bin/ops cap run services.health.run
```

2. Choose one `safe_cleanup_now` batch
- Execute one bounded batch.
- Capture before/after runtime facts in receipt.

3. Re-check queue and service impact
```bash
./bin/ops cap run communications.alerts.queue.status
./bin/ops cap run communications.alerts.queue.slo.status
```

4. Verify
```bash
./bin/ops cap run verify.route.recommend
./bin/ops cap run verify.pack.run infra
```

5. Close linked gap(s)
- `gaps.close --status fixed --fixed-in <RUN_KEY>`

## Break-Glass Only

Manual queue flush remains break-glass:

```bash
echo "yes" | ./bin/ops cap run communications.alerts.flush --limit 10
```

Preferred model is always-on dispatcher worker.

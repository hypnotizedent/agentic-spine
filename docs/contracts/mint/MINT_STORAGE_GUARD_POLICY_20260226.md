---
status: working
owner: "@ronny"
last_verified: 2026-02-26
scope: mint-storage-guard-policy
---

# Mint Storage Guard Policy (Wave 8)

## Mode

- Current policy mode: `report`
- Enforcement mode: `disabled` until promotion criteria are met.
- Runtime mutation: explicitly forbidden during report-first baseline.

Policy binding source:

- `ops/bindings/mint.storage.guard.policy.yaml`

## Severity Classes

- `critical`: data-loss or service outage risk requiring immediate operator action
- `high`: sustained boot-drive or placement drift with production impact risk
- `medium`: durability or hygiene drift that can accumulate into higher-risk state
- `low`: advisory observations

## Threshold Baseline

- Root usage warning: `>= 60%`
- Root usage fail threshold (for enforce phase): `>= 80%`
- Docker images warning: `>= 15GB`
- Docker build cache warning: `>= 10GB`
- Host tmp large-file threshold: `> 10MB`
- Container writable rootfs warning: `> 500MB`

## Report -> Enforce Promotion Rule

Promote only when all conditions are true:

1. Three consecutive report runs complete without unexpected findings on VM 212/213.
2. `STOR-001..008` mapping has no unlinked entries.
3. Operator approval is captured in a wave activation receipt.

Rollback from enforce if any `D235..D239` gate fails in `verify.pack.run mint`.

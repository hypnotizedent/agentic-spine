---
status: authoritative
owner: "@ronny"
created: 2026-02-22
last_updated: 2026-02-22
scope: mint-runtime-standard
---

# Mint Runtime Standard (2026-02-22)

## Why this exists

Mint code quality is no longer the main risk. Runtime drift is:

1. Healthy containers can still run stale stub builds.
2. Route health can pass while API behavior is wrong.
3. Docs/receipts can say "done" while VM behavior is still legacy.

This standard enforces deployment + proof gates so module work is only "done"
when live behavior matches contract.

## Canonical Deploy Path

Use Spine capability only:

```bash
cd /Users/ronnyworks/code/agentic-spine
echo "yes" | ./bin/ops cap run mint.deploy.sync --ref origin/main --modules artwork,shipping,suppliers,pricing,payment
```

What it does:

1. Syncs committed `mint-modules` source (`origin/main` by default) to VM 213.
2. Rebuilds selected services from synced code.
3. Runs:
   - `mint.deploy.status`
   - `mint.modules.health`
   - `mint.runtime.proof`

## Required Proof Gates

A module change is not complete until all gates pass:

1. `mint.deploy.status` -> stack/container state is healthy with no hidden sub-stack drift.
2. `mint.modules.health` -> all app/data plane health endpoints pass.
3. `mint.runtime.proof` -> behavioral checks pass:
   - shipping is not placeholder stub
   - suppliers search + stock parity works
   - artwork upload/prepare parity works
   - pricing + payment health pass

## Current Truth (from live checks)

- `mint.deploy.status` now includes all mint-apps sub-stacks (payment/pricing/suppliers/shipping).
  - Evidence: `CAP-20260222-051619__mint.deploy.status__R9zvx82329`
- `mint.modules.health` now probes all 8 app modules + 3 data-plane services.
  - Evidence: `CAP-20260222-051600__mint.modules.health__Rq53q79273`
- Runtime proof currently fails on real blockers (not doc drift):
  - shipping placeholder address
  - suppliers stock 404 after valid search
  - artwork upload/prepare hitting legacy `orders` relation
  - Evidence: `CAP-20260222-051600__mint.runtime.proof__Rfkhv79275`

## Stop Gates

Stop deployment wave if any condition is true:

1. `mint.runtime.proof` exit != 0.
2. `mint.modules.health` has any non-OK row for mint app/data services.
3. `mint.deploy.status` shows missing/down target stack for changed module.

## Operating Rule

No "done" claim from tests/commits/docs alone.
Only runtime-proofed behavior closes blockers.

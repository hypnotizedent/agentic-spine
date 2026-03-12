---
status: completed
owner: "@ronny"
last_verified: 2026-03-12
scope: repo-boringness-audit
source_repo: /Users/ronnyworks/code/ronny-products
---

# Ronny Products Boringness Audit

## Repo Purpose

`ronny-products` is a small parked-orchestration repo for standalone personal products.
It is not a general runtime inventory. It currently holds one live integration surface and
two intentionally non-deployed product lanes.

## Canonical Top-Level Folders

- `bin`
- `docs`
- `scripts`
- `templates`
- `cc-benefits-tracker`
- `inbox-shield`
- `vouchervault`

## Top-Level Classification

### Active

- `vouchervault`
- `bin`
- `docs`
- `scripts`
- `templates`

`vouchervault` is the only runtime-backed product surface today, and it is integration-only.

### Parked / Non-Deployed

- `cc-benefits-tracker`
- `inbox-shield`

These roots contain real code, but they are not current runtime truth. Their execution state is parked by design.

### Generated

- None at the repo top level.

### Legacy

- None currently.

### Dead

- None currently.

## What Should Move

- Nothing needs to move immediately. The top-level tree is already small and legible.

## What Should Collapse

- Nothing structural. The repo works as a small orchestration/product lane repo as long as app contracts stay aligned with the execution board.

## What Should Tombstone

- Nothing at this time.

## Is The Repo Boring Enough Now?

Yes.

## Why?

- One purpose: parked product orchestration plus product code/configs.
- One live runtime story: `vouchervault`.
- Two intentionally non-runtime lanes: `cc-benefits-tracker` and `inbox-shield`.
- Repo-local README and execution board already make the activation order and parking model explicit.
- This wave removed the worst ambiguity by aligning parked product contracts away from `status: active`.

## Honest Close

`ronny-products` is now boring enough. It is small, explicit, and does not pretend that parked product code is already live runtime.

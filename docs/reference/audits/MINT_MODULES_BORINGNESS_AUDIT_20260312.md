---
status: completed
owner: "@ronny"
last_verified: 2026-03-12
scope: repo-boringness-audit
source_repo: /Users/ronnyworks/code/mint-modules
---

# Mint Modules Boringness Audit

## Repo Purpose

`mint-modules` is the Mint Prints implementation repo. It is not a pure runtime-only repo:
it contains active runtime modules, future module code, blocked module code, deferred module
code, and support/tooling surfaces under one tree.

Canonical lifecycle authority is not local README text. It is
`/Users/ronnyworks/code/agentic-spine/ops/bindings/mint.module.lifecycle.authority.yaml`.

## Canonical Top-Level Folders

These roots are canonical now:

- `artwork`
- `auth`
- `finance-adapter`
- `order-intake`
- `payment`
- `pricing`
- `public-ingress`
- `quote-page`
- `shipping`
- `suppliers`
- `agents`
- `bin`
- `docs`
- `packages`
- `scripts`
- `templates`
- `tools`

## Top-Level Classification

### Active

- Runtime-active module roots: `artwork`, `auth`, `finance-adapter`, `order-intake`, `payment`, `pricing`, `public-ingress`, `quote-page`, `shipping`, `suppliers`
- Support/tooling roots: `agents`, `bin`, `docs`, `packages`, `scripts`, `templates`, `tools`

### Generated

- `*/dist`
- `*/node_modules`
- `agents/mcp-server/build`

These are build/install residue, not authority.

### Future Horizon

- `customer-portal`
- `digital-proofs`
- `shopify-module`

These roots have code presence, but they are not current runtime truth.

### Blocked On Order Truth

- `orders`
- `production`
- `quotes`

These roots are not deploy-now surfaces. They depend on canonical order/production truth
that does not yet exist as a stable boring runtime lane.

### Deferred

- `customers`
- `notifications`
- `reporting`

These capabilities are either covered elsewhere or intentionally not in the current runtime plan.

### Compatibility Hold

- `deploy`

This is an operator wrapper/promotion surface. It is not the canonical definition of runtime truth.

### Dead

- None explicitly tombstoned at the top level yet.

## What Should Move

- Nothing must move for runtime truth right now. Physical separation of future, blocked, and deferred roots is optional cleanup, not a runtime blocker.
- The required minimum was explicit root-local lifecycle markers plus runtime-surface enforcement, and that now exists.

## What Should Collapse

- Keep `deploy/` as an operator-wrapper compatibility lane only. It no longer defines production runtime membership.
- Keep the repo-local lifecycle registry and root-local `lifecycle_state` markers aligned to spine authority.

## What Should Tombstone

- Nothing must be tombstoned immediately.

## Is The Repo Boring Enough Now?

Yes.

## Why Exactly?

- Every module root now carries an explicit `lifecycle_state` marker in `module.contract.yaml`.
- `docs/CANONICAL/MINT_MODULE_LIFECYCLE_REGISTRY_V1.yaml` now matches spine authority for runtime-active, future-horizon, blocked, and deferred roots.
- `deploy/docker-compose.prod.yml` now contains only the runtime-active production service set.
- Promotion, rollback, `mintctl doctor`, `mintctl matrix`, CI inventory checks, and lifecycle guards now derive from the same lifecycle register instead of the stale ten-module list.
- `docs/ARCHITECTURE/MINT_TRANSITION_STATE.md` no longer overclaims `shopify-module` or `digital-proofs` as deployed runtime.

## Honest Close

`mint-modules` is now boring enough on lifecycle/runtime truth. Remaining cleanup is repo hygiene, not runtime classification rescue.

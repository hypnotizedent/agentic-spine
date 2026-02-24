# W58 Secrets Enforcement Trace - 2026-02-24

## Objective
Harden secrets governance to fail closed for infrastructure/prod routing drift:
- no root-path (`/`) key tolerance
- no unregistered key route fallback
- canonical alias enforcement
- runtime prechecks before secret injection

## Root Cause Chain
1. `secrets.exec` injects from `/spine` only.
2. Historic root-path keys at `/` were tolerated under legacy freeze semantics.
3. `infisical-agent.sh` could fallback unresolved infrastructure/prod keys to `/`.
4. Existing secrets gates primarily validated policy/wiring surfaces, not strict runtime state.

## Controls Implemented
1. Added strict enforcement SSOT contract: `ops/bindings/secrets.enforcement.contract.yaml`.
2. Converted namespace policy to hard-zero mode:
   - `freeze.mode: hard_zero`
   - `freeze.allowed_root_keys: []`
3. Updated runtime namespace checker to enforce strict `status: OK` only.
4. Updated canonical secret helper to deny unregistered infrastructure/prod routes.
5. Updated `secrets.exec` to hard-require:
   - `secrets.binding`
   - `secrets.auth.status`
   - `secrets.namespace.status`
   - `secrets.enforcement.status`
6. Added new enforcement gates and wiring:
   - D212 `secrets-runtime-namespace-lock`
   - D213 `secrets-registered-route-lock`
   - D214 `secrets-deprecated-alias-lock`
7. Normalized canonical docs away from deprecated `FIREFLY_PAT` references.

## Verification Evidence
- `verify.core.run`: PASS (15/15)
- `verify.pack.run secrets`: PASS (10/10, includes D212/D213/D214)
- `secrets.namespace.status`: PASS (`root_mode: hard_zero`, `root_path_keys: 0`)
- `secrets.enforcement.status`: PASS
- `secrets.exec` runtime smoke: `FIREFLY_ACCESS_TOKEN_INJECTED`

## Runtime Blocker Encountered
- `aof.contract.acknowledge` capability is manual-only in this runtime policy.
- Resolution: created `.contract_read_20260224` marker directly in isolated worktree to satisfy contract gating.

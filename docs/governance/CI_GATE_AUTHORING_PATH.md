# CI Gate Authoring Path

> **Status:** authoritative pointer
> **Scope:** decision guide for repo authors choosing a CI substrate profile
> **Last updated:** 2026-05-04 (PACKET-1175)
> **Source of truth (taxonomy):** [`ops/bindings/cross-repo.authority.yaml`](../../ops/bindings/cross-repo.authority.yaml) under `ci_gate_substrate_profiles:`

This is a navigational doc, not new authority. The canonical taxonomy is in
`cross-repo.authority.yaml`. Read this doc **before** authoring any
`.gitea/workflows/*.yml` for a new repo, before tightening branch protection,
or before copying `spine-verify` into a new place.

## Decision rule (one question)

> **What is the repo's `repo_class` in `cross-repo.authority.yaml` `repos:`?**

| `repo_class` | CI substrate profile | What CI may assume |
|---|---|---|
| `L1_control_plane` (e.g. `agentic-spine`) | `heavy_estate` | substrate-aware runner: SSH key for pve, `/md1400` NFS mount, Tailscale, canonical SQLite at `$SPINE_STATE`, Infisical creds, `cap.sh` routing to `db_authority` |
| `L2_shared_operational_rails` (e.g. `workbench`) | `heavy_estate` | same as L1 |
| `product_home` (e.g. `mint-modules`) | `thin_vanilla` | `GITHUB_WORKSPACE` only; internet-routable git clone (Gitea via Tailscale IP); apt-installable toolchain; **no estate substrate** |
| `L3_project_body` (e.g. `~/code/projects/<id>`) | `thin_vanilla` | same as `product_home` |
| `legacy_decomposed_product_scaffold` (e.g. `ronny-products`) | `thin_vanilla` | same as `product_home` |

If your repo isn't in `cross-repo.authority.yaml.repos:`, add it there first
(repo class declaration is the prerequisite, not an afterthought).

## What `thin_vanilla` authors must NOT copy

The spine repo's `.gitea/workflows/spine-verify.yml` is the `heavy_estate`
gate. It calls `./bin/ops cap run verify.engine.run`, which carries
`state_authority: shared_authority_db` and routes to pve. **Copying it into
a product repo bricks that repo's CI on a vanilla Gitea Actions runner.**
That brick was traced in PACKET-1145 (`action_run #1765`: `cap.sh:
db_authority routing failed via all declared routes`).

`thin_vanilla` repos must use:
- repo-local build/test/typecheck/lint (`npm test`, `npx tsc`, `pytest`,
  `cargo test`, etc.) directly in the workflow, **OR**
- a thin sibling cap modeled on `verify.engine.smoke.local` (added in
  PACKET-1165 at `ops/plugins/core/verify/bin/verify-engine-smoke-local`)
  that declares `routing.db_authority: skip` and operates only on
  workspace-local files.

`thin_vanilla` workflows **MUST NOT** depend on:
- SSH keys to estate hosts (pve, dev-tools, etc.)
- `/md1400` NFS mount or any spine-state mount
- Tailscale attachment for spine internals
- Infisical credentials
- `shared_authority_db` routing
- `./bin/ops cap run` invocations against caps that declare
  `state_authority: shared_authority_db`

These constraints are enforced at the cap-dispatch layer
(`ci_gate_substrate_profile_rules.rule_4` in `cross-repo.authority.yaml`).
A thin gate that quietly imports a heavy cap will route to pve and fail
the same way `spine-verify` fails on vanilla.

## Authoring checklist

When you add or modify a CI workflow, walk this list:

1. **Classify**: confirm the repo's `repo_class` and `ci_gate_substrate_profile`
   in `cross-repo.authority.yaml`. If absent, add the row first.
2. **Declare**: add a header comment block to the workflow file naming the
   profile. See `mint-modules/.gitea/workflows/ci.yaml` (lines 1-19) for the
   reference shape.
3. **Document**: add (or update) a "CI Substrate Profile" section in the
   repo's canonical authority doc. See `mint-modules/docs/CANONICAL/
   ACTIVE_AUTHORITY.md` "## CI Substrate Profile" for the reference shape.
4. **Verify substrate-fit**: read the `forbidden_substrate` list for the
   profile in `cross-repo.authority.yaml`. The workflow must not introduce
   any of those.
5. **Avoid the universal gate**: do not write a single workflow that tries
   to satisfy both profiles. The split is intentional; collapsing it
   violates the brief that established `cross-repo.authority.yaml`
   `ci_gate_substrate_profile_rules.rule_6`.
6. **Branch protection**: tightening `required_approvals`, `signed_commits`,
   or `status_check_contexts` is a separate decision, downstream of this
   doc. Do not tighten until the workflow being referenced actually passes
   on its declared runner class.

## Worked examples

- **Spine itself (`agentic-spine`)** — `heavy_estate`. CI gate is the heavy
  `spine-verify` workflow consuming `verify.engine.run`. The substrate
  brick that PACKET-1145 surfaced is acknowledged in
  `node.role.contract.yaml.agent_boundary_proof.accepted_residuals
  .branch_protection_permissive`. A substrate-aware runner image is the
  named (deferred) primitive that would close the brick. **Do not** swap
  the spine gate to `thin_vanilla`; spine-class repos consume estate
  truth by design.

- **Mint product (`mint-modules`)** — `thin_vanilla`. CI gate is the
  product-local `.gitea/workflows/ci.yaml` running per-module
  `npm ci`/`tsc --noEmit`/`vitest run`/guard scripts. The repo's
  `docs/CANONICAL/ACTIVE_AUTHORITY.md` "## CI Substrate Profile" section
  declares the classification. Image build/push lives in CI; **deploy
  lives in `mintctl deploy promote`**, not in CI.

## When in doubt

- Read `cross-repo.authority.yaml` `ci_gate_substrate_profiles:` for the
  precise substrate constraints.
- Read `cross-repo.authority.yaml` `ci_gate_substrate_profile_rules:` for
  the six rules every author must honor.
- If a check genuinely needs estate substrate AND the repo is product-class,
  the right answer is **not** to import that check into the product
  workflow. The right answer is to keep that check in spine and have
  spine-side observability surface its results — **not** to widen the
  product's CI substrate.

## What this doc deliberately does NOT do

- Does not duplicate the taxonomy in `cross-repo.authority.yaml`
  (single source of truth).
- Does not specify branch-protection settings (separate concern).
- Does not specify deploy/promotion behavior (separate concern, owned by
  each repo's deploy contract; `mint-modules/docs/DEPLOYMENT/
  MINT_MODULES_DEPLOY_CONTRACT.md` is the reference).
- Does not invent a new authority surface or control plane.

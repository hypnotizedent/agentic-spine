# secrets

Canonical domain policy for `secrets`.

- Authority: `docs/governance/SPINE.md`
- Runtime contracts: `ops/bindings/domains/secrets.bundle.yaml`
- Scoped domain health readback: `./bin/ops cap run verify.run -- domain secrets`
- Provider SSOT: `ops/bindings/secrets.binding.yaml` (Infisical,
  `infrastructure/prod`, base path `/spine`)
- Routing authority: `ops/bindings/secrets.namespace.policy.yaml`
- Enforcement authority: `ops/bindings/secrets.enforcement.contract.yaml`

The secrets concern is an L2 shared infrastructure rail. Its live capability
surface is therefore mostly `plane: fabric`, not `plane: domain_external`.
The generated catalog below only reports domain-external capabilities; the
first-class L2 fabric readbacks are:

- `secrets.status` — local plumbing/config presence, no values
- `secrets.binding` — non-secret provider binding
- `secrets.auth.status` / `secrets.auth.load` / `secrets.cli.status` — auth
  presence and shim posture, no values
- `secrets.inventory.status` / `secrets.projects.status` — SSOT and live
  project parity, names/counts only
- `secrets.namespace.status` / `secrets.enforcement.status` — namespace and
  strict routing posture
- `secrets.credentials.parity` — Infisical credential-file shape and
  reachability parity, no values
- `secrets.runway.status` — container/domain secret normalization audit, no
  values
- `secret.reference.status` / `token.custody.status` — registered key names,
  custody classes, and canonical paths only
- `secrets.tier1.writeproof.status` — live-safe writeproof probes; this surface
  does not print values, but it can perform bounded provider create/delete or
  equivalent no-op write checks for integrations declared `proof_mode:
  live_safe` in `ops/bindings/secrets.tier1.writeproof.contract.yaml`

<!-- DOMAIN_CAPABILITY_CATALOG_START -->
## Capability Catalog
Generated from `ops/capabilities.yaml` by `catalog-domain-sync`.

_No domain-external capabilities currently map to `secrets`._
<!-- DOMAIN_CAPABILITY_CATALOG_END -->

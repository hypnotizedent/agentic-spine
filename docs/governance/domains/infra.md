# infra

Canonical domain policy for `infra`.

- Authority: `docs/governance/SPINE.md`
- Runtime contracts: `ops/bindings/domains/infra.bundle.yaml`
- Verify entrypoint: `./bin/ops cap run verify.run -- domain infra`

## Governed Capability Membership

- Total governed capabilities with `domain: infra`: `107`
- All `107` are `plane: fabric` capabilities
- The catalog view remains empty because it lists only `domain_external` capabilities
- `infra` governs the live mailroom operational transport slice:
  - `mailroom.bridge.*`
  - `mailroom.task.*`
  - `mailroom.runtime.*`
  - existing `mailroom.log.rotate`
- The existing split remains intentional:
  - `mailroom.scan` stays `domain: loop_gap`
  - `mailroom.outbox.retention` stays `domain: loop_gap`

<!-- DOMAIN_CAPABILITY_CATALOG_START -->
## Capability Catalog
Generated from `ops/capabilities.yaml` by `catalog-domain-sync`.

_No domain-external capabilities currently map to `infra`._
<!-- DOMAIN_CAPABILITY_CATALOG_END -->

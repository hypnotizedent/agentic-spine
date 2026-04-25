# communications

Canonical domain policy for `communications`.

- Authority: `docs/governance/SPINE.md`
- **Canonical home:** `workbench/agents/communications/`
- **Spine mode:** projection (spine holds engine registrations and thin shims; product truth lives in workbench)
- Runtime contracts: `ops/bindings/domains/communications.bundle.yaml`
- Verify entrypoint: `./bin/ops cap run verify.run -- domain communications`

## Canonical Home Decision

Decided 2026-04-25 (Packet 3: CANONICAL-HOME-MATRIX).

Communications product truth (compose, operator UX, domain tooling) lives in
`workbench/agents/communications/`. Spine retains engine registrations,
bindings (projection), gates, and verify surfaces as L1/L2 infrastructure.

Extraction of product scripts and contracts to workbench is a follow-on
delivery packet, not part of this decision.

<!-- DOMAIN_CAPABILITY_CATALOG_START -->
## Capability Catalog
Generated from `ops/capabilities.yaml` by `catalog-domain-sync`.

_No domain-external capabilities currently map to `communications`._
<!-- DOMAIN_CAPABILITY_CATALOG_END -->

# communications

Canonical domain policy for `communications`.

- Authority: `docs/governance/SPINE.md`
- **Canonical home:** `workbench/agents/communications/`
- **Spine mode:** projection (spine holds engine registrations and thin shims; product truth lives in workbench)
- Runtime contracts: no bundle (communications has no bundle.yaml yet). Domain contracts now at `workbench/agents/communications/bindings/`.
- Promoted tracked bindings currently live at `workbench/agents/communications/bindings/`:
  `communications.providers.contract.yaml`,
  `communications.alerts.queue.contract.yaml`, and
  `communications.alerts.escalation.contract.yaml`.
  `communications.stack` is governed separately by the compose source.
  `communications.policy` and `communications.templates` are retired as tracked
  authority artifacts.
  `communications.delivery` remains intentionally unpromoted as a tracked
  authority artifact.
- Scoped domain health readback: `./bin/ops cap run verify.run -- domain communications`

## Canonical Home Decision

Decided 2026-04-25 (Packet 3: CANONICAL-HOME-MATRIX).

Communications product truth (compose, operator UX, domain tooling) lives in
`workbench/agents/communications/`. Spine retains engine registrations,
bindings (projection), gates, and verify surfaces as L1/L2 infrastructure.

Extraction delivered 2026-04-25 (Packet 5: COMMUNICATIONS-WORKBENCH-HOME-DELIVERY).
3 promoted domain binding contracts moved to
`workbench/agents/communications/bindings/`:
`communications.providers.contract.yaml`,
`communications.alerts.queue.contract.yaml`, and
`communications.alerts.escalation.contract.yaml`.
Canonical stack authority now lives at
`workbench/agents/communications/compose/docker-compose.yml`.
`communications.policy.contract.yaml` and
`communications.templates.catalog.yaml` are retired tracked-authority artifact
names.
`communications.delivery.contract.yaml` remains intentionally unpromoted as a
tracked authority artifact.
1 script converted to thin shim (delegates to workbench implementation).
Spine retains 1 thin shim, 13 gates (registry-only), and verify surfaces.

<!-- DOMAIN_CAPABILITY_CATALOG_START -->
## Capability Catalog
Generated from `ops/capabilities.yaml` by `catalog-domain-sync`.

_No domain-external capabilities currently map to `communications`._
<!-- DOMAIN_CAPABILITY_CATALOG_END -->

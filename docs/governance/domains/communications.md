# communications

Canonical domain policy for `communications`.

- Authority: `docs/governance/SPINE.md`
- **Canonical home:** `projects/communications/`
- **Spine mode:** projection (spine holds engine registrations and thin shims; product truth lives in the communications project)
- Runtime contracts: communications domain contracts live at `projects/communications/bindings/`.
- Promoted tracked bindings currently live at `projects/communications/bindings/`:
  `communications.providers.contract.yaml`,
  `communications.alerts.queue.contract.yaml`, and
  `communications.alerts.escalation.contract.yaml`, and
  `communications.stack.contract.yaml`.
  Runtime deployment still uses the compose source as the executable stack authority.
  `communications.policy` and `communications.templates` are retired as tracked
  authority artifacts.
  `communications.delivery` remains intentionally unpromoted as a tracked
  authority artifact.
- Scoped domain health readback: `./bin/ops cap run verify.run -- domain communications`

## Canonical Home Decision

Decided 2026-04-25 (Packet 3: CANONICAL-HOME-MATRIX).

Communications product truth (compose, operator UX, domain tooling) lives in
`projects/communications/`. Spine retains engine registrations,
bindings (projection), gates, and verify surfaces as L1/L2 infrastructure.

Extraction delivered 2026-04-25 (Packet 5: COMMUNICATIONS-WORKBENCH-HOME-DELIVERY).
Promoted domain binding contracts moved to
`projects/communications/bindings/`:
`communications.providers.contract.yaml`,
`communications.alerts.queue.contract.yaml`, and
`communications.alerts.escalation.contract.yaml`.
Canonical stack compose authority now lives at
`projects/communications/compose/docker-compose.yml`, with stack readback contract
at `projects/communications/bindings/communications.stack.contract.yaml`.
`communications.policy.contract.yaml` and
`communications.templates.catalog.yaml` are retired tracked-authority artifact
names.
`communications.delivery.contract.yaml` remains intentionally unpromoted as a
tracked authority artifact.
1 script converted to thin shim (delegates to the communications project implementation).
Spine retains 1 thin shim, 13 gates (registry-only), and verify surfaces.

<!-- DOMAIN_CAPABILITY_CATALOG_START -->
## Capability Catalog
Generated from `ops/capabilities.yaml` by `catalog-domain-sync`.

| Capability |
|---|
| `communications.mailarchiver.restore.drill` |
<!-- DOMAIN_CAPABILITY_CATALOG_END -->

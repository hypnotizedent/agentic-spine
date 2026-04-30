# observability

Canonical domain policy for `observability`.

- Authority: `docs/governance/SPINE.md`
- Runtime contracts: `ops/bindings/domains/observability.bundle.yaml`
- Verify entrypoint: `./bin/ops cap run verify.run -- domain observability`

## Witness Boundary

Observability is a witness surface only. It helps agents and operators see
service/readback posture before risky work, but it does not become spine
authority, backup authority, placement authority, or watcher authority.

The first-class agent context entrypoint is:

```bash
./bin/ops cap run observability.context.status
```

That readback may compose stack health, Prometheus scrape targets, watcher
summary, and backup posture. It must stay read-only: no backup jobs, restore
drills, service restarts, VM cutover, decommission, placement mutation, or
timer/cron changes.

Prometheus target failures are witness evidence, not automatic workload truth.
The owning domain readback must corroborate before treating a scrape failure as
a workload outage.

Generated service-health projection remains downstream of
`ops/bindings/probe.registry.yaml`; do not edit `services.health.yaml`
manually.

<!-- DOMAIN_CAPABILITY_CATALOG_START -->
## Capability Catalog
Generated from `ops/capabilities.yaml` by `catalog-domain-sync`.

_No domain-external capabilities currently map to `observability`._
<!-- DOMAIN_CAPABILITY_CATALOG_END -->

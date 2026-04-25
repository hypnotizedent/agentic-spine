# rag

Canonical domain policy for `rag`.

- Authority: `docs/governance/SPINE.md`
- Runtime contracts: `ops/bindings/domains/rag.bundle.yaml`
- Verify entrypoint: `./bin/ops cap run verify.run -- domain rag`
- Workbench agent root: `~/code/workbench/agents/ai-consolidation/`

The workbench agent uses the name `ai-consolidation` (matching the VM/host identity).
Spine retains `rag` as the capability domain name for policy and control-plane authority.

<!-- DOMAIN_CAPABILITY_CATALOG_START -->
## Capability Catalog
Generated from `ops/capabilities.yaml` by `catalog-domain-sync`.

_No domain-external capabilities currently map to `rag`._
<!-- DOMAIN_CAPABILITY_CATALOG_END -->

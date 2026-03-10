# Foundation Extraction Map

**Recommended foundation root:** `/Users/ronnyworks/code/agentic-foundation`

## Extract As Foundation Source

- Runtime implementation: `ops/runtime/**`, `ops/engine/**`, `mailroom/templates/**`
- Extension/plugin source: most of `ops/plugins/**` outside the small control-plane set (`session`, `verify`, `docs`, `loops`, `lifecycle`, `orchestration`, `proposals`, `authority`, `audit`, `agent`, `work-index`, `budget`, `surface`)
- Product/package docs: `docs/product/**`, plus governance-path product plans such as `docs/governance/CUSTOMER_PORTAL_CANONICAL_PLAN_V1.md`
- Operator/reference docs: `docs/brain/**`, `docs/runbooks/**`, `docs/pillars/**`, `docs/contracts/**`, `docs/validation/**`, `docs/jd/**`, plus governance-path operator checklists such as `docs/governance/FINANCE_STACK_OPERATOR_CHECKLIST.md` and `docs/governance/PROXMOX_VM_OPERATOR_CHECKLIST.md`
- Domain/prose contracts: `ops/agents/**`, domain-specific docs under `docs/governance/domains/**`
- Staged reusable source: service directories under `ops/staged/**`
- Surface integration sources: `surfaces/claude-ai-skill/**`, `fixtures/tenant.sample.yaml`

## Suggested Packages Inside Foundation

- `foundation/runtime-core`
  `ops/runtime/**`, `ops/engine/**`, `mailroom/templates/**`
- `foundation/extensions`
  Extracted plugin implementations and domain/operator wrappers
- `foundation/product-docs`
  `docs/product/**`, starter/product templates, tenant examples
- `foundation/operator-surfaces`
  Skills, runbooks, reference docs, worker usage guides

## Stay In Spine Instead

- `bin/ops`
- `ops/bindings/**`
- `ops/commands/**`
- `ops/lib/**`
- `ops/capabilities.yaml`
- Governance plugins and verify/session/orchestration/lifecycle surfaces
- Canonical control-plane governance docs and deterministic fixtures

## Why

The extracted foundation is still source, but it is not the boring control-plane core. Keeping it in a separate root lets the spine stay small, declarative, and enforcement-heavy while the reusable runtime/product layer can evolve independently.

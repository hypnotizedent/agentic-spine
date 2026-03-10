# Lane Docs Surfaces Fixtures Receipt

**Loop:** `LOOP-SPINE-BORING-REBUILD-20260310`
**Lane:** `lane-docs-surfaces-fixtures`
**Scope:** `docs/`, `surfaces/`, `fixtures/`

## Produced

- `DOCS_SCORECARD.md`
- `DOCS_GOVERNANCE_SCORECARD.md`
- `SURFACES_SCORECARD.md`
- `FIXTURES_SCORECARD.md`
- `DOCS_SURFACES_FIXTURES_QUALIFICATION_MANIFEST.tsv`

## Findings

- Control-plane canonical docs are centered in a subset of `docs/governance/`, most of `docs/core/`, and active surface files under `surfaces/verify/` and `surfaces/commands/`.
- `docs/archive/`, `docs/legacy/`, and `docs/planning/` are mostly archive or evidence surfaces and should leave the hot path.
- `docs/product/`, `docs/brain/`, `docs/pillars/`, `docs/runbooks/`, `docs/contracts/`, `surfaces/claude-ai-skill/`, and the product/operator-heavy subset of `docs/governance/` are useful source, but they describe product, operator, or extension concerns rather than the boring spine core.
- `docs/CANONICAL/**` and `docs/core/SPINE.md` are explicit duplicate-truth seams and remain operator decisions.

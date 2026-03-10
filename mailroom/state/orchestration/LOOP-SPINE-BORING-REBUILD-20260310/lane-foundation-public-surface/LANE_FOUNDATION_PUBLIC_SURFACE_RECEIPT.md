# Lane Foundation Public Surface Receipt

**Loop:** `LOOP-SPINE-BORING-REBUILD-20260310`
**Lane:** `lane-foundation-public-surface`
**Scope:** extracted foundation boundary and public starter definition

## Produced

- `FOUNDATION_CANDIDATE_SUMMARY.md`
- `PUBLIC_STARTER_CANDIDATE_SUMMARY.md`
- `FOUNDATION_EXTRACTION_MAP.md`
- `PUBLIC_GITHUB_STARTER_SURFACE.md`

## Findings

- The extracted foundation should own runtime implementation, product/package docs, operator surfaces, staged service source, and most extension plugins.
- The public GitHub starter should shrink to the control-plane core: bindings, commands, verify/session/orchestration plugins, canonical docs, and fixtures.
- Private local surfaces and live runtime/evidence stores should not ship as part of the starter.


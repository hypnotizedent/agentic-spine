# Lane Synthesis Receipt

**Loop:** `LOOP-SPINE-BORING-REBUILD-20260310`
**Lane:** `lane-synthesis`
**Scope:** final boringness model and unresolved decisions

## Produced

- `TOP_LEVEL_FOLDER_SCORECARD.md`
- `GLOBAL_BUCKET_COUNTS.md`
- `BORINGNESS_SYNTHESIS.md`
- `NON_REGRESSION_GUARD_PROPOSAL.md`
- `OPERATOR_DECISION_REGISTER.md`

## Findings

- The repo currently resolves to roughly three dominant classes: evidence (`receipts/**` and many mailroom artifacts), runtime (`mailroom` runtime/state exhaust and `runtime/**`), and a much smaller boring spine core.
- The smallest stable spine is declarative: entry surfaces, bindings, commands, verify/session/orchestration plugins, canonical docs, and deterministic fixtures.
- The remaining ambiguity is concentrated in local bootstrap state, duplicate canonical docs, staged source, rogue gate roots, and domain/operator-heavy surfaces.


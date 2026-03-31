# Media Workbench Home Relocation — Election

status: ratified
change_class: new_truth
parent_loop: LOOP-MEDIA-SPLIT-AUTHORITY-CANONICALIZATION-20260322
created: 2026-03-30

## Election question

Should canonical L3 media product authority move from `agentic-spine/ops/bindings/domains/media/` to `workbench/agents/media/`, with spine retaining only engine-facing registrations and compatibility projections?

## Result

**Ratified.** Operator approved in the control-plane prompt on 2026-03-30.

## Authorized scope

- Copy 20 authority files + 3 archive files to workbench media home
- Ingest March 29 runtime docs into workbench
- Mark all 23 spine copies as compatibility projections (all have live consumers)
- Update spine domain pointer to reference workbench as canonical
- Create implementation status artifact
- Commit and push both repos

## Constraints

- No capability ID or route changes
- No agentic-foundation cleanup
- No runtime deployment changes
- No new loop creation
- Consumer compatibility preserved via projection headers

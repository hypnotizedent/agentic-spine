---
loop_id: LOOP-WORKBENCH-AOF-NORMALIZATION-IMPLEMENT-20260217
created: 2026-02-17
status: active
owner: "@ronny"
scope: workbench
objective: Implement canonical AOF normalization across workbench docs, compose/runtime, and secrets with proactive proposal preflight enforcement.
parent_loop: LOOP-WORKBENCH-AOF-NORMALIZATION-AUDIT-20260216
---

## Child Workstreams

1. AOF contract + checker foundation
2. Compose/runtime normalization (ownership + patterns)
3. Secrets canonicalization (project, key, and env naming)
4. Metadata/schema normalization for inventory + docs
5. Proposal preflight enforcement and certification

## Success Criteria

- Single canonical contract for workbench normalization domains
- Proposal apply blocks P0/P1 workbench violations before mutation
- No active workbench references to deprecated finance-stack/mint-os-vault paths
- Compose/runtime pattern predictability across audited stacks

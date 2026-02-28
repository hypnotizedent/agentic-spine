---
loop_id: LOOP-SCOPE-TEMPLATE-VOCABULARY-NORMALIZATION-20260228
created: 2026-02-28
status: closed
owner: "@ronny"
scope: scope
priority: medium
objective: Update loops.create template to use Steps vocabulary instead of Phases per D145, and add linked_gaps table placeholder
---

# Loop Scope: LOOP-SCOPE-TEMPLATE-VOCABULARY-NORMALIZATION-20260228

## Objective

Update loops.create template to use Steps vocabulary instead of Phases per D145, and add linked_gaps table placeholder

## Steps

### Step 0: Friction Capture (COMPLETE)
- Every `loops.create` emits a legacy phase-priority template
- D145 vocabulary gate normalizes to "Steps" — agents rewrite every scope body
- This scope file itself was emitted with Phases and manually rewritten

### Step 1: Update template in loops-create
- Find template string in `ops/plugins/lifecycle/bin/loops-create`
- Replace "Phases" → "Steps", remove legacy priority labels, keep sequential step labels
- Add `## Linked Gaps` table placeholder (Gap ID / Type / Severity / Description / Status)
- Add `## Success Criteria` and `## Definition Of Done` sections matching current convention

### Step 2: Verify D145 passes on new loops
- Create a test loop, confirm template matches D145 vocabulary
- Run verify.pack.run aof to confirm D145 gate passes

## Linked Gaps

| Gap ID | Type | Severity | Description | Status |
|--------|------|----------|-------------|--------|
| GAP-OP-1092 | stale-ssot | medium | loops.create template used legacy vocabulary and D145 requires Steps | open |

## Success Criteria
- New loops created with `loops.create` emit Steps-based template
- D145 vocabulary gate passes on freshly created scope files
- No manual rewriting needed

## Definition Of Done
- Template updated and committed
- D145 passes on test loop
- Loop status can be moved to closed

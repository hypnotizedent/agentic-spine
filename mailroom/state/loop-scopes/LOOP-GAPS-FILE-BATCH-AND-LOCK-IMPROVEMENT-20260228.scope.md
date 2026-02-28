---
loop_id: LOOP-GAPS-FILE-BATCH-AND-LOCK-IMPROVEMENT-20260228
created: 2026-02-28
status: active
owner: "@ronny"
scope: gaps
priority: medium
objective: Eliminate agent friction in gaps.file: add --parent-loop flag, implement single-lock batch mode, add lock queuing instead of immediate fail, add gaps.next-id helper
---

# Loop Scope: LOOP-GAPS-FILE-BATCH-AND-LOCK-IMPROVEMENT-20260228

## Objective

Eliminate agent friction in gaps.file: add --parent-loop flag, implement single-lock batch mode, add lock queuing instead of immediate fail, add gaps.next-id helper

## Steps

### Step 0: Friction Capture (COMPLETE)
- Observed during LOOP-NETWORK-INFRASTRUCTURE-NORMALIZATION-20260228
- Filing 7 gaps took ~3 minutes instead of ~10 seconds due to lock contention
- 3 linter-race Edit failures while adding parent_loop manually
- Concurrent forensic-sweep interleaved 14 gaps into this session's block

### Step 1: Add --parent-loop flag to gaps.file (GAP-OP-1090)
- Accept `--parent-loop LOOP-ID` parameter
- Write `parent_loop:` field atomically with gap entry
- Validate loop ID exists in loop-scopes/

### Step 2: Lock queuing with backoff (GAP-OP-1088)
- Replace immediate STOP on lock contention with retry+backoff
- 3 retries, 1s/2s/4s backoff before giving up
- Alternatively: hold lock across batch writes (single acquire/release per session)

### Step 3: Atomic batch mode (GAP-OP-1094)
- `gaps.file --batch` should acquire lock once, write all entries, release once
- Prevent interleaving from concurrent agents
- Consider YAML append ordering (keep loop gaps contiguous)

### Step 4: gaps.next-id helper or --id auto default (GAP-OP-1091)
- Make `--id auto` the documented default pattern for agents
- Update MEMORY.md / agent instructions to stop using manual IDs
- Optionally add `gaps.next-id` read-only capability

### Step 5: Verify + Close
- File 10+ gaps in a single session without sleep delays
- Confirm --parent-loop writes correctly
- verify.pack.run aof PASS

## Linked Gaps

| Gap ID | Type | Severity | Description | Status |
|--------|------|----------|-------------|--------|
| GAP-OP-1088 | agent-behavior | high | Lock contention — immediate STOP on back-to-back calls | open |
| GAP-OP-1090 | missing-entry | high | No --parent-loop flag on gaps.file | open |
| GAP-OP-1091 | agent-behavior | medium | Gap ID discovery fragile, --id auto not default | open |
| GAP-OP-1094 | agent-behavior | medium | Concurrent agents interleave gaps in registry | open |

## Success Criteria
- Agent can file 10 gaps in <30 seconds without lock errors
- --parent-loop flag writes atomically
- --id auto is documented default
- verify.pack.run aof PASS

## Definition Of Done
- Scope artifacts updated and committed
- Receipted verification run keys recorded
- Loop status can be moved to closed

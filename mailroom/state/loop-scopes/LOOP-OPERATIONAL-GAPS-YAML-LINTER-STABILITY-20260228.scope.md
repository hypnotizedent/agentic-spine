---
loop_id: LOOP-OPERATIONAL-GAPS-YAML-LINTER-STABILITY-20260228
created: 2026-02-28
status: active
owner: "@ronny"
scope: operational
priority: medium
objective: Fix linter or hook that modifies operational.gaps.yaml between agent Read and Edit calls, causing repeated file-modified-since-read failures
---

# Loop Scope: LOOP-OPERATIONAL-GAPS-YAML-LINTER-STABILITY-20260228

## Objective

Fix linter or hook that modifies operational.gaps.yaml between agent Read and Edit calls, causing repeated file-modified-since-read failures

## Steps

### Step 0: Friction Capture (COMPLETE)
- During LOOP-NETWORK-INFRASTRUCTURE-NORMALIZATION-20260228, adding `parent_loop` to 7 gap entries required 10 Edit attempts — 3 failed with "File has been modified since read"
- Something modifies `operational.gaps.yaml` on disk between the agent's Read and Edit tool calls
- Likely candidates: YAML auto-formatter, IDE save hook, or fswatch-triggered linter

### Step 1: Identify the modifier
- Check `.githooks/pre-commit` for YAML formatting
- Check for fswatch/watchman processes targeting ops/bindings/
- Check IDE settings (VS Code, Cursor) for auto-format-on-save on YAML
- Check if `gaps.file` itself triggers a post-write formatter

### Step 2: Fix or exclude
- Option A: Exclude `operational.gaps.yaml` from auto-formatting (it's machine-written)
- Option B: Make the formatter idempotent (no change on already-formatted files)
- Option C: Add `--parent-loop` to `gaps.file` so agents never need to edit this file manually (overlap with LOOP-GAPS-FILE-BATCH-AND-LOCK-IMPROVEMENT-20260228)

### Step 3: Verify
- File 5 gaps, add parent_loop via Edit, confirm 0 race failures
- verify.pack.run aof PASS

## Linked Gaps

| Gap ID | Type | Severity | Description | Status |
|--------|------|----------|-------------|--------|
| GAP-OP-1093 | runtime-bug | high | operational.gaps.yaml modified between Read and Edit calls | open |

## Success Criteria
- Agent can Edit operational.gaps.yaml without race failures
- Root cause identified and fixed or mitigated

## Definition Of Done
- Fix committed
- 0 race failures on 5+ consecutive edits
- Loop status can be moved to closed

---
loop_id: LOOP-AGENT-CAPABILITY-ERGONOMICS-20260227-20260228
created: 2026-02-28
status: active
owner: "@ronny"
scope: agent
priority: medium
objective: Reduce agent friction in spine capability system. cap show needs flag docs, capability names should auto-inject modes, cap.sh needs bulk/batch overhead reduction, MEMORY.md needs restructure, zsh variable collisions need fixing, subagent context sharing needs improvement.
---

# Loop Scope: LOOP-AGENT-CAPABILITY-ERGONOMICS-20260227-20260228

## Objective

Reduce agent friction in spine capability system. cap show needs flag docs, capability names should auto-inject modes, cap.sh needs bulk/batch overhead reduction, MEMORY.md needs restructure, zsh variable collisions need fixing, subagent context sharing needs improvement.

## Steps

### Step 0: Friction Capture (COMPLETE)
- Observed during LOOP-CROSS-SITE-MAINTENANCE-PARITY-20260227 (26-gap filing session)
- Related to but distinct from LOOP-GAPS-FILE-BATCH-AND-LOCK-IMPROVEMENT-20260228 (which covers gaps.file locking/batching)
- This loop covers cap.sh ergonomics, capability definition gaps, and agent runtime friction

### Step 1: cap show flag documentation (GAP-OP-1095)
- `cap show` only displays description/safety/approval
- Agent called `infra.proxmox.maintenance.precheck` without `--mode precheck` — got STOP
- Had to read script source to discover required flags
- Fix: parse `--help` output or add `flags:` field to capability YAML, display in `cap show`

### Step 2: Capability auto-mode injection (GAP-OP-1096)
- `infra.proxmox.maintenance.precheck` and `.shutdown` and `.startup` are separate capabilities calling same script
- Each still requires explicit `--mode` flag despite capability name implying it
- Fix: capability definition should inject mode args so agent just calls `cap run infra.proxmox.maintenance.precheck`

### Step 3: zsh status variable collision (GAP-OP-1097)
- `status` is read-only in zsh (macOS default shell)
- Agent inline bash verification loops fail with `read-only variable: status`
- Fix: audit spine scripts for `status` as local var, rename to `_status` or `result_status`

### Step 4: MEMORY.md restructure (GAP-OP-1098)
- Currently 268 lines, truncated at 200
- Agent loses context on recent loops/discoveries
- Fix: move detailed per-loop notes to topic files, keep MEMORY.md as concise index <150 lines

### Step 5: cap.sh bulk overhead reduction (GAP-OP-1099)
- Each `gaps.file` call takes 3-5s (policy resolution, receipt gen, identity check)
- Filing 26 gaps took >3 minutes wall time
- Fix: lightweight fast-path for sequential same-capability calls, or batch API
- Related: LOOP-GAPS-FILE-BATCH-AND-LOCK-IMPROVEMENT covers locking; this covers general cap.sh overhead

### Step 6: Subagent context sharing (GAP-OP-1100)
- 5 parallel Explore agents each independently read same files (vm.lifecycle.yaml, startup.sequencing.yaml, etc.)
- ~400K total tokens for one research question split 5 ways
- Fix: consider ctx preload bundles for common infra files, or shared read cache across subagents

## Linked Gaps

| Gap ID | Type | Severity | Description | Status |
|--------|------|----------|-------------|--------|
| GAP-OP-1095 | agent-behavior | high | cap show missing flag documentation | open |
| GAP-OP-1096 | agent-behavior | medium | Capability name implies mode but doesnt inject it | open |
| GAP-OP-1097 | runtime-bug | medium | zsh read-only status variable collision | open |
| GAP-OP-1098 | agent-behavior | medium | MEMORY.md truncated at 200 lines | open |
| GAP-OP-1099 | agent-behavior | medium | cap.sh overhead painful for bulk operations | open |
| GAP-OP-1100 | agent-behavior | low | Parallel subagents share no context cache | open |

## Related Loops
- LOOP-GAPS-FILE-BATCH-AND-LOCK-IMPROVEMENT-20260228 — covers gaps.file locking, --parent-loop, batch mode, --id auto
- LOOP-OPERATIONAL-GAPS-YAML-LINTER-STABILITY-20260228 — covers linter race conditions on gaps yaml

## Success Criteria
- `cap show` displays flags/usage for any capability
- Agent can call `infra.proxmox.maintenance.precheck` without explicit `--mode`
- No zsh variable collision errors in agent verification loops
- MEMORY.md under 150 lines with topic file links
- verify.pack.run aof PASS

## Definition Of Done
- Scope artifacts updated and committed.
- Receipted verification run keys recorded.
- Loop status can be moved to closed.

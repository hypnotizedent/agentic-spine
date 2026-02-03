# Agent Dispatch Pipeline Gap Scan

**Date:** 2026-01-26 22:38 PST
**Auditor:** Claude (Terminal Operator)
**Scope:** Verify docs/runbook vs script behavior vs launchd wiring vs runtime layout
**Status: LEGACY** — Historical audit snapshot. Path authority now at `infrastructure/docs/AUTHORITY_INDEX.md` → SPINE

---

## Summary Table

| Check | Status | Evidence |
|-------|--------|----------|
| 1. Repo Integrity | PASS | On `main`, 1 untracked file (this audit), no drift |
| 2. Runtime Layout | PASS | All lanes exist, ledger.csv present, outbox functional |
| 3. Launchd Wiring | PASS | Job running (PID 6944), correct paths, logs to ~/agent/logs |
| 4. Script Self-Diag | PASS | `bash -n` clean, `--status` works correctly |
| 5. Docs Match Behavior | **FAIL** | Outdated Desktop symlink references in debug section |
| 6. RAG-lite Safety Bounds | PASS | Opt-in only, bounded to docs/ + modules/, limits enforced |
| 7. Secrets/State Leak Check | PASS | state/ gitignored, no secrets printed to context |
| 8. Live Behavior Probe | PASS | Prompt processed queued→done, result in outbox, ledger updated |

---

## Check Details

### 1. Repo Integrity (PASS)

```
Branch: main
Status: 1 untracked file (docs/audits/RAG_INTEGRATION_RATIONALE.md)

Recent commits:
a507d4e1 docs(agents): add Prompt Contract + update flow diagram
4c977b8b chore(agents): add outbox purge utility + archive disconnect audit
9812f1ea feat(agents): add traceability lanes + run ledger + status dashboard
```

### 2. Runtime Layout (PASS)

```
~/agent/
├── inbox/
│   ├── queued/   ← Drop zone
│   ├── running/  ← In flight
│   ├── done/     ← Completed (3 files)
│   ├── failed/   ← Errors
│   └── parked/   ← Blocked
├── outbox/       ← Results (4 files)
├── logs/         ← Watcher logs
└── state/
    ├── ledger.csv      ← 10 rows, append-only
    ├── agent-inbox.pid ← PID file present
    └── locks/          ← Lock directory
```

### 3. Launchd Wiring (PASS)

```
Job: com.ronny.agent-inbox
State: running
PID: 6944

ProgramArguments:
  /bin/bash -lc /Users/ronnyworks/ronny-ops/scripts/agents/hot-folder-watcher.sh

StandardOutPath: /Users/ronnyworks/agent/logs/agent-inbox.out
StandardErrorPath: /Users/ronnyworks/agent/logs/agent-inbox.err

EnvironmentVariables:
  AGENT_INBOX=/Users/ronnyworks/agent/inbox
  AGENT_OUTBOX=/Users/ronnyworks/agent/outbox
  AGENT_STATE=/Users/ronnyworks/agent/state
  RONNY_OPS_REPO=/Users/ronnyworks/ronny-ops
```

No Desktop symlink references in plist.

### 4. Script Self-Diag (PASS)

```bash
$ bash -n scripts/agents/hot-folder-watcher.sh
# No output = syntax OK

$ scripts/agents/hot-folder-watcher.sh --status
  Queued:   0
  Running:  0
  Done:     3
  Status:   Running (PID: 6944)
```

### 5. Docs Match Behavior (FAIL)

**Issue found in `docs/runbooks/AGENT_DISPATCH_PIPELINE.md`:**

Lines 280-283 contain outdated debug commands:
```bash
echo "== canonical dirs =="
ls -la ~/ronnyworks/agent    # WRONG: should be ~/agent

echo "== desktop symlinks =="
ls -la ~/Desktop/agent-inbox ~/Desktop/agent-outbox  # OUTDATED: symlinks removed
```

These references are in a debug script section but should be updated to reflect current architecture.

### 6. RAG-lite Safety Bounds (PASS)

**Opt-in mechanism:**
```bash
# Line 244: Only retrieve if RAG:ON is present
if ! grep -q "RAG:ON" "$prompt_file" 2>/dev/null; then
    return  # Skip retrieval
```

**Bounded scope:**
```bash
# Lines 262-263: Search only docs/ and modules/
local search_dirs=("$REPO/docs")
[[ -d "$REPO/modules" ]] && search_dirs+=("$REPO/modules")
```

**Limits enforced:**
```bash
# Line 266: Max 3 files retrieved
matches="$(rg -l -i "$query" "${search_dirs[@]}" --type md 2>/dev/null | head -3)"
```

**Ledger tracking:**
- `context_used` column properly updated to `rag-lite` when RAG used

### 7. Secrets/State Leak Check (PASS)

**state/ gitignored:**
```
# .gitignore line 88
state/
```

**ANTHROPIC_API_KEY handling:**
- Used for API calls only (line 345)
- Loaded from keychain (lines 120-126)
- Never printed to logs or prompt context

**No dangerous retrieval:**
- Script does not search .env files
- Retrieval bounded to docs/ and modules/ only
- No infrastructure/, receipts/, or state/ in search scope

### 8. Live Behavior Probe (PASS)

**Test file:** `PIPELINE_GAP_SCAN_TEST_1769485094.md`
**Content:** "Explain what this agent system does in one sentence."

**Results:**
```
queued → running → done  ✓
Outbox: 20260126-223815-4s9xjx6944_RESULT.md  ✓
Ledger: Row appended with status=done  ✓
Processing time: ~3 seconds
```

---

## Gaps Found

| # | Location | Gap | Severity |
|---|----------|-----|----------|
| 1 | `docs/runbooks/AGENT_DISPATCH_PIPELINE.md:280` | Typo: `~/ronnyworks/agent` should be `~/agent` | Low |
| 2 | `docs/runbooks/AGENT_DISPATCH_PIPELINE.md:283` | Outdated Desktop symlink references in debug script | Low |

---

## Next Fixes (if any)

1. **Update debug script in runbook** (low priority, cosmetic):
   - Line 280: Change `~/ronnyworks/agent` to `~/agent`
   - Lines 282-283: Remove Desktop symlink check or replace with canonical paths

These are documentation gaps only. The actual system operates correctly with no Desktop symlink dependencies.

---

## Conclusion

**Pipeline Status: LOCKED**

The Agent Dispatch Pipeline is functionally complete and operating correctly. All runtime components (launchd job, watcher script, inbox lanes, ledger, outbox) are wired correctly and processing prompts end-to-end.

The only gaps are cosmetic documentation issues in a debug script section that do not affect system behavior.

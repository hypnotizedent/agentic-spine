---
status: authoritative
owner: "@ronny"
created: 2026-02-22
scope: codebase-cleanup-and-next-queue
source: AUDIT-CODE-FOLDER-DRIFT-20260222
---

# Codebase Cleanup Execution Queue

Generated from audit `AUDIT-CODE-FOLDER-DRIFT-20260222`. Items ordered by priority.

## Completed (this session)

| ID | Action | Result |
|---|---|---|
| CL-01 | Delete `apply/cp-20260221-mobile-ledger-rerun` (spine) | Done |
| CL-02 | Delete `hardening/orch-entry-20260212` (workbench) | Done |
| CL-03 | Delete `worker-e/w2-lane-e-mcpjungle-cleanup` (workbench) | Done |
| CL-04 | Remove `~/code/agentic-spine-.worktrees/` (orphan) | Done |
| CL-05 | Remove `mint-modules/.worktrees/integration/` (orphan) | Done |
| CL-06 | Move `~/code/SYSTEM_AUDIT_20260222.md` to spine audits | Done |
| CL-07 | Delete `codex/proposals-apply-20260222` (spine) | SKIPPED — not merged |
| CL-08 | Delete 5x `exec/*` (mint-modules) | SKIPPED — not merged (audit false positive) |
| CL-09 | Delete 5x `exec/*` (workbench) | SKIPPED — not merged (audit false positive) |

## Remaining Queue

### Q-01: Decide on unmerged exec/* branches (mint-modules + workbench)

- **Owner:** Ronny
- **Repo:** mint-modules, workbench
- **Risk:** low (branches are local-only, not on remotes)
- **Dependency:** None
- **ETA:** 5 min
- **Commands:**
  ```bash
  # Option A: Force delete (if work is superseded by main)
  cd ~/code/mint-modules
  git branch -D exec/a-agent-mcp-surface-v2-20260218 exec/a-guard-selfmatch-20260218 \
    exec/b-agent-smoke-runbook-20260218 exec/b-release-7module-20260218 \
    exec/c-smoke-fullstack-20260218
  cd ~/code/workbench
  git branch -D exec/a-agent-mcp-surface-v2-20260218 exec/a-guard-selfmatch-20260218 \
    exec/b-agent-smoke-runbook-20260218 exec/b-release-7module-20260218 \
    exec/c-smoke-fullstack-20260218

  # Option B: Keep if any contain unreleased work
  # Check first: git log main..exec/a-agent-mcp-surface-v2-20260218 --oneline
  ```
- **Done check:** `git branch | grep exec/` returns empty in both repos

### Q-02: Commit or gitignore 31 untracked n8n workflow JSONs (workbench)

- **Owner:** Ronny
- **Repo:** workbench
- **Risk:** low
- **Dependency:** None
- **ETA:** 2 min
- **Commands:**
  ```bash
  cd ~/code/workbench

  # Option A: Commit as workflow backup archive
  git add infra/compose/n8n/workflows/*.json
  git commit -m "chore: archive n8n workflow exports"

  # Option B: Gitignore (if these are auto-generated)
  echo "infra/compose/n8n/workflows/*.json" >> .gitignore
  git add .gitignore && git commit -m "chore: gitignore n8n workflow exports"
  ```
- **Done check:** `git status --short | grep n8n | wc -l` returns 0

### Q-03: Commit or restore 4 dirty tracked files (workbench)

- **Owner:** Ronny
- **Repo:** workbench
- **Risk:** low
- **Dependency:** None
- **ETA:** 2 min
- **Commands:**
  ```bash
  cd ~/code/workbench
  git diff agents/microsoft/docs/INDEX.md  # Review changes

  # If changes are intentional:
  git add agents/microsoft/docs/INDEX.md agents/microsoft/docs/notes/INDEX.md \
    dotfiles/macbook/README.md dotfiles/opencode/opencode.json \
    agents/microsoft/docs/notes/20260220__CAP-*.md
  git commit -m "chore: commit pending workbench state changes"

  # If changes are accidental:
  git checkout -- agents/microsoft/docs/INDEX.md agents/microsoft/docs/notes/INDEX.md \
    dotfiles/macbook/README.md dotfiles/opencode/opencode.json
  ```
- **Done check:** `git status --short | wc -l` < 5 (excluding n8n if Q-02 not done)

### Q-04: Close stale open MINT loops in spine

- **Owner:** Ronny
- **Repo:** agentic-spine
- **Risk:** medium (closing loops is a governance action)
- **Dependency:** Q-01 (confirm exec branches are dead)
- **ETA:** 10 min
- **Context:** Spine tracks 8 open LOOP-MINT-* loops. Mint-modules has moved past them with MODULE_FIRST_RESET commit. These loops create false "10 loops open" signal in `ops status`.
- **Commands:**
  ```bash
  cd ~/code/agentic-spine
  # Review which loops are truly superseded:
  ./bin/ops loops list --open

  # For each superseded loop, close it:
  # ./bin/ops cap run loops.close LOOP-MINT-AUTH-PHASE0-CONTRACT-20260222 \
  #   --reason "Superseded by MODULE_FIRST_RESET in mint-modules"
  # (repeat for each)
  ```
- **Done check:** `./bin/ops loops list --open | grep MINT | wc -l` < 3

### Q-05: Add wave runtime TTL / archive policy

- **Owner:** Ronny
- **Repo:** agentic-spine
- **Risk:** low
- **Dependency:** None
- **ETA:** 15 min (backlog)
- **Context:** `.runtime/spine-mailroom/waves/` contains test artifacts (WAVE-97/98/99) and closed waves with no TTL. Will accumulate indefinitely.
- **Commands:**
  ```bash
  # Option: Add to wave.lifecycle.yaml
  # archive_policy:
  #   ttl_days: 7
  #   archive_dir: waves/.archive
  #   auto_prune: false  (manual for now)

  # Manual cleanup of test artifacts:
  rm -rf ~/.runtime/spine-mailroom/waves/WAVE-20260222-{97,98,99}
  rm -rf ~/.runtime/spine-mailroom/waves/WAVE-20260222-{10,11,12}
  ```
- **Done check:** `ls ~/.runtime/spine-mailroom/waves/ | wc -l` < 5

### Q-06: Implement audit guardrails (backlog — NOT tonight)

These are from the audit report. Each becomes a gap or drift gate when prioritized.

| Guard | Description | Testable By |
|---|---|---|
| G-01 | WAVE IDs include repo prefix | `ops wave start` pattern validation |
| G-02 | One planning SSOT per domain (mint planning in mint-modules only) | Drift gate on `spine/docs/planning/MINT_*` staleness |
| G-03 | Merged branches auto-delete | Post-merge hook or verify check |
| G-04 | Cross-repo loop commits reference same loop_id | Grep commit messages across repos |
| G-05 | No files outside repo roots in ~/code/ | `ls ~/code/` verify check |
| G-06 | Wave runtime TTL (7d archive) | Cron or verify check on closed_at age |
| G-07 | Workbench dirty file budget (<5 at session close) | Session closeout check |

## Module-First Execution (Tonight's Real Work)

After cleanup, move to `/Users/ronnyworks/code/mint-modules`:

1. **shipping** — real EasyPost adapter + persistence layer (scaffold exists at `shipping/`)
2. **suppliers** — extraction from legacy adapters/sync scripts (work in progress: `suppliers/src/providers/` untracked)

Spine and workbench are FROZEN unless production break/fix.

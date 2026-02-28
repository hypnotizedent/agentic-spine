# LOOP-GOV-CLAUDE-ENTRYPOINT-LOCK-20260208

**Status:** closed
**Severity:** medium
**Owner:** @ronny
**Created:** 2026-02-08
**Gap:** GAP-OP-017

## Objective

Eliminate competing instruction authority from CLAUDE.md, enforce Claude home-config
path canon (`/Users/ronnyworks/code` not `/Users/ronnyworks/Code`), and repair runtime
`.brain/*` path drift so context injection is reliably spine-native.

## Root Cause Chain

1. `~/.claude/CLAUDE.md` contains standalone governance sections (duplicate authority)
2. No Claude-equivalent of D32 (Codex instruction source lock) exists
3. Runtime scripts (`launch-agent.sh`, `hot-folder-watcher.sh`, `close-session.sh`) reference `.brain/` but no `.brain/` directory exists — actual files live at `docs/brain/`
4. `SESSION_PROTOCOL.md` also references `.brain/`
5. CLAUDE.md, `commands/ctx.md`, `settings.json`, `settings.local.json` use uppercase `~/Code/`

## Phases

- **P0:** Baseline + loop registration + GAP-OP-017
- **P1:** Create CLAUDE_ENTRYPOINT_SHIM.md + agent.entrypoint.lock.yaml + host plugin
- **P2:** D46 Claude instruction source lock + D47 brain surface path lock
- **P3:** Fix `.brain/` references to `docs/brain/` in runtime scripts + SESSION_PROTOCOL
- **P4:** Register capabilities + update governance indexes
- **P5:** Verification + closeout

## Acceptance Criteria

- D46 passes: CLAUDE.md is redirect shim, no standalone governance headings, no uppercase Code paths
- D47 passes: no `.brain/` references in runtime scripts
- `ops verify` passes with no new failures relative to baseline
- All mutating actions have receipts

## Evidence

- `ops/bindings/operational.gaps.yaml` (GAP-OP-017)
- `~/.claude/CLAUDE.md` (current state with governance sections)
- `ops/runtime/inbox/launch-agent.sh` (`.brain/` reference at line 19)

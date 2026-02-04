# OPS Patch History (Spine-native)

> **Status:** authoritative
> **Last verified:** 2026-02-04

Purpose: record proof of critical ops path hardening (no ronny-ops fallback).

## MUSTFIX patches (confirmed working)
- ai.sh: removed `$HOME/ronny-ops` fallback; requires git context or explicit `REPO_ROOT`
- clerk-watcher.sh: service registry path now spine-native
- README.md: installation paths updated to `~/Code/agentic-spine` and `~/.local/bin`

## Proof (receipts)
- receipts/sessions/ADHOC_20260201_031118_OPS_HARDCODED_MUSTFIX/
- receipts/sessions/ADHOC_20260201_031556_OPS_SMOKE_MATRIX/

## Governance Hardening Sprint (2026-02-04)

Changes:
- Created `docs/core/SPINE_STATE.md` — canonical state doc, registered in README
- Fixed 7 docs with stale ronny-ops instructions (AGENTS_GOVERNANCE, REPO_STRUCTURE_AUTHORITY, SCRIPTS_AUTHORITY, INFRASTRUCTURE_MAP, GOVERNANCE_INDEX, brain/README, issue.md)
- Added reference audit table to CORE_AGENTIC_SCOPE.md (120+ refs categorized)
- Added CHECK 7 (SSOT path validation) to docs-lint
- Fixed CHECK 5 self-referential false positive in docs-lint
- Added `# Status: authoritative` + `# Last verified:` to 4 YAML registries

Proof:
- `docs.lint`: 0 errors, CHECK 7: 12 spine-local OK / 23 external / 0 missing
- `spine.verify`: D1–D24 all PASS
- `spine.replay`: 4/4 deterministic match
- Receipt keys: CAP-20260204-022915__docs.lint, CAP-20260204-022919__spine.verify

## Expected behavior
- `ops ai` outside git repo:
  - fails with: `ERROR: REPO_ROOT not set and not in a git repo.`

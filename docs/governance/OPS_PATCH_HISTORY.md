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

## Workbench Portability + Spine README Alignment (2026-02-04)

Changes:
- Spine README: replaced `./cli/bin/spine` with `./bin/ops`, removed ronny-ops secrets loading, added `~/.config/infisical/credentials` path
- Created `hypnotizedent/workbench` (private) — 473 files tracked across infra/docs/dotfiles/scripts
- Workbench .gitignore: deferred folders (immich, home-assistant, media-stack, mint-os), .DS_Store, .env, *.log
- Archived 5 runtime-bleed scripts to `.archive/legacy-runtime/` (supervisor-start/closeout/exit-prompt, terminal-closeout/bootstrap)
- Added Legacy Path Map to `docs/LEGACY_TIES.md` (9 path translations)
- Added legacy callouts to 8 workbench docs (README, 00-overview, AUTHORITY_INDEX, MCP_AUTHORITY, RAG_ARCHITECTURE, LAPTOP, CLOUDFLARE_GOVERNANCE, WORKBENCH_CONTRACT)
- `docs/WORKBENCH_CONTRACT.md` is now canonical (root copy redirects)

Proof:
- `docs.lint`: 0 errors, 0 warnings
- `spine.verify`: D1–D24 PASS
- `spine.replay`: 4/4 match
- `spine.status`: watcher healthy
- Workbench `git status`: clean, deferred folders excluded
- Receipt keys: CAP-20260204-025408__spine.verify, CAP-20260204-025410__spine.replay

## Expected behavior
- `ops ai` outside git repo:
  - fails with: `ERROR: REPO_ROOT not set and not in a git repo.`

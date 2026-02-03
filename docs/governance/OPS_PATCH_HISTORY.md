# OPS Patch History (Spine-native)

Purpose: record proof of critical ops path hardening (no ronny-ops fallback).

## MUSTFIX patches (confirmed working)
- ai.sh: removed `$HOME/ronny-ops` fallback; requires git context or explicit `REPO_ROOT`
- clerk-watcher.sh: service registry path now spine-native
- README.md: installation paths updated to `~/Code/agentic-spine` and `~/.local/bin`

## Proof (receipts)
- receipts/sessions/ADHOC_20260201_031118_OPS_HARDCODED_MUSTFIX/
- receipts/sessions/ADHOC_20260201_031556_OPS_SMOKE_MATRIX/

## Expected behavior
- `ops ai` outside git repo:
  - fails with: `ERROR: REPO_ROOT not set and not in a git repo.`

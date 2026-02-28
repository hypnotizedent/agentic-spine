# W79-T0 Promotion Parity Receipt

**Date:** 2026-02-28
**Control Loop:** LOOP-W79-T0-SECURITY-EMERGENCY-20260228

---

## Branch Parity

| Repo | Branch | Upstream | Pushed | Status |
|------|--------|----------|--------|--------|
| agentic-spine | codex/w79-program-t0-20260228 | none | NO | Local only — not pushed |
| workbench | codex/w79-program-t0-20260228 | none | NO | Local only — not pushed |
| mint-modules | codex/w79-program-t0-20260228 | none | NO | Clean — no changes in this wave |

## Commit Parity

| Repo | T0 Commits | Content |
|------|-----------|---------|
| agentic-spine | 3 new (auto-committed by gaps.file) | GAP-OP-1195, GAP-OP-1196, GAP-OP-1197 registration |
| workbench | 0 new (changes unstaged) | Containment edits: recyclarr.yml, refresh-mint-vault.py, .gitignore, pre-commit hook |
| mint-modules | 0 | No changes |

## Uncommitted Changes Summary

### agentic-spine (unstaged)
- `docs/planning/W79_T0_*.md` — 6 artifacts (this wave)
- `mailroom/state/loop-scopes/LOOP-W79-T0-SECURITY-EMERGENCY-20260228.scope.md` — loop scope
- `ops/plugins/verify/state/verify-failure-class-history.ndjson` — TELEMETRY EXCEPTION (preserved unstaged per policy)

### workbench (unstaged)
- `.githooks/pre-commit` — added committed-secret-check invocation
- `.gitignore` — added `secrets.yml` exclusion
- `agents/media/config/recyclarr.yml` — replaced hardcoded API keys with `!secret` refs
- `scripts/root/.archive/2025-migrations/refresh-mint-vault.py` — replaced hardcoded Printavo token with env var
- `scripts/root/security/committed-secret-check.sh` — NEW regression lock script

### mint-modules
- (none)

## Promotion Path

1. **Branch-only review:** `git diff main...HEAD` in each repo
2. **Tokened promotion:** Requires `RELEASE_MAIN_MERGE_WINDOW` token
3. **Optional history rewrite:** Requires `RELEASE_SECRET_REWRITE_WINDOW` token (for git filter-branch to remove secrets from history)

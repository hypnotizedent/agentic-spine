# W79-T0 Token Inventory (Redacted)

**Date:** 2026-02-28
**Source:** W77 Forensic Audit Report (WB-C1)
**Control Loop:** LOOP-W79-T0-SECURITY-EMERGENCY-20260228

---

## Classification Legend

| Classification | Meaning |
|----------------|---------|
| TRUE_UNRESOLVED | Credential exists in git-tracked file, exposed in repo history |
| STALE_FALSE | Credential exists on disk only, gitignored, never committed — W77 finding incorrect about git exposure |
| NOOP_FIXED | Already resolved or not applicable |

---

## TRUE_UNRESOLVED Findings

| # | Finding ID | Service | File | Line | Fingerprint | Gap ID | Containment Plan |
|---|-----------|---------|------|------|-------------|--------|-----------------|
| 1 | WB-C1-SONARR | Sonarr | workbench/agents/media/config/recyclarr.yml | 11 | `284a****2274` | GAP-OP-1195 | Replace with `!secret SONARR_API_KEY` ref |
| 2 | WB-C1-RADARR | Radarr | workbench/agents/media/config/recyclarr.yml | 45 | `f381****ae98` | GAP-OP-1196 | Replace with `!secret RADARR_API_KEY` ref |
| 3 | WB-C1-PRINTAVO | Printavo | workbench/scripts/root/.archive/2025-migrations/refresh-mint-vault.py | 22 | `tApa****-ofg` | GAP-OP-1197 | Replace literal with `os.environ.get()` |

## STALE_FALSE Findings (W77 WB-C1 classification corrected)

These credentials exist on disk in `.env` files but are **gitignored and were never committed**. The W77 forensic report incorrectly stated "Live API tokens committed to git." Git verification (`git ls-files` + `git log --all`) confirms zero git exposure.

| # | Finding ID | Service | File | Status | Evidence |
|---|-----------|---------|------|--------|----------|
| 4 | WB-C1-FIREFLY | Firefly III | workbench/agents/finance/tools/.env | STALE_FALSE | `.gitignore:36` matches, `git log --all` returns empty |
| 5 | WB-C1-IMMICH | Immich | workbench/agents/immich/tools/mcp/.env | STALE_FALSE | `.gitignore:36` matches, `git log --all` returns empty |
| 6 | WB-C1-PAPERLESS | Paperless-ngx | workbench/agents/finance/tools/.env | STALE_FALSE | `.gitignore:36` matches, `git log --all` returns empty |
| 7 | WB-C1-GHOSTFOLIO | Ghostfolio | workbench/agents/finance/tools/.env | STALE_FALSE | `.gitignore:36` matches, `git log --all` returns empty |

## Rotation Requirement Summary

| Classification | Count | Rotation Required |
|---------------|-------|-------------------|
| TRUE_UNRESOLVED | 3 | YES — keys are in git history even after containment |
| STALE_FALSE | 4 | RECOMMENDED — but no git exposure risk |

---

*No secret values printed. Fingerprints use first-4/last-4 masking only.*

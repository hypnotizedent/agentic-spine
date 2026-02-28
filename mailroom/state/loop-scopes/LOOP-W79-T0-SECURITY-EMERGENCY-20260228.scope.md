---
loop_id: LOOP-W79-T0-SECURITY-EMERGENCY-20260228
created: 2026-02-28
status: active
owner: "@ronny"
scope: w79
priority: critical
objective: Security emergency — rotate/revoke compromised credentials, contain secret exposure in tracked files, add regression locks
---

# Loop Scope: LOOP-W79-T0-SECURITY-EMERGENCY-20260228

## Objective

Security emergency — rotate/revoke compromised credentials, contain secret exposure in tracked files, add regression locks. Driven by W77 forensic audit finding WB-C1 (live API tokens in git-tracked files).

## Findings Classification

| Finding ID | Credential | File | Classification | Evidence |
|------------|-----------|------|----------------|----------|
| WB-C1-SONARR | Sonarr API Key | recyclarr.yml:11 | TRUE_UNRESOLVED | 32-char hex in git-tracked file |
| WB-C1-RADARR | Radarr API Key | recyclarr.yml:45 | TRUE_UNRESOLVED | 32-char hex in git-tracked file |
| WB-C1-PRINTAVO | Printavo API Token | refresh-mint-vault.py:22 | TRUE_UNRESOLVED | base64 token in git-tracked archived script |
| WB-C1-FIREFLY | Firefly III JWT | agents/finance/tools/.env | STALE_FALSE | gitignored, never committed |
| WB-C1-IMMICH | Immich API Key | agents/immich/tools/mcp/.env | STALE_FALSE | gitignored, never committed |
| WB-C1-PAPERLESS | Paperless API Token | agents/finance/tools/.env | STALE_FALSE | gitignored, never committed |
| WB-C1-GHOSTFOLIO | Ghostfolio Access Token | agents/finance/tools/.env | STALE_FALSE | gitignored, never committed |

## Phases
- Step 1: Confirm findings, classify, register gaps
- Step 2: Rotate/revoke compromised credentials
- Step 3: Contain secrets in code (remove literals, env-varize, gitignore)
- Step 4: Verify (secret scans, verify packs, final receipts)

## Success Criteria
- All TRUE_UNRESOLVED credentials rotated or documented as HOLD_WITH_BLOCKERS
- Zero secret literals in HEAD of tracked files
- Regression lock gate active for committed-secret detection
- All linked gaps resolved or documented

## Definition Of Done
- Scope artifacts updated and committed
- Receipted verification run keys recorded
- W79_T0 artifacts produced
- Loop status can be moved to closed

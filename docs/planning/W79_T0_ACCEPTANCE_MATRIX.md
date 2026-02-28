# W79-T0 Acceptance Matrix

**Date:** 2026-02-28
**Control Loop:** LOOP-W79-T0-SECURITY-EMERGENCY-20260228

---

## Acceptance Criteria

| # | Criterion | Status | Evidence |
|---|-----------|--------|----------|
| 1 | confirmed_leaks == rotated_or_revoked_leaks | **FAIL** | 3 confirmed, 0 rotated (HOLD_WITH_BLOCKERS — no API/SSH access for rotation) |
| 2 | high_confidence_head_leaks == 0 | **PASS** | All 3 repos scan clean — no secret literals in HEAD tracked files |
| 3 | every confirmed token finding linked to a gap | **PASS** | GAP-OP-1195, 1196, 1197 (TRUE_UNRESOLVED); 4 STALE_FALSE classified with evidence |
| 4 | orphaned_open_gaps == 0 | **PASS** | gaps.status confirms 0 orphaned |
| 5 | blocker_count == 0 | **FAIL** | 3 blockers: Sonarr rotation (no API endpoint), Radarr rotation (no API endpoint), Printavo rotation (SaaS UI required) |
| 6 | telemetry exception preserved unstaged | **PASS** | `verify-failure-class-history.ndjson` confirmed ` M` (modified, unstaged) |

## Decision

**HOLD_WITH_BLOCKERS**

Criteria 1 and 5 not met. Containment is complete (zero secret literals in HEAD), but provider-side token rotation requires manual operator action.

## Blocker Matrix

| # | ID | Reason | Owner | Next Action |
|---|-----|--------|-------|-------------|
| 1 | GAP-OP-1195 | Sonarr API key rotation — no v3 API endpoint, no SSH access configured | @ronny | Manual: Sonarr UI > Settings > General > Regenerate API Key |
| 2 | GAP-OP-1196 | Radarr API key rotation — no v3 API endpoint, no SSH access configured | @ronny | Manual: Radarr UI > Settings > General > Regenerate API Key |
| 3 | GAP-OP-1197 | Printavo token rotation — SaaS, requires web UI login | @ronny | Manual: printavo.com > Account > API Settings > Regenerate |

# W79-T0 Rotation Receipt

**Date:** 2026-02-28
**Control Loop:** LOOP-W79-T0-SECURITY-EMERGENCY-20260228

---

## Rotation Status: HOLD_WITH_BLOCKERS

### Blocker Summary

| # | Credential | Gap ID | Blocker | Unblock Action |
|---|-----------|--------|---------|----------------|
| 1 | Sonarr API Key | GAP-OP-1195 | No v3 API endpoint for key reset; SSH not configured to 192.168.1.209 | Manual: Sonarr UI > Settings > General > Regenerate API Key, then update secrets.yml |
| 2 | Radarr API Key | GAP-OP-1196 | Same as above | Manual: Radarr UI > Settings > General > Regenerate API Key, then update secrets.yml |
| 3 | Printavo Token | GAP-OP-1197 | Printavo is a SaaS — token regeneration requires web UI login | Manual: printavo.com > Account > API Settings > Regenerate token |

### Rotation Attempts

| Credential | Method | Result | Timestamp |
|-----------|--------|--------|-----------|
| Sonarr | `POST /api/v3/system/reset/apikey` | 404 / empty — endpoint does not exist | 2026-02-28T09:20Z |
| Radarr | `POST /api/v3/system/reset/apikey` | 404 / empty — endpoint does not exist | 2026-02-28T09:20Z |
| Sonarr | SSH `ronny@192.168.1.209` | `Permission denied (publickey)` — no SSH key configured | 2026-02-28T09:21Z |
| Printavo | N/A — SaaS, no API rotation endpoint | Not attempted | — |

### Risk Assessment

- All 3 credentials are for **internal/private services** (local LAN or private SaaS account)
- The workbench repo is **private** on both GitHub (`hypnotizedent/workbench`) and local Gitea
- Exposure window: from first commit of the file to containment (this wave)
- Practical risk: LOW (private repos, internal network services)
- **Containment (removing from tracked files) reduces future risk to zero**
- **Rotation remains recommended** to invalidate any historical exposure via repo access

### Manual Rotation Steps (for operator)

**Sonarr (http://192.168.1.209:8989):**
1. Navigate to Settings > General > Security
2. Click "Regenerate" next to API Key
3. Copy new key to `agents/media/config/secrets.yml` (gitignored) as `SONARR_API_KEY`
4. Restart recyclarr container if running

**Radarr (http://192.168.1.209:7878):**
1. Navigate to Settings > General > Security
2. Click "Regenerate" next to API Key
3. Copy new key to `agents/media/config/secrets.yml` (gitignored) as `RADARR_API_KEY`
4. Restart recyclarr container if running

**Printavo (printavo.com):**
1. Log in as ronny@mintprints.com
2. Navigate to Account > API Settings
3. Regenerate API token
4. Script is archived — update only if reactivation is planned

---

*No secret values printed in this receipt.*

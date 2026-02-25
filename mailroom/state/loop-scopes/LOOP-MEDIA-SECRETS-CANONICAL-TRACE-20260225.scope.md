---
loop_id: LOOP-MEDIA-SECRETS-CANONICAL-TRACE-20260225
created: 2026-02-25
status: closed
owner: "@ronny"
scope: media
priority: medium
objective: Canonical trace and normalization of all media-stack secret dependencies, migrate runway contracts from legacy media-stack project to infrastructure/prod canonical paths, add D224 media-secrets-canonical-lock gate
---

# Loop Scope: LOOP-MEDIA-SECRETS-CANONICAL-TRACE-20260225

## Objective

Canonical trace and normalization of all media-stack secret dependencies, migrate runway contracts from legacy media-stack project to infrastructure/prod canonical paths, add D224 media-secrets-canonical-lock gate

## Gaps

| Gap | Description | Status |
|-----|-------------|--------|
| GAP-OP-904 | Unprovisioned media secrets (AUTOPULSE_PASSWORD, REAL_DEBRID_API_KEY, LASTFM_API_KEY, LASTFM_SECRET, JELLYFIN_API_KEY, SPOTIFY_CLIENT_ID, SPOTIFY_CLIENT_SECRET, NAVIDROME_USERNAME, NAVIDROME_PASSWORD) | open — deferred to provisioning phase |
| GAP-OP-905 | Legacy runway contract drift (stack_defaults pointed to media-stack project) | fixed — D224 + contract normalization |

## Deliverables

1. **secrets.runway.contract.yaml** — stack_defaults migrated from `media-stack:/` to `infrastructure:/spine/vm-infra/media-stack/{download|streaming}`, stack_key_overrides for compose aliases, key_overrides for all canonical media keys
2. **secrets.namespace.policy.yaml** — 9 media keys moved from planned to enforced (key_path_overrides), HUNTARR keys added
3. **D224 media-secrets-canonical-lock** — new gate (4 checks: compose var registration, canonical routing, stack defaults, SSH target parity), wired into media domain profile + topology + agent profile
4. **Verification** — secrets 11/11 PASS, media 10/10 PASS, core 15/15 PASS

## Outcome

GAP-OP-905 CLOSED. GAP-OP-904 remains OPEN (provisioning deferred — keys registered in policy but not yet in Infisical). Loop objective achieved: canonical trace complete, contract normalized, regression gate active.

---
loop_id: LOOP-MEDIA-QB-AUTH-RECONCILE-20260226-20260226
created: 2026-02-26
status: closed
owner: "@ronny"
scope: media
priority: high
objective: Reconcile qB auth: fix Infisical/runtime password mismatch, collect governed mutation receipts, correct route narrative
---

# Loop Scope: LOOP-MEDIA-QB-AUTH-RECONCILE-20260226-20260226

## Objective

Reconcile qB auth: fix Infisical/runtime password mismatch, collect governed mutation receipts, correct route narrative

## Phases
- P0: Diagnose qB auth state
- P1: Fix password and re-probe
- P2: Verify and close

## Success Criteria
- qB login via Infisical creds succeeds
- Arr clients confirmed host=qbittorrent port=8081

## Definition Of Done
- Corrected return package delivered

## Completion Record

- **Closed:** 2026-02-26
- **Root cause:** qBittorrent anti-brute-force IP ban (HTTP 403) triggered by earlier failed probe attempts; password was already correct in both runtime and Infisical
- **Fix:** Container restart to clear in-memory ban list; permanent password confirmed persisted in qBittorrent.conf PBKDF2 hash

### Mutation Run Keys

| Action | Run Key |
|--------|---------|
| Loop create | `CAP-20260226-003032__loops.create__Rmvpx25816` |
| Auth probe (PASS) | `CAP-20260226-003413__secrets.exec__Rek0x77438` |
| verify.pack.run media (16/16) | `CAP-20260226-003434__verify.pack.run__Rskwr83758` |
| verify.pack.run secrets (11/11) | `CAP-20260226-003455__verify.pack.run__R4gjp95659` |

### Probe Output Summary

```
radarr: qbit enabled=True host=qbittorrent port=8081 user=admin category=None priority=2
sonarr: qbit enabled=True host=qbittorrent port=8081 user=admin category=None priority=2
lidarr: qbit enabled=True host=qbittorrent port=8081 user=admin category=None priority=2
qbittorrent: login OK web_ui_username=admin
RESULT: PASS
```

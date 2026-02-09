# LOOP-DEV-TOOLS-GITEA-STANDARDIZATION-20260209

> **Status:** open
> **Owner:** @ronny
> **Created:** 2026-02-09
> **Severity:** medium

---

## Executive Summary

Standardize Gitea as canonical origin for agentic-spine and workbench repos. GitHub becomes a push mirror. Close governance gaps: automated app-level backups, durable mirror token, CI workflow on Gitea Actions, and monitoring coverage.

---

## Decisions (Locked)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Canonical origin | Gitea (git.ronny.works) | Self-hosted, full control, Authentik SSO |
| GitHub role | Push mirror | Public visibility, external collaboration |
| CI system | Gitea Actions | Runner already deployed on VM 206 (idle) |

---

## Phases

| Phase | Scope | Dependency | Status |
|-------|-------|------------|--------|
| P0 | Gap registration + loop scope + JSONL | None | **COMPLETE** |
| P1 | Backup script + inventory entry | SSH to dev-tools | **COMPLETE** |
| P2 | CI workflow + D50 drift gate | None | **COMPLETE** |
| P3 | GitHub PAT replacement (manual) | Browser for PAT generation | Deferred |
| P4 | Remote cutover: swap origin on MacBook (both repos) | P3 done | **DONE** |
| P5 | Deploy backup cron on dev-tools + NAS rsync validation | SSH to dev-tools + NAS reachable | **DONE** |
| P6 | Authentik SSO browser test + closeout | Browser | Deferred |

---

## P0: Governance Artifacts

### Gaps Registered (GAP-OP-050 through GAP-OP-055)

| Gap | Severity | Description |
|-----|----------|-------------|
| GAP-OP-050 | HIGH | No automated backup cron for gitea dump + pg_dump to NAS |
| GAP-OP-051 | HIGH | No app-gitea entry in backup.inventory.yaml |
| GAP-OP-052 | MEDIUM | Push mirror OAuth token (gho_*) will expire — need durable PAT |
| GAP-OP-053 | MEDIUM | No CI/CD workflow on Gitea Actions (runner idle) |
| GAP-OP-054 | LOW | No Authentik SSO browser test documented |
| GAP-OP-055 | LOW | No Gitea-specific monitoring beyond HTTP health probe |

---

## P1: Backup Script

Staged at `ops/staged/dev-tools/gitea-backup.sh`, following the vaultwarden pattern:

- `docker exec gitea gitea dump` -> zip
- `docker exec gitea-postgres pg_dump` -> gzip
- rsync to NAS `/volume1/backups/apps/gitea/`
- Retention: 7 daily on NAS
- Cron: 02:55 daily (after vaultwarden 02:45, infisical 02:50)
- Staged first; cron deployed in P5

Backup inventory entry: `app-gitea` added to `backup.inventory.yaml`.
Backup runbook note added to `GITEA_BACKUP_RESTORE.md`.

---

## P2: CI Workflow + D50

### CI Workflow

`.gitea/workflows/verify.yml`:
- Trigger: push to main, pull_request
- Runner: ubuntu-latest
- Job: run `surfaces/verify/drift-gate.sh`

### D50 Drift Gate

`surfaces/verify/d50-gitea-ci-workflow-lock.sh`:
- Validates `.gitea/workflows/verify.yml` exists in repo
- Validates workflow references `drift-gate.sh`

---

## P3: GitHub PAT Replacement (Deferred)

- Generate classic PAT (repo scope) at github.com/settings/tokens
- Store in Infisical at `/spine/vm-infra/gitea/GITHUB_PUSH_MIRROR_TOKEN`
- Update Gitea push mirror config via API
- Add to `secrets.namespace.policy.yaml`

---

## P4: Remote Cutover — DONE

On MacBook (both repos):
```
git remote rename origin github
git remote rename gitea origin
git branch --set-upstream-to=origin/main main
```

Both agentic-spine and workbench now have `origin`=Gitea, `github`=GitHub.
`git push` defaults to Gitea; `git push github main` for explicit GitHub push.

Note: P3 (PAT replacement) still needed for durable mirror token, but the cutover
is independent — existing OAuth mirror works, and the rename is local + reversible.

---

## P5: Deploy Backup Cron — DONE

- SCP `gitea-backup.sh` to dev-tools `/usr/local/bin/` — **DONE**
- Install cron: `55 2 * * * /usr/local/bin/gitea-backup.sh` — **DONE**
- Generated SSH key (`gitea-backup@dev-tools`) on VM 206, added to NAS `ronadmin` authorized_keys — **DONE**
- Fixed script: `-u git` for gitea dump (root rejected by Gitea), `NAS_USER="ronadmin"` — **DONE**
- Manual test: gitea dump (3.8M) + pg_dump (80K) → NAS `/volume1/backups/apps/gitea/` — **VERIFIED**

---

## P6: Closeout (Deferred)

- Authentik SSO browser test
- Verify `backup.status` shows app-gitea OK
- Verify push mirror works with new PAT
- Close all 6 gaps
- Close loop

---

## Success Criteria

| Criteria | Validation |
|----------|------------|
| `git remote -v` shows origin = Gitea on both repos | After P4 |
| Push to main triggers Gitea Actions CI | After P2 deployed |
| `backup.status` shows app-gitea OK | After P5 |
| All 6 gaps marked fixed | After P6 |
| `spine.verify` 50/50 PASS | After P2 (D50 added) |

---

## Non-Goals

- Do NOT migrate additional repos beyond agentic-spine + workbench (future loop)
- Do NOT enable Gitea container registry (future loop)
- Do NOT set up branch protection rules (future loop)
- Do NOT add Gitea Prometheus metrics endpoint (future loop)

---

_Scope document created by: Opus 4.6_
_Created: 2026-02-09_

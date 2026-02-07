# Media Stack Architecture Phase A Playbook

| Field | Value |
|---|---|
| Loop | `LOOP-MEDIA-STACK-ARCH-20260208` |
| Phase | `A` |
| Scope | Move remaining high-write SQLite/log DBs off NFS to local disk |
| Blocker | RCA 24h stability gate (~`2026-02-08T19:00:00Z`) |
| Primary Goal | Reduce VM 201 iowait by removing write-heavy DB/log churn from NFS |

## Preflight (Read-Only)

```bash
./bin/ops cap run infra.hypervisor.identity
ssh media-stack 'hostname; uptime'
ssh media-stack 'findmnt -t nfs4 | egrep "/mnt/docker|/mnt/media"'
ssh media-stack 'df -h /opt /opt/appdata /mnt/docker /mnt/media'
ssh media-stack 'docker ps --format "table {{.Names}}\t{{.Status}}"'
ssh media-stack 'vmstat 1 5'
```

## Target Files (From P0 Discovery)

- `/mnt/docker/volumes/radarr/config/logs.db`
- `/mnt/docker/volumes/prowlarr/config/logs.db`
- `/mnt/docker/volumes/jellyfin/config/data/introskipper.db`
- `/mnt/docker/volumes/trailarr/trailarr.db`
- `/mnt/docker/volumes/posterizarr/database/*.db`

## Execution Pattern (Per Service)

```bash
# Example: radarr logs.db
ssh media-stack 'docker stop radarr'
ssh media-stack 'mkdir -p /opt/appdata/radarr'
ssh media-stack 'mv /mnt/docker/volumes/radarr/config/logs.db /opt/appdata/radarr/logs.db'
ssh media-stack 'ln -sfn /opt/appdata/radarr/logs.db /mnt/docker/volumes/radarr/config/logs.db'
ssh media-stack 'chown -R 1000:1000 /opt/appdata/radarr'
ssh media-stack 'docker start radarr'
```

Repeat the same stop/move/symlink/start sequence for each target service.

## Verification (After Each Service)

```bash
ssh media-stack 'ls -l /mnt/docker/volumes/radarr/config/logs.db'
ssh media-stack 'test -f /opt/appdata/radarr/logs.db && echo OK'
ssh media-stack 'docker ps --filter name=radarr --format "{{.Names}} {{.Status}}"'
```

## Phase-A Exit Validation

```bash
ssh media-stack 'find /mnt/docker/volumes -type f \( -name "*.db" -o -name "logs.db" \) | egrep "radarr|prowlarr|jellyfin|trailarr|posterizarr"'
ssh media-stack 'vmstat 1 10'
ssh media-stack 'docker ps --format "table {{.Names}}\t{{.Status}}"'
```

Target outcome: sustained iowait trend reduction versus P0 baseline and no unhealthy containers.

## Rollback

```bash
# Example rollback for radarr
ssh media-stack 'docker stop radarr'
ssh media-stack 'rm -f /mnt/docker/volumes/radarr/config/logs.db'
ssh media-stack 'cp -a /opt/appdata/radarr/logs.db /mnt/docker/volumes/radarr/config/logs.db'
ssh media-stack 'docker start radarr'
```

## Follow-On (Phase B)

If iowait remains high after Phase A, proceed to Phase B (dedicated local data disk + config volume relocation) per loop scope.

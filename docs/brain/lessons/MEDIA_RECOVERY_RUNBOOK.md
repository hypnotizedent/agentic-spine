# Media Stack Recovery Runbook

> **Status:** authoritative
> **Provenance:** extracted from `ronny-ops/media-stack/docs/runbooks/RUNBOOK_RECOVER.md`
> **Extraction loop:** LOOP-MEDIA-LEGACY-EXTRACTION-20260211
> **Last verified:** 2026-02-11
> **Topology:** VM 209 (download-stack), VM 210 (streaming-stack)

When to use: media services are down, 502 errors on public URLs, or after unexpected reboot.

---

## Quick Recovery (Most Cases)

NFS mount issues are the most common cause. Try this first:

```bash
# For download-stack (VM 209)
ssh download-stack 'sudo mount -a && sudo docker compose -f /opt/stacks/download-stack/docker-compose.yml restart'

# For streaming-stack (VM 210)
ssh streaming-stack 'sudo mount -a && sudo docker compose -f /opt/stacks/streaming-stack/docker-compose.yml restart'

# Verify
ssh download-stack 'docker ps --format "table {{.Names}}\t{{.Status}}" | head -25'
ssh streaming-stack 'docker ps --format "table {{.Names}}\t{{.Status}}"'
```

If the above doesn't work, proceed with the full procedure.

---

## Full Recovery: VM 209 (download-stack)

### Step 1: Verify VM is running

```bash
ssh pve 'qm status 209'
# Expected: status: running

# If stopped:
ssh pve 'qm start 209'
sleep 60
```

### Step 2: Verify SSH access

```bash
ssh -o ConnectTimeout=10 download-stack 'echo ok'

# If SSH fails, try LAN direct:
ssh -o ConnectTimeout=10 ubuntu@192.168.1.209 'echo ok'

# If still failing, hard reset:
ssh pve 'qm reset 209'
sleep 90
```

### Step 3: Verify NFS mounts

```bash
ssh download-stack 'mount | grep nfs'
# Expected:
# 192.168.1.184:/tank/docker/download-stack on /mnt/docker type nfs4 ...
# 192.168.1.184:/media on /mnt/media type nfs4 ...

# If missing:
ssh download-stack 'sudo mount -a'

# If mount fails, check NFS server on pve:
ssh pve 'systemctl status nfs-server && exportfs -v'
```

### Step 4: Verify config directories are populated

```bash
ssh download-stack 'ls /mnt/docker/volumes/radarr/config/ | head -3'
# If empty → NFS didn't mount properly. Go back to Step 3.
```

### Step 5: Restart containers

```bash
ssh download-stack 'cd /opt/stacks/download-stack && sudo docker compose up -d'
```

### Step 6: Verify services

```bash
ssh download-stack 'docker ps --filter health=unhealthy --format "{{.Names}}"'
# Expected: empty (no unhealthy containers)

# Spot-check Radarr
ssh download-stack 'curl -sf http://localhost:7878/ping'
```

---

## Full Recovery: VM 210 (streaming-stack)

### Step 1–4: Same pattern as VM 209

Replace `download-stack` with `streaming-stack`, `209` with `210`, `192.168.1.209` with `192.168.1.210`.

NFS expected:
```
192.168.1.184:/tank/docker/streaming-stack on /mnt/docker type nfs4 ...
192.168.1.184:/media on /mnt/media type nfs4 ... (ro)
```

Note: `/mnt/media` is **read-only** on VM 210 — this is correct.

### Step 5: Restart containers

```bash
ssh streaming-stack 'cd /opt/stacks/streaming-stack && sudo docker compose up -d'
```

### Step 6: Verify Jellyfin specifically

```bash
# Health endpoint
ssh streaming-stack 'curl -sf http://localhost:8096/health'
# Expected: Healthy

# Library accessible
ssh streaming-stack 'ls /mnt/media/movies/ | wc -l'
# Expected: 1200+
```

---

## Verify Public URLs

```bash
curl -sf -o /dev/null -w "%{http_code}" https://jellyfin.ronny.works
curl -sf -o /dev/null -w "%{http_code}" https://requests.ronny.works
curl -sf -o /dev/null -w "%{http_code}" https://music.ronny.works
# Expected: 200, 301, 302, or 307
```

If 502 persists, the Cloudflare tunnel on infra-core may need a restart:
```bash
ssh infra-core 'sudo docker restart cloudflared'
sleep 10
```

---

## Container Restart Order (if needed individually)

On VM 209:
1. Prowlarr (indexer foundation)
2. Radarr, Sonarr, Lidarr (depend on Prowlarr)
3. SABnzbd, qBittorrent (download clients)
4. Bazarr is on VM 210, not here
5. Supporting services (recyclarr, unpackerr, etc.)

On VM 210:
1. Jellyfin (media server)
2. Bazarr (subtitles — needs Radarr/Sonarr on VM 209 reachable)
3. Jellyseerr (request UI — needs Jellyfin + Radarr/Sonarr)
4. Supporting services (navidrome, wizarr, spotisub, etc.)

---

## Escalation

If recovery fails after all steps:

1. Proxmox console: check VM errors in pve web UI
2. Docker logs: `ssh <vm> 'docker logs <container> --tail 100'`
3. System journal: `ssh <vm> 'journalctl -xe --no-pager | tail -50'`
4. ZFS health: `ssh pve 'zpool status tank'`
5. NFS server: `ssh pve 'systemctl status nfs-server && exportfs -v'`

---

## Prevention

| Measure | Status |
|---------|--------|
| NFS uses LAN IPs (192.168.1.184), not Tailscale | Verified |
| Docker systemd drop-in requires NFS mounts | Verified |
| fstab uses `x-systemd.requires=network-online.target` | Verified |
| SQLite DBs on local ext4, not NFS | Verified |
| Prometheus node-exporter on both VMs | Active |
| Uptime Kuma monitoring public URLs | Active |

---

## Cross-References

| Document | Relationship |
|----------|-------------|
| `MEDIA_CRITICAL_RULES.md` | Safety constraints (VM reset procedure) |
| `MEDIA_PIPELINE_ARCHITECTURE.md` | Service inventory and boot chain |
| `MEDIA_STACK_LESSONS.md` | NFS + SQLite patterns |
| `receipts/audits/MEDIA_STACK_E2E_TRACE_20260210.md` | Post-split verification |

---

_Extracted: 2026-02-11_
_Loop: LOOP-MEDIA-LEGACY-EXTRACTION-20260211_

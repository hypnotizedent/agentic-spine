# Phase 2 Playbook: NFS + Local Storage Preparation

> **Loop:** LOOP-MEDIA-STACK-SPLIT-20260208
> **Phase:** 2 of 6
> **Prereqs:** Phase 1 complete (VM 209 + VM 210 provisioned and ready)
> **Targets:** pve (ZFS/NFS server), download-stack (VM 209), streaming-stack (VM 210), media-stack (VM 201, source)

---

## Step 1: Create ZFS Datasets on pve

```bash
# SSH to pve
ssh root@pve

# Create new datasets (inherit compression/recordsize from tank/docker parent)
zfs create tank/docker/download-stack
zfs create tank/docker/streaming-stack

# Create volumes subdirs matching existing media-stack layout
mkdir -p /tank/docker/download-stack/volumes
mkdir -p /tank/docker/streaming-stack/volumes

# Verify
zfs list -r tank/docker -o name,mountpoint,used,avail
```

**Expected:** Three datasets under `tank/docker/` — media-stack (existing), download-stack (new), streaming-stack (new).

---

## Step 2: Copy Container Volumes from media-stack

### Inventory first — check what exists on media-stack dataset:

```bash
# On pve — list all service volume dirs
ls -la /tank/docker/media-stack/volumes/
```

### Download stack services (→ tank/docker/download-stack/volumes/):

```bash
# Copy each service's config dir
for svc in prowlarr flaresolverr recyclarr sabnzbd qbittorrent unpackerr \
           radarr sonarr lidarr soularr swaparr-radarr swaparr-sonarr \
           swaparr-lidarr trailarr posterizarr decypharr huntarr autopulse \
           crosswatch crowdsec; do
  if [ -d "/tank/docker/media-stack/volumes/$svc" ]; then
    echo "Copying $svc..."
    cp -r "/tank/docker/media-stack/volumes/$svc" "/tank/docker/download-stack/volumes/$svc"
  else
    echo "SKIP: $svc (not found on media-stack)"
    mkdir -p "/tank/docker/download-stack/volumes/$svc"
  fi
done

# tdarr has non-standard layout (server, configs, logs subdirs)
if [ -d "/tank/docker/media-stack/volumes/tdarr" ]; then
  cp -r "/tank/docker/media-stack/volumes/tdarr" "/tank/docker/download-stack/volumes/tdarr"
else
  mkdir -p /tank/docker/download-stack/volumes/tdarr/{server,configs,logs}
fi
```

### Streaming stack services (→ tank/docker/streaming-stack/volumes/):

```bash
for svc in jellyfin navidrome jellyseerr bazarr wizarr spotisub subgen homarr; do
  if [ -d "/tank/docker/media-stack/volumes/$svc" ]; then
    echo "Copying $svc..."
    cp -r "/tank/docker/media-stack/volumes/$svc" "/tank/docker/streaming-stack/volumes/$svc"
  else
    echo "SKIP: $svc (not found on media-stack)"
    mkdir -p "/tank/docker/streaming-stack/volumes/$svc"
  fi
done

# jellyfin has cache dir too
mkdir -p /tank/docker/streaming-stack/volumes/jellyfin/cache
```

### Set ownership:

```bash
chown -R 1000:1000 /tank/docker/download-stack/volumes/
chown -R 1000:1000 /tank/docker/streaming-stack/volumes/
```

---

## Step 3: Add NFS Exports on pve

### Check existing exports pattern first:

```bash
cat /etc/exports
```

### Add new exports (match existing media-stack options):

```bash
# Append to /etc/exports — adjust subnet/options to match existing style
cat >> /etc/exports << 'EXPORTS'

# Download stack (VM 209) — rw for configs, rw for media
/tank/docker/download-stack 192.168.12.209/32(rw,no_subtree_check,no_root_squash)
/media 192.168.12.209/32(rw,no_subtree_check,no_root_squash)

# Streaming stack (VM 210) — rw for configs, ro for media
/tank/docker/streaming-stack 192.168.12.210/32(rw,no_subtree_check,no_root_squash)
/media 192.168.12.210/32(ro,no_subtree_check,no_root_squash)
EXPORTS

# Reload NFS exports
exportfs -ra
exportfs -v
```

**Note:** The export client IP uses the LAN IP (192.168.12.x), NOT the Tailscale IP. NFS traffic stays on the LAN for performance.

---

## Step 4: Configure fstab on Both VMs

### VM 209 (download-stack):

```bash
ssh ubuntu@download-stack

# Create mount points
sudo mkdir -p /mnt/docker /mnt/media /opt/appdata

# Add fstab entries (use pve LAN IP 192.168.12.191)
sudo tee -a /etc/fstab << 'FSTAB'

# NFS mounts from pve (ZFS datasets)
192.168.12.191:/tank/docker/download-stack /mnt/docker nfs4 hard,intr,nfsvers=4,x-systemd.automount,x-systemd.requires=tailscaled.service 0 0
192.168.12.191:/media /mnt/media nfs4 hard,intr,nfsvers=4,x-systemd.automount,x-systemd.requires=tailscaled.service 0 0
FSTAB

# Mount
sudo mount -a

# Verify
df -h /mnt/docker /mnt/media
ls /mnt/docker/volumes/
```

### VM 210 (streaming-stack):

```bash
ssh ubuntu@streaming-stack

sudo mkdir -p /mnt/docker /mnt/media /opt/appdata

sudo tee -a /etc/fstab << 'FSTAB'

# NFS mounts from pve (ZFS datasets)
192.168.12.191:/tank/docker/streaming-stack /mnt/docker nfs4 hard,intr,nfsvers=4,x-systemd.automount,x-systemd.requires=tailscaled.service 0 0
192.168.12.191:/media /mnt/media nfs4 ro,hard,intr,nfsvers=4,x-systemd.automount,x-systemd.requires=tailscaled.service 0 0
FSTAB

sudo mount -a
df -h /mnt/docker /mnt/media
ls /mnt/docker/volumes/
```

**Critical:** The `/mnt/media` mount on VM 210 is **read-only** (`ro`).

---

## Step 5: Systemd Docker Drop-in (NFS dependency)

### VM 209 (download-stack):

```bash
ssh ubuntu@download-stack

sudo mkdir -p /etc/systemd/system/docker.service.d
sudo tee /etc/systemd/system/docker.service.d/nfs-dependency.conf << 'DROPIN'
[Unit]
After=mnt-docker.mount mnt-media.mount
Requires=mnt-docker.mount mnt-media.mount
DROPIN

sudo systemctl daemon-reload
```

### VM 210 (streaming-stack):

```bash
ssh ubuntu@streaming-stack

sudo mkdir -p /etc/systemd/system/docker.service.d
sudo tee /etc/systemd/system/docker.service.d/nfs-dependency.conf << 'DROPIN'
[Unit]
After=mnt-docker.mount mnt-media.mount
Requires=mnt-docker.mount mnt-media.mount
DROPIN

sudo systemctl daemon-reload
```

---

## Step 6: Copy /opt/appdata Databases from VM 201

### Inventory on media-stack:

```bash
ssh media@media-stack "sudo ls -laR /opt/appdata/"
```

### Expected DB layout (from MEDIA_STACK_LESSONS.md):

| Service | Main DB | Logs/Secondary | Total |
|---------|---------|----------------|-------|
| radarr | radarr.db (268MB) | logs.db (90MB) | ~358MB |
| sonarr | sonarr.db (4MB) | logs.db (2.2MB) | ~6MB |
| lidarr | lidarr.db (411MB) | — | ~411MB |
| prowlarr | prowlarr.db (29MB) | logs.db (3.6MB) | ~33MB |
| jellyfin | jellyfin.db (148MB) | introskipper.db (1.4MB) | ~149MB |
| trailarr | — | trailarr.db + logs.db (~512KB) | ~1MB |
| posterizarr | — | 5 DBs (~250KB) | ~1MB |

### Copy to download-stack (radarr, sonarr, lidarr, prowlarr, trailarr, posterizarr):

```bash
# From macbook, use pve as jump host if direct media-stack SSH fails
# Option A: direct scp
for svc in radarr sonarr lidarr prowlarr trailarr posterizarr; do
  ssh media@media-stack "sudo tar -C /opt/appdata -cf - $svc" | \
    ssh ubuntu@download-stack "sudo tar -C /opt/appdata -xf -"
done

# Option B: via pve jump host
for svc in radarr sonarr lidarr prowlarr trailarr posterizarr; do
  ssh -J root@pve media@media-stack "sudo tar -C /opt/appdata -cf - $svc" | \
    ssh -J root@pve ubuntu@download-stack "sudo tar -C /opt/appdata -xf -"
done
```

### Copy to streaming-stack (jellyfin):

```bash
ssh media@media-stack "sudo tar -C /opt/appdata -cf - jellyfin" | \
  ssh ubuntu@streaming-stack "sudo tar -C /opt/appdata -xf -"
```

### Set ownership on both VMs:

```bash
ssh ubuntu@download-stack "sudo chown -R 1000:1000 /opt/appdata/"
ssh ubuntu@streaming-stack "sudo chown -R 1000:1000 /opt/appdata/"
```

---

## Step 7: Recreate Symlinks on New VMs

### On download-stack:

```bash
ssh ubuntu@download-stack << 'SCRIPT'
# radarr
sudo ln -sfn /opt/appdata/radarr/radarr.db /mnt/docker/volumes/radarr/config/radarr.db
sudo ln -sfn /opt/appdata/radarr/logs.db /mnt/docker/volumes/radarr/config/logs.db

# sonarr
sudo ln -sfn /opt/appdata/sonarr/sonarr.db /mnt/docker/volumes/sonarr/config/sonarr.db
sudo ln -sfn /opt/appdata/sonarr/logs.db /mnt/docker/volumes/sonarr/config/logs.db

# lidarr
sudo ln -sfn /opt/appdata/lidarr/lidarr.db /mnt/docker/volumes/lidarr/config/lidarr.db

# prowlarr
sudo ln -sfn /opt/appdata/prowlarr/prowlarr.db /mnt/docker/volumes/prowlarr/config/prowlarr.db
sudo ln -sfn /opt/appdata/prowlarr/logs.db /mnt/docker/volumes/prowlarr/config/logs.db

# trailarr
sudo ln -sfn /opt/appdata/trailarr/trailarr.db /mnt/docker/volumes/trailarr/config/trailarr.db
sudo ln -sfn /opt/appdata/trailarr/logs.db /mnt/docker/volumes/trailarr/config/logs.db

# posterizarr (5 DBs — enumerate after inventory check)
# Will fill in exact filenames after ls on media-stack /opt/appdata/posterizarr/
SCRIPT
```

### On streaming-stack:

```bash
ssh ubuntu@streaming-stack << 'SCRIPT'
# jellyfin
sudo ln -sfn /opt/appdata/jellyfin/jellyfin.db /mnt/docker/volumes/jellyfin/config/data/jellyfin.db
sudo ln -sfn /opt/appdata/jellyfin/introskipper.db /mnt/docker/volumes/jellyfin/config/data/introskipper.db
SCRIPT
```

**Note:** The exact DB file paths inside the config dirs may vary — we need to check the actual symlink layout on VM 201 before executing. The symlink targets above are based on typical Linuxserver.io container layouts, but the actual paths will be confirmed during execution.

---

## Verification

```bash
# VM 209
ssh ubuntu@download-stack << 'CHECK'
echo "=== NFS Mounts ==="
df -h /mnt/docker /mnt/media
echo "=== Volume Dirs ==="
ls /mnt/docker/volumes/ | wc -l
echo "=== appdata ==="
ls -la /opt/appdata/
echo "=== Symlinks ==="
find /mnt/docker/volumes -type l -ls 2>/dev/null
echo "=== Docker systemd ==="
systemctl show docker.service | grep -E "^(After|Requires)=" | head -5
CHECK

# VM 210
ssh ubuntu@streaming-stack << 'CHECK'
echo "=== NFS Mounts ==="
df -h /mnt/docker /mnt/media
echo "=== Volume Dirs ==="
ls /mnt/docker/volumes/ | wc -l
echo "=== appdata ==="
ls -la /opt/appdata/
echo "=== Symlinks ==="
find /mnt/docker/volumes -type l -ls 2>/dev/null
echo "=== Docker systemd ==="
systemctl show docker.service | grep -E "^(After|Requires)=" | head -5
echo "=== Media RO check ==="
touch /mnt/media/.writetest 2>&1 || echo "PASS: media is read-only"
CHECK
```

**Acceptance criteria:**
- [ ] NFS mounts visible on both VMs
- [ ] All service volume dirs present
- [ ] /opt/appdata DBs present and owned by 1000:1000
- [ ] Symlinks point from NFS config dirs → /opt/appdata
- [ ] Docker systemd requires NFS mounts
- [ ] VM 210 /mnt/media is read-only
- [ ] `docker compose config` succeeds in both compose dirs (volumes resolve)

---

## Rollback

ZFS datasets are additive — no existing data modified. Rollback is simply:
```bash
# On pve
zfs destroy tank/docker/download-stack
zfs destroy tank/docker/streaming-stack
# Remove NFS export lines from /etc/exports
exportfs -ra
```

---

_Playbook created: 2026-02-08_
_Loop: LOOP-MEDIA-STACK-SPLIT-20260208_

# Media Stack Critical Rules

> **Status:** authoritative
> **Provenance:** extracted from legacy media source `media-stack/docs/reference/REF_CRITICAL_RULES.md` (commit `1ea9dfa`)
> **Extraction loop:** LOOP-MEDIA-LEGACY-EXTRACTION-20260211
> **Last verified:** 2026-02-11
> **Topology:** VM 209 (download-stack), VM 210 (streaming-stack)

Hard-won rules from production incidents. Breaking these causes outages.

---

## Rule 1: No Bulk Library Searches

**Never trigger `MissingMoviesSearch` on the entire Radarr library.** The R730XD cannot handle searching 1000+ movies simultaneously — NFS I/O saturates and the VM becomes unresponsive.

- **Safe:** Search specific movies by ID (max 10 at a time) via API or Huntarr (5 movies / 15 min cycle).
- **Unsafe:** Any "search all missing" action in Radarr/Sonarr/Lidarr UI or API.

Applies to VM 209 (download-stack) where all *arr services live.

---

## Rule 2: Trickplay is Permanently Banned

Trickplay (thumbnail strip generation) spawns background ffmpeg processes for every media file. On NFS-backed storage this creates catastrophic I/O storms (187+ load average observed).

**On VM 210 (streaming-stack):**
- Trickplay must remain disabled in all Jellyfin library `options.xml` files.
- `EnableTrickplayImageExtraction` must be `false` for Movies, TV Shows, and Collections.
- Library options files should be read-only (`chmod 444`) to prevent accidental re-enablement.
- If a Jellyfin update resets these: stop Jellyfin, fix XML, restore permissions, restart.

**Verification:**
```bash
ssh streaming-stack 'grep -i trickplay /mnt/docker/volumes/jellyfin/config/root/default/*/options.xml'
```

---

## Rule 3: No Chapter Image Extraction

Chapter image extraction runs ffmpeg against every movie file during library scans, competing with playback I/O.

**Incident:** Watching a movie while chapter extraction ran caused repeated buffering and eventually contributed to VM memory exhaustion.

**On VM 210 (streaming-stack):**
- `EnableChapterImageExtraction` must be `false` in all library `options.xml`.
- `ExtractChapterImagesDuringLibraryScan` must be `false`.

**Verification:**
```bash
ssh streaming-stack 'grep -iE "ChapterImage" /mnt/docker/volumes/jellyfin/config/root/default/*/options.xml'
```

---

## Rule 4: NFS Uses LAN IPs Only

**Never use Tailscale IPs for NFS mounts.** Hard NFS mounts over Tailscale cause D-state deadlocks when the tunnel flaps.

| VM | NFS Source IP | Correct |
|----|--------------|---------|
| download-stack (209) | 192.168.1.184 | LAN |
| streaming-stack (210) | 192.168.1.184 | LAN |

See `MEDIA_STACK_LESSONS.md` for the full NFS anti-pattern documentation.

---

## Rule 5: SQLite Databases Stay on Local Disk

All service databases (radarr.db, jellyfin.db, etc.) must live on local ext4 at `/opt/appdata/`, symlinked from NFS config paths. Running SQLite directly on NFS causes WAL corruption and database locks.

See `MEDIA_STACK_LESSONS.md` for the symlink pattern and per-service inventory.

---

## Rule 6: VM Recovery via Proxmox

If a media VM becomes unresponsive:

```bash
# download-stack (VM 209)
ssh pve 'qm reset 209'
sleep 90
ssh download-stack 'sudo mount -a && docker ps'

# streaming-stack (VM 210)
ssh pve 'qm reset 210'
sleep 90
ssh streaming-stack 'sudo mount -a && docker ps'
```

See `MEDIA_RECOVERY_RUNBOOK.md` for full procedure.

---

_Extracted: 2026-02-11_
_Loop: LOOP-MEDIA-LEGACY-EXTRACTION-20260211_

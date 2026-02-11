---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-11
scope: immich-operations
migrated_from: ronny-ops/immich/IMMICH_CONTEXT.md
parent_loop: LOOP-IMMICH-LEGACY-EXTRACTION-20260211
---

# Immich Operations Lessons

> **Service:** Immich (VM 203, immich-1)
> **Web UI:** http://immich-1:2283 (Tailscale) or http://192.168.1.203:2283 (LAN)
> **Library:** 135,412 assets (3TB) across 4 users

---

## THE RULE (Deduplication Governance)

```
KEEP = Most EXIF metadata + Oldest DateTimeOriginal
```

**Never** use Immich's built-in deduplication (it uses resolution — wrong criteria). THE RULE governs all duplicate decisions:
- Compare EXIF field count between duplicates
- Prefer the copy with the most metadata fields populated
- Tiebreaker: oldest `DateTimeOriginal` wins
- File size and resolution are NOT selection criteria

**Principle:** Tools surface data. Human decides. No auto-deletion.

---

## Infrastructure

| Component | Value |
|-----------|-------|
| VM ID | 203 |
| VM Name | immich |
| Tailscale hostname | immich-1 |
| Tailscale IP | 100.114.101.50 |
| LAN IP | 192.168.1.203 (target; see GAP-OP-094) |
| Cloud-init IP | 192.168.12.230 (old network; needs update) |
| RAM | 16 GB |
| CPU | 8 cores |
| OS | Ubuntu 24.04 LTS |
| Docker | 29.1.3 |
| Immich version | v2.4.1 |
| SSH user | `ronny` (non-standard; other VMs use `ubuntu`) |

### Containers

| Container | Purpose |
|-----------|---------|
| immich_server | Main API and web UI (port 2283) |
| immich_machine_learning | Face recognition, CLIP, OCR |
| immich_postgres | PostgreSQL database |
| immich_redis | Cache layer |

### ZFS Datasets (on pve host)

| Dataset | Size | Purpose |
|---------|------|---------|
| `tank/immich/photos` | 1.15TB | Photo library storage |
| `tank/immich/db` | 205K | Database overhead |

---

## User Accounts

| User | Email | Role | API Key Status |
|------|-------|------|---------------|
| Ronny Archive | hypnotizedent@gmail.com | Admin | Created (`IMMICH_API_KEY` in Infisical) |
| Mint Prints | mint@mintprints.com | User | Pending |
| Ronny Hantash | ronny@hantash.com | User | Pending |
| HYPNOTIZED | hypnotized@hypnotizedent.com | User | Pending |

### Creating User API Keys

1. Log in as the user at http://immich-1:2283
2. Account Settings -> API Keys -> Create
3. Store in Infisical `/spine/services/immich` as `USER_<NAME>_API_KEY`

### Admin API Usage

```bash
# Server statistics
curl -s -H "x-api-key: $IMMICH_API_KEY" \
  "http://immich-1:2283/api/server/statistics" | jq

# Job status
curl -s -H "x-api-key: $IMMICH_API_KEY" \
  "http://immich-1:2283/api/jobs" | jq

# Server ping (health check)
curl -sf http://immich-1:2283/api/server-info/ping
```

---

## Secrets (Infisical)

| Key | Infisical Path | Purpose |
|-----|---------------|---------|
| `IMMICH_API_KEY` | `/spine/services/immich` | Admin API access |
| `IMMICH_HYPNO_API_KEY` | `/spine/services/immich` | Hypno user API key |
| `IMMICH_HYPNO_PASSWORD` | `/spine/services/immich` | Hypno user password |
| `IMMICH_HYPNO_USER_ID` | `/spine/services/immich` | Hypno user ID |
| `IMMICH_MINT_API_KEY` | `/spine/services/immich` | Mint user API key |
| `IMMICH_SUDO_PASSWORD` | `/spine/services/immich` | VM sudo password |
| `DB_PASSWORD` | `/spine/services/immich` | PostgreSQL auth |

**Known issue:** Immich keys are duplicated between the `immich` and `infrastructure` Infisical projects. P5 secrets migration capabilities exist to resolve this (`secrets.p5.immich.copy_first.status`, `secrets.p5.immich.root_cleanup.status`).

---

## Known Camera Anomalies

| Camera | Issue | Action |
|--------|-------|--------|
| NIKON D50 | Clock resets to 2005-01-01 | Flag for manual review, do not auto-process |
| FUJIFILM X100 | Clock ~8 years behind | Flag for manual review |

These cameras produce photos with incorrect `DateTimeOriginal`. THE RULE still applies, but these files must be manually reviewed before any dedup decisions.

---

## Photo Management Workflow

Per the tooling plan, photo operations follow this pipeline:

1. **generate_manifest** — Extract EXIF metadata from all files into `manifest.csv`
2. **group_duplicates** — Group files by pHash (visual similarity) into `duplicate_groups.csv`
3. **flag_anomalies** — Flag D50/X100 photos and files missing `DateTimeOriginal` into `review_needed.csv`
4. **generate_summary** — Year/month breakdown into `LIBRARY_SUMMARY.md`
5. **Human reviews** all outputs
6. **Human decides** what to keep/fix/quarantine
7. **Human instructs** agent to execute decisions

**Tools we do NOT build:**
- No auto-keeper selection
- No auto-deletion scripts
- No filename-based logic

---

## Rebuild Guide (Disaster Recovery)

If VM 203 needs to be rebuilt from scratch:

### Prerequisites
- Proxmox VM: 8 cores, 16GB RAM, 50GB OS disk
- Ubuntu 24.04 LTS
- ZFS datasets on pve: `tank/immich/photos`, `tank/immich/db`

### Steps

1. Create VM in Proxmox (clone from template 9000 or manual install)
2. Install Docker + Docker Compose plugin
3. Create directory: `mkdir -p ~/immich && cd ~/immich`
4. Download official Immich compose and env files from https://immich.app/docs/install/docker-compose
5. Configure `.env`: set `DB_PASSWORD` (from Infisical), `UPLOAD_LOCATION=/mnt/immich/library`, `TZ=America/New_York`
6. Mount storage (NFS from pve or direct ZFS passthrough)
7. `docker compose up -d`
8. Verify all 4 containers are healthy: `docker compose ps`
9. Access UI at `http://<vm-ip>:2283`, create admin account
10. Save admin API key to Infisical
11. Install Tailscale: `curl -fsSL https://tailscale.com/install.sh | sh && sudo tailscale up`
12. Restore PostgreSQL from backup (see IMMICH_BACKUP_RESTORE.md)
13. Restore photo library from WD Portable backup
14. Verify asset count matches expected (135K+)

### Post-Rebuild Checklist

- [ ] All 4 containers running and healthy
- [ ] Web UI accessible
- [ ] Admin API key in Infisical
- [ ] Tailscale connected (hostname: immich-1)
- [ ] Storage mounted correctly
- [ ] Backup cron jobs registered
- [ ] Synology offsite sync configured

---

## Pending Items

- [ ] Configure ML settings (face recognition, CLIP, OCR)
- [ ] Set storage labels per user (separate upload folders)
- [ ] Create API keys for Mint, Ronny, Hypno users
- [ ] SanDisk SSD recovery (corrupt, contains Mint Prints + Hypnotized photos)
- [ ] MCP server implementation (10-tool AI photo management — spec in legacy, deferred)

---

## Related Spine Documents

| Document | Purpose |
|----------|---------|
| `docs/brain/lessons/IMMICH_BACKUP_RESTORE.md` | Backup topology and restore procedures |
| `docs/governance/IMMICH_LEGACY_EXTRACTION_MATRIX.md` | Extraction audit and decisions |
| `ops/bindings/backup.inventory.yaml` | VM-level backup targets |
| `ops/bindings/secrets.namespace.policy.yaml` | Immich secrets mapping |
| `ops/bindings/secrets.inventory.yaml` | Infisical project registry |

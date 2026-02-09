---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-08
scope: disaster-recovery
---

# Disaster Recovery Runbook

Purpose: document per-site failure scenarios, what breaks, recovery sequence, and
expected recovery times. Reference: `infra.placement.policy.yaml` for service placement.

## Site Inventory

| Site | Hosts | Critical Services |
|------|-------|-------------------|
| **Shop** (primary) | pve (R730XD), VMs 200-210 | cloudflared, pihole, infisical, vaultwarden, authentik, gitea, prometheus, grafana, jellyfin, all media services |
| **Home** | proxmox-home (Beelink), NAS (Synology) | home-assistant, NAS (offsite backup target), vaultwarden-home (decommissioned) |
| **Mobile** | MacBook | spine CLI (control plane), development |

## Scenario 1: Shop Site Down (Power/Network/Hardware Failure)

**Impact: CRITICAL** — all public services offline.

### What Breaks

| Service | Impact | Dependency Chain |
|---------|--------|-----------------|
| cloudflared | All `*.ronny.works` public URLs unreachable | CF tunnel dies |
| pihole | Shop DNS resolution fails | Devices fall back to ISP DNS |
| infisical | No new secret fetches from any site | SPOF — no replica |
| vaultwarden | Password manager inaccessible | Users lose access to credentials |
| authentik | SSO for all protected services fails | Forward auth dies |
| gitea | Code forge offline, CI stopped | Push mirrors to GitHub are stale |
| observability | No metrics/alerts/dashboards | Monitoring blind |
| media stack | Jellyfin, Sonarr, Radarr, etc. all offline | Download + streaming both down |
| ai services | Qdrant, AnythingLLM offline | RAG/AI workflows broken |

### Recovery Sequence

1. **Assess** — Check iDRAC (192.168.12.250) remotely if WAN is up. Check UPS status (APC 900VA, ~10-15 min runtime).
2. **If power outage**: Wait for power restoration. All VMs have `onboot=1`, pve auto-starts them.
3. **If hardware failure (single disk)**: ZFS pools are RAIDZ1 (tank) or mirror (boot). Replace failed disk, `zpool replace`. No data loss.
4. **If hardware failure (motherboard/total loss)**:
   - Restore pve from most recent vzdump on NAS (offsite copies exist for VMs 204-210).
   - Provision new Proxmox host, restore VMs from NAS: `qmrestore /path/to/vzdump.vma.zst <vmid>`.
   - Re-establish Tailscale node, update IPs in bindings if changed.
   - Priority order: infra-core (204) first (unlocks cloudflared, DNS, secrets, auth), then observability (205), then media (209, 210).
5. **Post-recovery**: Run `./bin/ops cap run spine.verify` and `backup.status` to confirm parity.

### Mitigation (Pre-Failure)

- vzdump runs daily at 02:00; critical VMs offsite-synced to NAS at 09:00.
- Home site NAS holds offsite vzdump copies for VMs 204-210 (not VM 200 due to size).

## Scenario 2: Home Site Down (Power/Network/Hardware Failure)

**Impact: LOW-MEDIUM** — offsite backups unavailable, home-assistant offline.

### What Breaks

| Service | Impact |
|---------|--------|
| NAS | Offsite backup target unreachable; no new offsite copies |
| home-assistant | Home automation offline (lights, sensors, automations) |
| proxmox-home | Home VMs unreachable (currently minimal workload) |

### What Continues Working

All shop services continue normally. Public URLs, DNS, secrets, media — all unaffected.
Spine CLI continues working from MacBook.

### Recovery Sequence

1. **Assess** — SSH to proxmox-home (100.103.99.62) or NAS (100.102.199.111) over Tailscale.
2. **If NAS offline**: offsite backup sync will fail silently (rsync cron). Monitor `backup.status` for NAS target errors.
3. **If proxmox-home offline**: home-assistant down. No shop impact.
4. **Post-recovery**: Run `./bin/ops cap run backup.status` to confirm NAS connectivity restored.

## Scenario 3: MacBook Lost/Destroyed

**Impact: MEDIUM** — control plane offline until replaced.

### What Breaks

- Spine CLI (`bin/ops`) unavailable — no capability runs, no drift gate verification.
- Infisical universal auth credentials cached on MacBook.
- Git working copies (agentic-spine, workbench) — both mirrored to GitHub and Gitea.

### What Continues Working

All infrastructure services continue running autonomously. Backups continue on schedule.
Services are self-healing (Docker restart policies, systemd).

### Recovery Sequence

1. **New machine**: clone `agentic-spine` and `workbench` from GitHub or Gitea.
2. **Restore Infisical auth**: Re-create universal auth credentials from Infisical web UI (via Vaultwarden-stored admin creds).
3. **Restore SSH keys**: Generate new keypair, inject into VMs via `qm guest exec` on pve, or use iDRAC console.
4. **Restore Tailscale**: Install Tailscale, authenticate. Old device can be removed from admin console.

## Scenario 4: Infisical Compromised or Corrupt

**Impact: CRITICAL** — secrets SPOF.

### Recovery Sequence

1. **Isolate**: `ssh infra-core 'cd /opt/stacks/secrets && docker compose down'`
2. **Assess**: Check Infisical audit logs for unauthorized access.
3. **Restore from backup**: Follow `INFISICAL_BACKUP_RESTORE.md` procedure.
4. **Rotate all secrets**: If compromise confirmed, rotate every secret in every namespace.
5. **Re-deploy dependent services**: Restart all stacks that consume Infisical secrets.

## Cross-Site Dependency Map

```
MacBook (control plane)
  └── SSH → all VMs (via Tailscale)
  └── Infisical CLI → infra-core:8088

infra-core (VM 204) — MOST CRITICAL
  ├── cloudflared → CF tunnel → all *.ronny.works
  ├── pihole → DNS for shop network
  ├── infisical → secrets for ALL services
  ├── vaultwarden → human credential access
  ├── authentik → SSO for pihole, vault, secrets, gitea
  └── caddy → reverse proxy for above

observability (VM 205)
  └── prometheus/grafana/loki/uptime-kuma (monitoring only, no runtime deps)

dev-tools (VM 206)
  └── gitea (code hosting, CI runners)

download-stack (VM 209) ←→ streaming-stack (VM 210)
  └── autopulse on 209 triggers jellyfin refresh on 210
  └── jellyseerr on 210 calls radarr/sonarr on 209

NAS (home site)
  └── offsite backup target (vzdump copies, app-level dumps)
```

## Recovery Priority Order

If all VMs need restoration simultaneously:

1. **infra-core (204)** — unlocks DNS, secrets, auth, public routing
2. **observability (205)** — restores monitoring visibility
3. **dev-tools (206)** — restores CI/CD
4. **download-stack (209)** — media acquisition
5. **streaming-stack (210)** — media serving
6. **ai-consolidation (207)** — AI/RAG services
7. **automation-stack (202)** — n8n, ollama, open-webui
8. **docker-host (200)** — legacy (mint-os, minio)
9. **immich-1 (203)** — photos

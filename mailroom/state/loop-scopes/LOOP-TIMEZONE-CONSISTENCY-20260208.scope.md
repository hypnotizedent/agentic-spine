# LOOP-TIMEZONE-CONSISTENCY-20260208

> **Status:** open
> **Blocked By:** none
> **Owner:** @ronny
> **Created:** 2026-02-08
> **Severity:** low

---

## Executive Summary

pve (shop R730XD) is running timezone `America/Adak` (HST, UTC-10) with `System clock synchronized: no`. This is almost certainly wrong — the shop is not in Hawaii. Likely set during initial Proxmox install or drifted. All VMs cloned from template 9000 on pve may inherit this timezone via cloud-init or host clock.

VMs 204-210 were all created on 2026-02-08 and may have inherited the wrong timezone. Vzdump logs, cron schedules, and Proxmox task timestamps are all offset, making incident correlation harder.

---

## Current State

### pve Host

| Property | Value | Expected |
|----------|-------|----------|
| Timezone | `America/Adak` (HST, UTC-10) | `America/New_York` (EST/EDT, UTC-5) |
| NTP sync | `System clock synchronized: no` | `yes` |
| Locale | unknown | en_US.UTF-8 |

### Impact

- vzdump job scheduled at `02:00` runs at 02:00 HST = 07:00 EST (not ideal — overlaps with daytime usage)
- All Proxmox task logs and timestamps are HST — confusing when correlating with EST-based events
- Newly provisioned VMs (204-210) may have inherited wrong timezone from host or cloud-init defaults
- `backup.inventory.yaml` declares `timezone: "America/New_York"` — mismatch with actual host

---

## Phases

| Phase | Scope | Dependency |
|-------|-------|------------|
| P0 | Audit all hosts for timezone + NTP status | None |
| P1 | Fix pve timezone + enable NTP | P0 |
| P2 | Fix VM timezones (204-210) | P1 |
| P3 | Verify + closeout | P2 |

---

## Phase Details

### P0 — Audit all hosts

SSH to each host and capture:
```
timedatectl
cat /etc/timezone
```

Hosts to check: pve, infra-core (204), observability (205), dev-tools (206), ai-consolidation (207), media-stack (201), download-stack (209), streaming-stack (210)

### P1 — Fix pve timezone + NTP

```bash
timedatectl set-timezone America/New_York
timedatectl set-ntp true
```

**Note:** Changing timezone on pve will shift when the vzdump `02:00` schedule fires (from 02:00 HST to 02:00 EST). This is the desired behavior. No vzdump config change needed.

### P2 — Fix VM timezones

For each VM:
```bash
sudo timedatectl set-timezone America/New_York
sudo timedatectl set-ntp true
```

Also check cloud-init template 9000 — if it bakes in the wrong timezone, future VMs will inherit it.

### P3 — Verify + closeout

- All hosts report `America/New_York`
- All hosts report `System clock synchronized: yes`
- vzdump next run fires at 02:00 EST
- Consider adding a D48 drift gate for timezone consistency

---

## Success Criteria

| Criteria | Validation |
|----------|------------|
| pve timezone correct | `timedatectl` shows `America/New_York` |
| NTP enabled on pve | `System clock synchronized: yes` |
| All VMs timezone correct | SSH audit shows `America/New_York` on all |
| Template 9000 timezone | Cloud-init defaults checked/updated |

---

## Non-Goals

- Do NOT change vzdump schedule time (02:00 is fine, just needs to be EST not HST)
- Do NOT investigate the power outage (separate from timezone)

---

## Evidence

- P0 audit from LOOP-BACKUP-STABILIZATION-20260208: `timedatectl` on pve shows `America/Adak`
- `backup.inventory.yaml` declares `timezone: "America/New_York"` — contradicts actual host config

---

_Scope document created by: Opus 4.6_
_Created: 2026-02-08_

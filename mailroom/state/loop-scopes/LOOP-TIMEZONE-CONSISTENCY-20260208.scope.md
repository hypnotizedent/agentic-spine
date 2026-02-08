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

### P0 Audit Results (2026-02-08)

| Host | VM | Before | NTP | Status |
|------|-----|--------|-----|--------|
| pve | — | `America/Adak` (HST) | yes | WRONG |
| proxmox-home | — | `America/Nome` (AKST) | yes | WRONG |
| infra-core | 204 | `Etc/UTC` | yes | cloud-init default |
| observability | 205 | `Etc/UTC` | yes | cloud-init default |
| dev-tools | 206 | `Etc/UTC` | yes | cloud-init default |
| ai-consolidation | 207 | `Etc/UTC` | yes | cloud-init default |
| media-stack | 201 | `Etc/UTC` | yes | cloud-init default |
| streaming-stack | 210 | `Etc/UTC` | yes | cloud-init default |
| vault | — | `Etc/UTC` | yes | cloud-init default |
| docker-host | 200 | unreachable | — | down post-outage |
| download-stack | 209 | unreachable | — | not provisioned |
| nas | — | unknown | unknown | Synology DSM (no timedatectl) |
| automation-stack | — | `Etc/UTC` | yes | sudo password required |
| ha | — | unknown | unknown | HAOS (no timedatectl) |

**Finding:** VMs did NOT inherit hypervisor timezone — cloud-init template 9000 defaults to UTC.

### P1+P2 Execution Results (2026-02-08)

Capability: `infra.timezone.set --timezone America/New_York --execute`

| Host | Result |
|------|--------|
| pve | FIXED (`America/Adak` -> `America/New_York`) |
| proxmox-home | FIXED (`America/Nome` -> `America/New_York`) |
| vault | FIXED (`Etc/UTC` -> `America/New_York`) |
| infra-core (204) | FIXED (`Etc/UTC` -> `America/New_York`) |
| observability (205) | FIXED (`Etc/UTC` -> `America/New_York`) |
| dev-tools (206) | FIXED (`Etc/UTC` -> `America/New_York`) |
| media-stack (201) | FIXED (`Etc/UTC` -> `America/New_York`) |
| streaming-stack (210) | FIXED (`Etc/UTC` -> `America/New_York`) |
| ai-consolidation (207) | FIXED (`Etc/UTC` -> `America/New_York`) |
| nas | FAILED — no `timedatectl` (Synology DSM, fix via web UI) |
| automation-stack | FAILED — sudo requires password |
| ha | FAILED — no `timedatectl` (HAOS appliance) |
| docker-host (200) | UNREACHABLE |
| pihole-home | UNREACHABLE |
| download-stack (209) | UNREACHABLE |
| download-home | UNREACHABLE |

**Result:** 9/16 fixed, 3 appliance/password failures, 4 unreachable.

Receipts:
- Dry-run: `RCAP-20260208-114500__infra.timezone.set__R36up5845`
- Execute (run 1): `RCAP-20260208-114535__infra.timezone.set__Rxfff6150`
- Execute (run 2): `RCAP-20260208-114623__infra.timezone.set__Rxnyk6678`
- Verify: `RCAP-20260208-114703__infra.timezone.set__Rgg6f7194`

### Remaining Work

- `nas`: Set timezone via Synology DSM web UI (manual)
- `automation-stack`: SSH with password or fix sudoers NOPASSWD
- `ha`: Set timezone via Home Assistant web UI (manual)
- `docker-host` (200): Fix after power outage recovery
- `download-stack` (209), `pihole-home`, `download-home`: Fix when provisioned/online

---

_Scope document created by: Opus 4.6_
_Created: 2026-02-08_

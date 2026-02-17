# L4 Proxmox Alignment Diff

> **Terminal:** LANE-D for LOOP-RONNY-OPS-FINAL-EXTRACTION-SWEEP-20260217
> **Agent:** opencode (unique workstream)
> **Generated:** 2026-02-17
> **Status:** read-only discovery

---

## Executive Summary

**Clusters Analyzed:**
| Cluster | Canonical Name | Host | Tailscale IP | Source Authority |
|---------|---------------|------|--------------|------------------|
| Shop | `pve` | Dell R730XD | 100.96.211.33 | spine/vm.lifecycle.yaml |
| Home | `proxmox-home` | Beelink SER7 | 100.103.99.62 | spine/vm.lifecycle.yaml |
| **Drift** | `pve-shop` | — | — | workbench only (NOT canonical) |

**Finding:** `pve-shop` is a non-canonical alias used in workbench/legacy but never in spine authority sources. This creates confusion but no runtime breakage (no VMs directly reference it for provisioning).

---

## Canonical Alignment (Spine Sources)

### vm.lifecycle.yaml
| VM ID | Hostname | proxmox_host | Status |
|-------|----------|--------------|--------|
| **Shop (pve)** ||||
| 200 | docker-host | `pve` | active |
| 201 | media-stack | `pve` | decommissioned |
| 202 | automation-stack | `pve` | active |
| 203 | immich | `pve` | active |
| 204 | infra-core | `pve` | active |
| 205 | observability | `pve` | active |
| 206 | dev-tools | `pve` | active |
| 207 | ai-consolidation | `pve` | active |
| 209 | download-stack | `pve` | active |
| 210 | streaming-stack | `pve` | active |
| 211 | finance-stack | `pve` | active |
| 212 | mint-data | `pve` | active |
| 213 | mint-apps | `pve` | active |
| 9000 | ubuntu-2404-cloudinit-template | `pve` | template |
| **Home (proxmox-home)** ||||
| 100 | homeassistant | `proxmox-home` | active |
| 101 | immich | `proxmox-home` | stopped |
| 102 | vaultwarden | `proxmox-home` | decommissioned |
| 103 | download-home | `proxmox-home` | stopped (LXC) |
| 105 | pihole-home | `proxmox-home` | stopped (LXC) |

### ssh.targets.yaml
| ID | Tailscale IP | Notes | Cluster |
|----|--------------|-------|---------|
| `pve` | 100.96.211.33 | Proxmox VE - shop location | Shop |
| `proxmox-home` | 100.103.99.62 | Proxmox Host (Home) - Beelink Mini | Home |

### SERVICE_REGISTRY.yaml (hosts section)
| Host | proxmox_host | VMID |
|------|--------------|------|
| automation-stack | `pve` | 202 |
| infra-core | `pve` | 204 |
| observability | `pve` | 205 |
| dev-tools | `pve` | 206 |
| immich | `pve` | 203 |
| ai-consolidation | `pve` | 207 |
| download-stack | `pve` | 209 |
| streaming-stack | `pve` | 210 |
| finance-stack | `pve` | 211 |
| mint-data | `pve` | 212 |
| mint-apps | `pve` | 213 |
| proxmox-home | — | — |

**Verdict:** Spine sources are **ALIGNED** — all use `pve` for shop, `proxmox-home` for home.

---

## Mismatch Table by Cluster

### Cluster: `pve` (Shop)

| Source | File | Field | Expected | Actual | Severity |
|--------|------|-------|----------|--------|----------|
| workbench | `infra/data/CONTAINER_INVENTORY.yaml` | location | `pve` | `pve-shop` | **MEDIUM** |
| workbench | `infra/data/monitoring_inventory.json:145-152` | service/host | `pve` | `proxmox-shop` | **MEDIUM** |
| legacy | `ronny-ops/infrastructure/docs/sessions/2026-01-25-PVE-INCIDENT-HANDOFF.md:123-126` | node name | `pve` | `pve-shop` | LOW |
| legacy | `ronny-ops/docs/governance/DEVICE_IDENTITY_SSOT.md:77-79` | canonical | `pve` | `pve` | ✅ ALIGNED |
| legacy | `ronny-ops/infrastructure/DISCOVERY_2026-01-21.md:346-347` | inventory label | `pve` | `pve` | ✅ ALIGNED |

**Impact:** Workbench uses `pve-shop` and `proxmox-shop` as location labels but spine never references these. Not a runtime issue since spine is the provisioning authority.

---

### Cluster: `proxmox-home` (Home)

| Source | File | Field | Expected | Actual | Severity |
|--------|------|-------|----------|--------|----------|
| workbench | `infra/data/monitoring_inventory.json:130-137` | service/host | `proxmox-home` | `proxmox-home` | ✅ ALIGNED |
| workbench | `infra/data/backup_inventory.json:238` | host label | `proxmox-home` | `pve-home` | **HIGH** |
| workbench | `infra/data/backup_inventory.json:245` | host label | `proxmox-home` | `pve-home` | **HIGH** |
| legacy | `ronny-ops/infrastructure/docs/sessions/2026-01-25-PVE-INCIDENT-HANDOFF.md:120-122` | node name | `proxmox-home` | `proxmox-home` | ✅ ALIGNED |

**Impact:** `pve-home` appears in backup_inventory.json as a drift. This is the only HIGH severity issue found — could cause backup path confusion.

---

### Cluster: `pve-shop` (Non-Canonical)

| Source | File | Context | Issue |
|--------|------|---------|-------|
| workbench | `infra/data/CONTAINER_INVENTORY.yaml:65,90,100,109,119` | location field | Uses `pve-shop` as location (should be `pve`) |
| legacy | `ronny-ops/infrastructure/docs/sessions/2026-01-25-PVE-INCIDENT-HANDOFF.md` | task references | Uses `pve-shop` as node identifier |
| legacy | `ronny-ops/scripts/sync-to-beelink.sh` | comment | References `pve-shop` as cluster |

**Verdict:** `pve-shop` is a **workbench/legacy artifact** — never referenced in spine authority sources. Recommend deprecation.

---

## Detailed File Targets for Remediation

### HIGH Priority (Breaks or Confuses Operations)

| File | Line(s) | Current | Should Be | Action |
|------|---------|---------|-----------|--------|
| `workbench/infra/data/backup_inventory.json` | 238, 245 | `pve-home` | `proxmox-home` | Update host labels |

### MEDIUM Priority (Creates Drift from Canonical)

| File | Line(s) | Current | Should Be | Action |
|------|---------|---------|-----------|--------|
| `workbench/infra/data/CONTAINER_INVENTORY.yaml` | 65, 90, 100, 109, 119 | `pve-shop` | `pve` | Update location fields |
| `workbench/infra/data/monitoring_inventory.json` | 145, 152 | `proxmox-shop` | `pve` | Update service/host names |

### LOW Priority (Legacy / Documentation Only)

| File | Context | Issue | Action |
|------|---------|-------|--------|
| `ronny-ops/infrastructure/docs/sessions/2026-01-25-PVE-INCIDENT-HANDOFF.md` | Session handoff notes | Uses `pve-shop` as node label | No action (legacy read-only) |
| `ronny-ops/scripts/sync-to-beelink.sh` | Script comment | References `pve-shop` | No action (legacy read-only) |

---

## Spine-to-Legacy Cross-Reference

| Spine Source | Spine Value | Legacy Equiv | Match? |
|--------------|-------------|--------------|--------|
| vm.lifecycle.yaml | `pve` | `pve`, `pve-shop`, `proxmox-shop` | Partial drift |
| vm.lifecycle.yaml | `proxmox-home` | `proxmox-home`, `pve-home`, `beelink` | Partial drift |
| ssh.targets.yaml | `pve` | `pve` | ✅ |
| ssh.targets.yaml | `proxmox-home` | `proxmox-home` | ✅ |
| SERVICE_REGISTRY.yaml | `pve` | `pve` | ✅ |
| SERVICE_REGISTRY.yaml | `proxmox-home` | `proxmox-home` | ✅ |

---

## Recommendations

1. **Deprecate `pve-shop`:** This alias appears only in workbench/legacy and should not be introduced into spine. Update workbench files to use canonical `pve`.

2. **Fix `pve-home` in backup_inventory.json:** This is the only HIGH severity drift. It could cause backup confusion if scripts depend on host matching.

3. **Standardize workbench location field:** `CONTAINER_INVENTORY.yaml` uses `pve-shop` as location for all shop VMs. This should be `pve` for alignment.

4. **No spine changes required:** All spine sources (`vm.lifecycle.yaml`, `ssh.targets.yaml`, `SERVICE_REGISTRY.yaml`, `DEVICE_IDENTITY_SSOT.md`) consistently use `pve` and `proxmox-home`.

---

## Files Reviewed

### Spine (Authoritative)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/vm.lifecycle.yaml`
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/vm.lifecycle.derived.yaml`
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/vm.lifecycle.contract.yaml`
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/ssh.targets.yaml`
- `/Users/ronnyworks/code/agentic-spine/docs/governance/SERVICE_REGISTRY.yaml`
- `/Users/ronnyworks/code/agentic-spine/docs/governance/DEVICE_IDENTITY_SSOT.md`

### Workbench (Tooling)
- `/Users/ronnyworks/code/workbench/infra/data/CONTAINER_INVENTORY.yaml`
- `/Users/ronnyworks/code/workbench/infra/data/SERVICE_REGISTRY.yaml` (tombstoned)
- `/Users/ronnyworks/code/workbench/infra/data/monitoring_inventory.json`
- `/Users/ronnyworks/code/workbench/infra/data/backup_inventory.json`
- `/Users/ronnyworks/code/workbench/infra/data/updates_inventory.json`

### Legacy (Read-Only Reference)
- `/Users/ronnyworks/ronny-ops/**` (grep search for `pve|proxmox` — 885 matches in 152 files)

---

## Receipt

- **Task:** L4 Proxmox Alignment Diff
- **Lane:** LANE-D for LOOP-RONNY-OPS-FINAL-EXTRACTION-SWEEP-20260217
- **Agent:** opencode
- **Output:** `L4opencodePROXMOXalignmentdiff.md`
- **Completed:** 2026-02-17

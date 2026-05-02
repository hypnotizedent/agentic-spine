---
status: authoritative
owner: "@ronny"
last_verified: 2026-04-27
verification_method: spine-capabilities
scope: all-infrastructure
github_issue: "#615"
parent_issues: ["#440", "#609", "#32", "#625"]
---

# DEVICE IDENTITY SSOT

> **This document defines stable naming rules and topology conventions.**
>
> Factual host/IP/VM tables are generated from structured bindings.
> Run `./bin/ops cap run device.identity.readmodel.generate` for the current
> device identity read model.
>
> For current SSH/access-path evidence -> run `./bin/ops cap run device.identity.readmodel.generate`
> and read `$SPINE_STATE/domain-state/ssh.access.projection.yaml`.
> `ops/bindings/ssh.targets.yaml` remains the access-path source binding; it is
> not machine identity, role, placement, watcher, backup, or recovery truth.
> For VM lifecycle state -> CHECK `ops/bindings/vm.lifecycle.yaml`.
> For hardware inventory -> CHECK `ops/bindings/hardware.inventory.yaml`.
> For operator-owned machine identity -> CHECK `ops/bindings/operator.hardware.inventory.yaml`.
> For service endpoints/ports/health routes -> CHECK `ops/bindings/probe.registry.yaml`.

---

## Naming Rules

### Tailscale Hostnames (AUTHORITATIVE)

| Pattern | Example | Use Case |
|---------|---------|----------|
| `{function}` | `macbook` | Single-purpose devices |
| `{function}-{location}` | `proxmox-home`, `immich-1` | When same function exists in multiple locations |
| `{stack}-{role}` | `finance-stack`, `download-stack` | VMs with clear stack ownership |

**Rules:**
- Lowercase only, hyphens for separators
- Max 20 characters (Tailscale limit)
- No underscores (breaks some DNS resolvers)
- Functional names (what it DOES), not arbitrary names

### Proxmox VMID Ranges

| Range | Location | Purpose |
|-------|----------|---------|
| 100-199 | proxmox-home | Home VMs/LXCs |
| 200-299 | pve (shop) | Shop VMs |

### Container Naming

| Pattern | Example | Use Case |
|---------|---------|----------|
| `{stack}-{service}` | `mint-os-postgres` | Stack-owned service |
| `{service}` | `minio` | Standalone infrastructure |

---

## Sites / Topology Memory

### Subnets

| Subnet | Site | Gateway | Notes |
|--------|------|---------|-------|
| 192.168.1.0/24 | Shop | 192.168.1.1 (UDR6) | Production infrastructure; DNS -> Pi-hole (.204) |
| 10.0.0.0/24 | Home | 10.0.0.1 (UDR7) | Home lab |
| 100.x.x.x/32 | Tailscale | MagicDNS | Mesh overlay network |

### Site Characteristics

- **Shop**: Dell R730XD hypervisor (`pve`), Dell N2024P switch, UDR6 gateway, LAN-only peripherals (NVR, AP, iDRAC). Production VMs on 192.168.1.x.
- **Home**: Beelink SER7 (`proxmox-home`), Synology NAS (`nas`), UDR7 gateway. Media/HA/DNS on 10.0.0.x.
- **Tailscale mesh**: All cross-site access. MagicDNS for hostname resolution.

---

## Authority Pointers

| Domain | Authority File | What It Answers |
|--------|---------------|-----------------|
| SSH/access projection | `./bin/ops cap run device.identity.readmodel.generate` -> `$SPINE_STATE/domain-state/ssh.access.projection.yaml` | Generated access evidence for how to reach each host |
| SSH targets source binding | `ops/bindings/ssh.targets.yaml` | Source access-path facts (IP, user, policy); not machine authority |
| VM lifecycle | `ops/bindings/vm.lifecycle.yaml` | What VMs exist, status, workloads, IPs |
| Hardware inventory | `ops/bindings/hardware.inventory.yaml` | Physical machines, storage controllers, recovery |
| Operator hardware | `ops/bindings/operator.hardware.inventory.yaml` | Operator-owned machine candidacy |
| Service endpoints | `ops/bindings/probe.registry.yaml` | Service-level health, ports, URLs |
| Stack registry | `docs/governance/STACK_REGISTRY.yaml` | Stack-to-host inventory |
| Minilab read model | `./bin/ops cap run infra.minilab.readmodel.generate` | Home site generated summary |
| Shop read model | `./bin/ops cap run infra.shop.readmodel.generate` | Shop site generated summary |
| Device identity read model | `./bin/ops cap run device.identity.readmodel.generate` | Estate-wide generated summary |

---

## Change Control

### Adding a New Device

1. Choose name following Naming Rules above
2. Add entry to appropriate binding (`ssh.targets.yaml`, `vm.lifecycle.yaml`)
3. Run `./bin/ops cap run device.identity.readmodel.generate` to verify it appears
4. Commit binding changes

### Updating an IP

1. Update the authority binding (`ssh.targets.yaml` and/or `vm.lifecycle.yaml`)
2. Update `ops/bindings/probe.registry.yaml` if service-level mapping changes
3. Run readmodel generator to verify

### Removing a Device

1. Set status to `decommissioned` in `vm.lifecycle.yaml` with date and reason
2. Mark SSH target as `optional: true` or remove if no longer needed
3. After 30 days, clean up decommissioned entries

---

## Retired Surfaces

- **Stream Deck automation**: Retired March 11, 2026. Not governed active authority.
- **Factual host/IP tables in this doc**: Retired April 27, 2026. Replaced by generated read model from structured bindings.
- **Manual verification command lists**: Replaced by `./bin/ops verify --infra` and per-capability receipts.

---

## Related Issues

- **#615** - This document (Device identity SSOT + Stream Deck entrypoint)
- **#440** - Master workflow session (parent)
- **#609** - Post-PVE reliability improvements (identity supports infra work)
- **#618** - Dell N2024P console debug + recovery (physical task, open)

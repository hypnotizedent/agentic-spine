# VM Infrastructure Lessons

> **Status:** reference
> **Provenance:** spine-native
> **Source Loop:** LOOP-INFRA-VM-RESTRUCTURE-20260206
> **Last verified:** 2026-02-07

Hard-won knowledge from VM provisioning and service migration work.

---

## Proxmox VM Provisioning

### Template Usage
- Template VM 9000 (`ubuntu-2404-cloudinit-template`) exists on `pve`
- Created from `ubuntu-24.04-server-cloudimg-amd64.img`

### Clone Gotchas
- `qm clone` needs `--full` flag when specifying `--storage`
- Linked clones don't allow storage param

### Cloud-Init
- `ip=dhcp` may fail on Ubuntu 24.04 cloud images
- Static IPs work reliably
- Always verify network config post-boot

---

## Ubuntu 24.04 Bootstrap

### Docker Installation
- `docker-compose-plugin` requires Docker's official apt repo (not default Ubuntu repos)
- Profile uses: `docker-ce` + `docker-ce-cli` + `containerd.io` + `docker-compose-plugin`

### Tailscale
- Needs its own apt repo added before `apt-get install tailscale` works
- Use `tailscale up --authkey` for headless setup

### System Services
- Cron service is `cron.service` not `crond`
- Check with `systemctl is-active cron` directly
- `qemu-guest-agent` is a static unit, `systemctl enable` warns but it works

---

## yq (v4.50.1) Syntax

### What Doesn't Work
```yaml
# FAILS - lexer error
(.field |= if .hostname == "X" then "val" else . end)
```

### What Works
```yaml
# CORRECT - use select()
(.vm_targets[] | select(.hostname == "X")).field = "val"
```

---

## SSH Access Patterns

### Tailscale Routing
- Macbook can reach shop subnet (192.168.12.0/24) via Tailscale subnet routing
- Sometimes flaky — use jump host as fallback

### Jump Host Pattern
```bash
ssh -J root@pve ubuntu@infra-core
```

### Key Credentials
- infra-core SSH: user=`ubuntu`, key=ed25519 (info@mintprints.com)

---

## Cloudflare Tunnel Lessons

### Dashboard-Managed Tunnel
- Ingress rules via CF API: `PUT /accounts/{acct}/cfd_tunnel/{id}/configurations`
- Don't try to use local config file with dashboard tunnel

### Cached Credentials
```
~/.cache/infisical/infrastructure/prod/CLOUDFLARE_*
```

### Critical Settings
- CF_ACCOUNT_ID: `7142588d89e84212ae430ad25f2aae1f`
- TUNNEL_ID: `ae7d4462-cfb2-4919-802e-41c01742a9eb`

### Network Mode
- Use `127.0.0.1` not `localhost` (avoids IPv6 `[::1]` resolution failure)
- cloudflared MUST use `network_mode: host` when routing to co-located services

---

## Pi-hole v6 Migration

### Config Format Change
- TOML config (`pihole.toml`), not `setupVars.conf`

### Listening Mode
- `DNSMASQ_LISTENING=all` env var is **IGNORED**
- Use: `pihole-FTL --config dns.listeningMode all`
- Default `LOCAL` mode blocks Tailscale IPs

### systemd-resolved Conflict
- Disable stub listener: `/etc/systemd/resolved.conf.d/no-stub.conf`
```ini
[Resolve]
DNSStubListener=no
```

---

## Agent Discipline

### SSOT First
- Consult bindings FIRST (`docker.compose.targets.yaml`, `ssh.targets.yaml`) before guessing paths on remote hosts
- Don't assume path from service name

### Gap Handling
- When an SSOT doc is inaccurate, note it explicitly in output
- Fix what's in scope
- Do NOT chase all stale refs (scope creep)
- Log to `operational.gaps.yaml` for future cleanup

### Manual Approval
- `approval: manual` caps require interactive `yes`
- Pipe with `echo "yes" |` for scripting
- No `--approve` or `--yes` flag exists

---

## Cross-References

| Document | Relationship |
|----------|--------------|
| `ops/bindings/infra.relocation.plan.yaml` | Active relocation manifest |
| `ops/bindings/infra.vm.profiles.yaml` | VM provisioning profiles |
| `ops/bindings/operational.gaps.yaml` | Gaps discovered during this work |
| `docs/governance/DEVICE_IDENTITY_SSOT.md` | VM identity and IPs |

---

_Extracted from Claude memory during LOOP-INFRA-VM-RESTRUCTURE-20260206_
_Canonicalized: 2026-02-07_

---
status: draft
owner: "@ronny"
last_verified: 2026-02-08
scope: security-governance
---

# Security Policies

Purpose: baseline security governance for the homelab estate. Covers firewall,
SSH hardening, NFS security, and access control.

## SSH Hardening (SEC-01)

Current state: `strict_host_key_checking: "no"` in `ssh.targets.yaml` to avoid
known_hosts drift on the MacBook. This is a known trade-off.

Target state:
- [ ] Populate `~/.ssh/known_hosts` with host keys from a trusted first-connection.
- [ ] Switch `strict_host_key_checking` to `"yes"` in `ssh.targets.yaml` defaults.
- [ ] Add a drift gate (D50+) that validates known_hosts entries match SSH target inventory.

Interim mitigation: All SSH connections traverse Tailscale (encrypted, authenticated overlay).
MITM requires Tailscale control plane compromise.

## Firewall Policy (SEC-04)

Current state: No standardized host-level firewall rules. Each VM relies on Tailscale ACLs
(when configured) and implicit trust within the Tailscale network.

Target policy:
- All VMs: deny all inbound by default, allow SSH (22) from Tailscale subnet only.
- Service ports: allow only from expected consumers (e.g., Prometheus scrape from observability VM).
- Proxmox hosts: allow PVE web UI (8006) from Tailscale only.
- Implementation: `ufw` on Ubuntu VMs, `iptables` on Proxmox hosts.
- [ ] Create Ansible playbook for firewall baseline (TOOL-01 prerequisite).

## NFS Security (SEC-03)

Current state: All NFS exports use `no_root_squash`. Mitigated by Tailscale-only IP ACLs.

Target policy:
- Switch to `root_squash` for exports where root access is not required.
- Media exports (`/media`): `root_squash` is safe — containers run as non-root UIDs.
- Docker volume exports (`/tank/docker/*`): `no_root_squash` may be required for container volume ownership. Evaluate per-stack.
- [ ] Audit each NFS export and apply least-privilege squash settings.

## Access Control (SEC-05)

Current state: Authentik deployed on infra-core. Forward auth active for pihole, vaultwarden,
infisical web UIs. Gitea SSO via OAuth2.

Deployed:
- [x] Authentik SSO (forward_single proxy providers)
- [x] Caddy reverse proxy with forward auth headers
- [x] Gitea OAuth2 integration

Remaining:
- [ ] Grafana OAuth2 integration with Authentik
- [ ] Uptime Kuma authentication
- [ ] Audit sudo access across all VMs (who has passwordless sudo)
- [ ] SSH session logging (consider `auditd` or `pam_exec`)

## Tailscale Device Audit (SEC-06)

Policy: Quarterly review of Tailscale admin console for:
- Stale devices (offline >30 days) — remove or document exception.
- Unexpected devices — investigate and remove.
- Key expiry — ensure machine keys don't silently expire.

Command: `tailscale status` on any enrolled node shows current peers.

- [ ] Perform initial device audit and document in a receipt.
- [ ] Add quarterly reminder to loop system.

## Secrets Rotation (SEC-07)

Current policy (from SECRETS_POLICY.md):
- 90 days = CRITICAL
- 60 days = WARNING
- Enforcement is manual via `check-secret-expiry.sh`

Target:
- [ ] Wire secret age check into the drift gate chain (D50+) so `spine.verify` catches stale secrets.
- [ ] Define which secrets are rotation-exempt (e.g., Tailscale auth keys, machine IDs).

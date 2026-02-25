---
loop_id: LOOP-PRIVADO-VPN-CANONICAL-SETUP-20260225
created: 2026-02-25
status: active
owner: "@ronny"
scope: privado
priority: medium
objective: Canonically document and configure Privado VPN across spine — provider binding, gluetun health probe, qBittorrent VPN decision, DNS policy, network topology update
---

# Loop Scope: LOOP-PRIVADO-VPN-CANONICAL-SETUP-20260225

## Objective

Canonically document and configure Privado VPN (Privado VPN account: hypnotizedent@gmail.com) across the spine infrastructure. Establish Privado as the canonical P2P VPN provider, create governance bindings, health probes, and a runbook covering every touchpoint.

## Context

Privado VPN was provisioned for the music pipeline upgrade (LOOP-MUSIC-PIPELINE-UPGRADE-20260225) as a gluetun container tunneling slskd (Soulseek) traffic. Credentials are in Infisical at `/spine/vm-infra/media-stack/download`. However, the VPN is not yet canonically documented as a spine-wide resource, and several questions remain about its scope across the download stack.

### Current State (from audit)

- **Gluetun container**: added to download-stack docker-compose (not yet deployed)
- **Provider**: Privado VPN, OpenVPN protocol, Netherlands default
- **Tunneled service**: slskd only (network_mode: "service:gluetun")
- **NOT tunneled**: qBittorrent (direct bridge, ports 8081/6881), SABnzbd
- **Pi-hole**: uses Cloudflare upstream (1.1.1.1), NOT Privado DNS
- **Privado DNS**: 91.148.229.50, 91.148.225.50 (used within tunnel only)
- **Privado DNS-over-HTTPS**: https://dns.privadovpn.com/nhtlinlzxhvo
- **Privado DNS-over-TLS**: nhtlinlzxhvo.dns.privadovpn.com
- **Privado features available**: SOCKS5 proxy, Email Relay, Control Tower DNS
- **No health probe** for gluetun in services.health.yaml
- **No VPN provider binding** document exists
- **No D-gate** checks VPN health

## Phases

### Phase 1: VPN Provider Binding + Runbook

Create canonical documentation:

1. **`ops/bindings/vpn.provider.yaml`** — SSOT for VPN provider:
   - Provider: Privado VPN
   - Account: hypnotizedent@gmail.com
   - Protocol: OpenVPN
   - Gluetun image: qmcgaw/gluetun:latest
   - Infisical path: /spine/vm-infra/media-stack/download
   - Keys: PRIVADO_VPN_USER, PRIVADO_VPN_PASS
   - Default region: Netherlands
   - Available features: SOCKS5, DNS-over-HTTPS, DNS-over-TLS, Email Relay
   - Tunneled services: slskd
   - NOT tunneled: qBittorrent, SABnzbd (with rationale)

2. **`docs/runbooks/privado-vpn-setup.md`** — Operational runbook:
   - How to verify VPN is working (docker logs, ifconfig.me check)
   - How to change server region
   - How to add a new service behind the tunnel
   - How to troubleshoot connection failures
   - Credential rotation procedure
   - Port forwarding setup (FIREWALL_VPN_INPUT_PORTS)

### Phase 2: Gluetun Health Probe + Gate

1. **`ops/bindings/services.health.yaml`** — add gluetun health endpoint
   - Note: gluetun exposes no HTTP health route; use Docker healthcheck status via SSH
   - Alternative: use `wget -qO- ifconfig.me` inside container to verify external IP differs from home IP

2. **D-gate (D22x)** — VPN health drift gate:
   - Check gluetun container is running on download-stack
   - Verify VPN is connected (gluetun healthcheck passes)
   - Verify slskd is behind VPN (not on default bridge)

### Phase 3: qBittorrent VPN Decision

**Decision gate**: Should qBittorrent route through gluetun?

Arguments FOR:
- ISP can see torrent traffic (even with Real-Debrid, some direct torrents exist)
- Consistent security posture for all P2P

Arguments AGAINST:
- Most torrents go through Real-Debrid (decypharr), not direct qBittorrent
- Adding qBittorrent to gluetun means ports move to gluetun container
- Radarr/Sonarr need network access to qBittorrent (same bridge or music-net)
- Adds complexity and a single point of failure

**Recommendation**: Keep qBittorrent direct for now. Re-evaluate if ISP issues arise. Document decision in vpn.provider.yaml.

### Phase 4: DNS Policy Documentation

Document in the runbook:
- Pi-hole upstream stays Cloudflare (1.1.1.1 / 1.0.0.1) — NOT Privado DNS
- Gluetun uses `DOT=off` (DNS resolved within VPN tunnel by Privado's servers)
- Privado DNS-over-HTTPS/TLS are account-level features, not used in spine
- No changes needed to Pi-hole config

### Phase 5: Network Topology Update

1. Update workbench network runbook to include Privado VPN as secondary provider
2. Update DEVICE_IDENTITY_SSOT.md to note: "Tailscale = primary overlay, Privado VPN = media P2P tunnel"

## Gaps (to be filed)

- VPN provider not canonically documented (new binding needed)
- Gluetun no health probe in services.health.yaml
- No D-gate for VPN connectivity health
- qBittorrent VPN decision not documented

## Success Criteria

- vpn.provider.yaml binding exists and is authoritative
- Privado VPN runbook covers setup, verification, troubleshooting, rotation
- Gluetun health probe in services.health.yaml
- D-gate validates VPN health on download-stack
- qBittorrent VPN decision documented with rationale
- DNS policy documented (Pi-hole unaffected)
- Network topology docs updated

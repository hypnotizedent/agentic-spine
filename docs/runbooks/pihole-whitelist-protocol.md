# Pi-hole Whitelist Standard Protocol

**Gap:** GAP-OP-834
**Scope:** Shop (docker-host) + Home (proxmox-home) Pi-hole instances
**Pi-hole version:** v6+

---

## Canonical Whitelist Domains

Exact domains (not regex):

### iCloud Private Relay

- `mask.icloud.com`
- `mask-h2.icloud.com`

### Apple Captive / Connectivity

- `captive.apple.com`
- `www.apple.com`

### Push / APNs

- `push.apple.com`
- `courier.push.apple.com`

---

## CLI Commands

Pi-hole v6 uses `pihole allow` (not the deprecated v5 `pihole --white-list`).

Apply on each Pi-hole instance:

```bash
pihole allow \
  mask.icloud.com \
  mask-h2.icloud.com \
  captive.apple.com \
  www.apple.com \
  push.apple.com \
  courier.push.apple.com
```

With a comment tag for traceability:

```bash
pihole allow --comment "GAP-OP-834 iCloud Private Relay whitelist" \
  mask.icloud.com \
  mask-h2.icloud.com \
  captive.apple.com \
  www.apple.com \
  push.apple.com \
  courier.push.apple.com
```

For shop (Docker), prefix with `sudo docker exec pihole`:

```bash
sudo docker exec pihole pihole allow --comment "GAP-OP-834 iCloud Private Relay whitelist" \
  mask.icloud.com mask-h2.icloud.com captive.apple.com \
  www.apple.com push.apple.com courier.push.apple.com
```

List current whitelist:

```bash
pihole allow --list
```

---

## Verify

After whitelisting, confirm resolution returns an A record (not NXDOMAIN):

```bash
dig mask.icloud.com @<pihole-ip>
```

Expected: A record pointing to a valid Apple CDN address (17.x.x.x range).
Failure: NXDOMAIN means the domain is still blocked — re-whitelist immediately.

---

## Maintenance Protocol

After every gravity update (`pihole -g`), re-run the dig checks:

```bash
dig mask.icloud.com @<pihole-ip>
dig mask-h2.icloud.com @<pihole-ip>
```

If any query returns NXDOMAIN, the blocklist update re-introduced the block. Re-run the whitelist command above immediately.

---

## Site Inventory

| Site | Host | Tailscale IP | Notes |
|------|------|-------------|-------|
| Shop | infra-core | 100.92.91.128 | Docker container, port 8053, SSH user `ubuntu` |
| Home | pihole-home | 100.105.148.96 | LXC 105, port 53, SSH user `root` |

---

## Post-Install Baseline (Day 1 Checklist)

Standard settings to configure on any new Pi-hole v6 instance.

### DNS

- **Upstream resolvers:** Cloudflare (1.1.1.1 / 1.0.0.1) for speed + privacy, or Quad9 (9.9.9.9) for built-in DNSSEC threat blocking
- **DNSSEC:** Leave enabled (default in v6)
- **Conditional forwarding:** Enable for local hostname resolution — point to your router IP (e.g. 10.0.0.1), local domain `lan` or `home.arpa`

### Privacy

- **Query logging:** Keep enabled — needed for troubleshooting and verifying blocks
- **Privacy level:** Default (show everything) until comfortable, then increase if desired

### Blocklists

- Default StevenBlack Unified Hosts List is a solid baseline
- Gravity updates: daily (automatic)
- After adding new lists, run `pihole -g` manually

### Common Whitelists (avoid breakage)

Beyond the iCloud domains above, these are frequently needed:

| Domain | Why |
|--------|-----|
| `login.microsoftonline.com` | Microsoft/O365 auth loops |
| `login.live.com` | Microsoft account sign-in |
| `msftconnecttest.com` | Windows connectivity check |
| `ocsp.apple.com` | Apple certificate validation |
| `s.youtube.com` | YouTube watch history |

```bash
pihole allow \
  login.microsoftonline.com \
  login.live.com \
  msftconnecttest.com \
  ocsp.apple.com \
  s.youtube.com
```

### Operational

- **Static IP:** Must be set before pointing clients to Pi-hole
- **HTTPS:** v6 has native TLS support — enable via web UI (auto-generated certs, 47-day auto-renewal)
- **Backup:** Configure immediately — Settings > Backup in web UI
- **Redundancy:** Two Pi-holes (shop + home) with the same config provides failover

---

## Tradeoff Note

When Private Relay is active, Pi-hole cannot filter DNS for that device. The policy is: **Private Relay wins.** This is an accepted tradeoff — user privacy via relay takes precedence over local DNS filtering for relay-enabled devices.

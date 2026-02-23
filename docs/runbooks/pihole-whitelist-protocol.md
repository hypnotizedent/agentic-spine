# Pi-hole Whitelist Standard Protocol

**Gap:** GAP-OP-834
**Scope:** Shop (docker-host) + Home (proxmox-home) Pi-hole instances

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

Apply on each Pi-hole instance:

```bash
pihole --white-list \
  mask.icloud.com \
  mask-h2.icloud.com \
  captive.apple.com \
  www.apple.com \
  push.apple.com \
  courier.push.apple.com
```

---

## Verify

After whitelisting, confirm resolution returns an A record (not NXDOMAIN):

```bash
dig mask.icloud.com @<pihole-ip>
```

Expected: A record pointing to a valid Apple CDN address.
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

| Site | Host | Tailscale IP |
|------|------|-------------|
| Shop | docker-host | 100.92.156.118 |
| Home | proxmox-home | 100.103.99.62 |

---

## Tradeoff Note

When Private Relay is active, Pi-hole cannot filter DNS for that device. The policy is: **Private Relay wins.** This is an accepted tradeoff — user privacy via relay takes precedence over local DNS filtering for relay-enabled devices.

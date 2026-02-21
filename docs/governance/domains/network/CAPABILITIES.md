---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-21
scope: domain-capability-catalog
domain: network
---

# network Capability Catalog

Generated from `ops/capabilities.yaml` by `catalog-domain-sync`.

| Capability | Safety | Approval | Implementation |
|---|---|---|---|
| `network.ap.facts.capture` | `read-only` | `manual` | `docs/infrastructure/domains/network/` |
| `network.cutover.preflight` | `read-only` | `auto` | `docs/infrastructure/domains/network/` |
| `network.home.dhcp.audit` | `read-only` | `auto` | `docs/infrastructure/domains/network/` |
| `network.home.dhcp.dns.set` | `mutating` | `manual` | `docs/infrastructure/domains/network/` |
| `network.home.dhcp.reservation.create` | `mutating` | `manual` | `docs/infrastructure/domains/network/` |
| `network.home.unifi.clients.snapshot` | `read-only` | `auto` | `docs/infrastructure/domains/network/` |
| `network.home.wifi.create` | `mutating` | `manual` | `docs/infrastructure/domains/network/` |
| `network.lan.device.status` | `read-only` | `auto` | `docs/infrastructure/domains/network/` |
| `network.lan.host.identify` | `read-only` | `auto` | `docs/infrastructure/domains/network/` |
| `network.md1400.bind_test` | `mutating` | `manual` | `docs/infrastructure/domains/network/` |
| `network.md1400.pm8072.stage` | `mutating` | `auto` | `docs/infrastructure/domains/network/` |
| `network.nvr.reip.canonical` | `mutating` | `manual` | `docs/infrastructure/domains/network/` |
| `network.oob.guard.status` | `read-only` | `auto` | `docs/infrastructure/domains/network/` |
| `network.pve.post_cutover.harden` | `mutating` | `auto` | `docs/infrastructure/domains/network/` |
| `network.shop.audit.canonical` | `read-only` | `auto` | `docs/infrastructure/domains/network/` |
| `network.shop.audit.status` | `read-only` | `auto` | `docs/infrastructure/domains/network/` |
| `network.shop.pihole.normalize` | `mutating` | `manual` | `docs/infrastructure/domains/network/` |
| `network.unifi.clients.snapshot` | `read-only` | `manual` | `docs/infrastructure/domains/network/` |

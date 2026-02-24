# W56 Phase 0 — Baseline Tracker

**Date:** 2026-02-24
**Branch:** `codex/w56-mintprints-cutover-20260224`
**Base commit:** `0ed4299`

## Run Keys

| Capability | Run Key | Status |
|---|---|---|
| session.start | CAP-20260224-133438__session.start__Rsxjv99894 | PASS |
| domains.namecheap.status | CAP-20260224-133448__domains.namecheap.status__Rfyft529 | PASS (7 checked, 0 failures) |
| cloudflare.status | CAP-20260224-133537__cloudflare.status__Ro1m52123 | PASS (7 zones) |
| cloudflare.dns.export | CAP-20260224-133628__cloudflare.dns.export__R8czw8477 | PASS |
| cloudflare.tunnel.ingress.status | CAP-20260224-133644__cloudflare.tunnel.ingress.status__R6lou10161 | PASS (41 rules) |
| cloudflare.domain_routing.diff | CAP-20260224-133705__cloudflare.domain_routing.diff__R09ii11752 | PASS (0 diffs) |
| verify.core.run | CAP-20260224-133715__verify.core.run__Rdp6w13352 | PASS (15/15) |
| verify.pack.run microsoft | n/a | 16/18 (D205/D208 calendar snapshot — non-domain noise) |
| verify.pack.run hygiene-weekly | n/a | 56/63 (D156/D161/D162/D201/D202/D205/D208 worktree artifact noise; D201/D202 fixed after snapshot copy) |

## Domain Gate Direct Checks

| Gate | Status |
|---|---|
| D195 (authority boundary) | PASS (zones=5) |
| D200 (canonical roots) | PASS (checks=4) |
| D201 (registrar parity) | PASS (after snapshot copy) |
| D202 (transfer readiness) | PASS |

## Key Findings

- **mintprints.com NS already at Cloudflare** (confirmed by user)
- CF zone has 23 DNS records, zone is authoritative
- Tunnel ingress has `customer.mintprints.com -> http://quote-page:3341`
- Tunnel ingress does NOT have `mintprints.com` or `www.mintprints.com` rules
- **BLOCKER:** Tunnel ingress rules needed for apex/www before DNS cutover
- Routing diff: 0 diffs (41/41 parity)

## Non-Domain Failures (Ignored)

- D156: coverage checker threshold (worktree)
- D161: receipt index empty (worktree)
- D162: calendar operator outputs stale
- D205/D208: calendar snapshots missing (worktree)

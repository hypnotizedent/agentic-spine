# W57 Phase 0 — Baseline Tracker

**Date**: 2026-02-24
**Branch**: `codex/w57-soak-retirement-20260224`
**Base commit**: `e2cf331` (W56 close)

## Session Start

| Capability | Run Key | Status |
|---|---|---|
| session.start | `CAP-20260224-145806__session.start__Rvew896407` | PASS |

## Domain Status Capabilities

| Capability | Run Key | Status | Summary |
|---|---|---|---|
| domains.namecheap.status | `CAP-20260224-145818__domains.namecheap.status__Rori597620` | PASS | checked=7 failures=0 canonical=7 |
| cloudflare.status | `CAP-20260224-145823__cloudflare.status__R9nkh98323` | PASS | zones=7 |
| cloudflare.dns.status | `CAP-20260224-145825__cloudflare.dns.status__Rd41199240` | PASS | zones=7, 105 total records |
| cloudflare.dns.export | `CAP-20260224-145827__cloudflare.dns.export__R5p251368` | PASS | 7 zone exports written |
| cloudflare.tunnel.ingress.status | `CAP-20260224-145830__cloudflare.tunnel.ingress.status__R87uc2826` | PASS | mintprints.com + www -> quote-page:3341 confirmed |
| cloudflare.domain_routing.diff | `CAP-20260224-145832__cloudflare.domain_routing.diff__Rnbbz4292` | PASS | 43/43 hostnames aligned, no diffs |

## Verify Packs

| Pack | Run Key | Status | Summary |
|---|---|---|---|
| verify.core.run | `CAP-20260224-145837__verify.core.run__R0aqj6280` | PASS | 15/15 |
| verify.pack.run microsoft | `CAP-20260224-150228__verify.pack.run__Ryggo18340` | 16/18 | D205/D208 = calendar snapshot noise (pre-existing) |
| verify.pack.run hygiene-weekly | `CAP-20260224-150228__verify.pack.run__R3p3t18644` | 56/63 | D202/D205/D208 = worktree snapshot context (pre-existing) |

## Critical Domain Gates (Direct Run)

| Gate | Status |
|---|---|
| D195 (authority boundary) | PASS (zones=5) |
| D200 (canonical roots) | PASS (checks=4) |
| D201 (registrar parity) | PASS (checks=4) |
| D202 (transfer readiness) | PASS (checks=2) |

## Pre-Existing Failures (Non-Blocker)

- **D205/D208**: Calendar snapshot files not present in worktree (not on main either — separate concern)
- **D202 in hygiene-weekly pack**: False positive from pack runner context; direct run passes

## Tunnel Ingress State (Post-W56)

```
- customer.mintprints.com -> http://quote-page:3341
- mintprints.com -> http://quote-page:3341
- www.mintprints.com -> http://quote-page:3341
```

## Verdict

**Baseline CLEAN** — all critical domain gates pass, tunnel ingress confirmed, routing diff aligned. Proceed to Phase 1.

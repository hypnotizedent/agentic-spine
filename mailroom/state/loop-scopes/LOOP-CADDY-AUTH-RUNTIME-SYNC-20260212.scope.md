---
status: closed
owner: "@ronny"
created: 2026-02-12
closed: 2026-02-12
---

# LOOP-CADDY-AUTH-RUNTIME-SYNC-20260212

> **Status:** closed
> **Owner:** @ronny
> **Created:** 2026-02-12
> **Closed:** 2026-02-12
> **Severity:** low

---

## Executive Summary

Sync live infra-core Caddy runtime with governed source after ingress cleanup.
The live Caddyfile on VM 204 had a residual commented-out Grafana block not
present in the repo source (`ops/staged/caddy-auth/Caddyfile`). Replaced live
config with governed source, reloaded Caddy, validated all 4 auth-proxied
routes respond correctly.

---

## Actions Taken

| # | Action | Result |
|---|--------|--------|
| 1 | Fetched live Caddyfile from infra-core | Found stale commented Grafana block |
| 2 | SCP governed Caddyfile to `/opt/stacks/caddy-auth/Caddyfile` | DONE |
| 3 | `caddy reload` via docker compose exec | SUCCESS — no config errors |
| 4 | Validated auth.ronny.works | HTTP 302 (0.047s) — Authentik redirect |
| 5 | Validated pihole.ronny.works | HTTP 302 (0.005s) — forward auth active |
| 6 | Validated vault.ronny.works | HTTP 302 (0.003s) — forward auth active |
| 7 | Validated secrets.ronny.works | HTTP 302 (0.002s) — forward auth active |
| 8 | Diff live vs repo | Zero diff — exact match |
| 9 | Container health check | All 5 containers Up (authentik-server/worker healthy) |

---

## What Was Removed (Live Only)

Commented-out Grafana block (`# http://{$GRAFANA_HOSTNAME}`) — legacy placeholder
from before Grafana moved to direct cloudflared routing via Tailscale IP. No
`GRAFANA_HOSTNAME` in `.env`, block was dead code.

---

## Outcome

- Live Caddyfile matches governed source: **YES**
- Dead blocks removed from live: **YES** (1 commented Grafana block)
- Caddy reload clean: **YES**
- 4/4 auth routes healthy: **YES**
- No production disruption: **YES**

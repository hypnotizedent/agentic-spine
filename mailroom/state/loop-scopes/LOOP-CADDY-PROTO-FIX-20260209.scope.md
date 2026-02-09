# LOOP-CADDY-PROTO-FIX-20260209

> **Status:** OPEN
> **Owner:** @ronny
> **Created:** 2026-02-09
> **Severity:** high
> **Origin:** SSO browser test for Gitea (LOOP-DEV-TOOLS-GITEA-STANDARDIZATION-20260209 P6)

---

## Executive Summary

Authentik OAuth2 flow for Gitea SSO failed with "Request failed. Please try again later." Root cause: Caddy reverse proxy passed `X-Forwarded-Proto: http` to Authentik because Cloudflare tunnel terminates TLS upstream. Authentik generated all OIDC discovery and OAuth redirect URLs with `http://` scheme, causing mixed-content browser failures.

Fix: Added `header_up X-Forwarded-Proto https` to all Authentik-facing `reverse_proxy` blocks in the Caddyfile. Verified OIDC discovery now returns `https://` URLs.

Additionally: staged Caddyfile was stale (missing forward-auth blocks for pihole, vault, secrets). Synced staged copy to match live + fix.

---

## Tasks

| Task | Action | Status |
|------|--------|--------|
| T1 | Diagnose "Request failed" on auth.ronny.works OAuth flow | **DONE** |
| T2 | Add `header_up X-Forwarded-Proto https` to all Authentik proxy blocks | **DONE** |
| T3 | Sync staged Caddyfile with live (was missing forward-auth blocks) | **DONE** |
| T4 | Deploy to infra-core + Caddy reload | **DONE** |
| T5 | Verify OIDC discovery returns https:// URLs | **DONE** |
| T6 | Audit all Authentik providers/apps/flows/outpost for other gaps | IN PROGRESS |
| T7 | Verify all proxied services healthy post-reload | IN PROGRESS |
| T8 | SSO browser test — user confirms login works | PENDING |
| T9 | spine.verify + close loop | PENDING |

---

## Root Cause

```
Browser (HTTPS) → Cloudflare Tunnel → cloudflared (HTTP) → Caddy (HTTP) → Authentik

Caddy's reverse_proxy sets X-Forwarded-Proto from what it sees (HTTP).
Authentik uses X-Forwarded-Proto to build OIDC URLs → generates http:// URLs.
Browser rejects mixed-content API calls → "Request failed."
```

## Fix Applied

```caddyfile
# Before (broken):
reverse_proxy 127.0.0.1:9000

# After (fixed):
reverse_proxy 127.0.0.1:9000 {
    header_up X-Forwarded-Proto https
}
```

Applied to all 5 Authentik-facing proxy blocks (auth, pihole outpost, vault outpost, secrets outpost, grafana template).

---

## Non-Goals

- Do NOT modify Authentik application/provider config (audit only)
- Do NOT add new Caddy sites
- Do NOT change CF tunnel routing

---

_Created: 2026-02-09_

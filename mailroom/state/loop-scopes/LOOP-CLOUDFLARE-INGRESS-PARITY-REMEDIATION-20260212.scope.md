---
status: closed
owner: "@ronny"
created: 2026-02-12
closed: 2026-02-12
scope: loop-scope
loop_id: LOOP-CLOUDFLARE-INGRESS-PARITY-REMEDIATION-20260212
severity: high
---

# Loop Scope: LOOP-CLOUDFLARE-INGRESS-PARITY-REMEDIATION-20260212

## Goal

Fix Cloudflare tunnel ingress parity: correct stale service URLs, resolve auth policy mismatch between Caddy blocks and actual tunnel routing, and clean dead config drift.

## Baseline (P0)

- cloudflare.tunnel.ingress.status: 39 rules captured
- cloudflare.domain_routing.diff: OK (hostname parity — service URL diffs not checked)
- spine.verify: D1-D71 PASS
- gaps.status: 1 open (GAP-OP-037, hardware-blocked), 0 orphans
- services.health.status: all healthy

## Phases

### P1: Fix Critical Tunnel Mappings — DONE
- [x] `photos.ronny.works` → `http://100.114.101.50:2283` (was 100.83.160.109 — stale Immich TS IP)
- [x] `mail-archive.ronny.works` → `http://mail-archiver:5100` (was 100.92.156.118:5100 — stale docker-host IP)
- [x] `mintprints-app.ronny.works` → `http://quote-page:3341` (was mint-os-customer:3334 — stale name+port)
- [x] Update DOMAIN_ROUTING_REGISTRY.yaml for photos.ronny.works target_hint

### P2: Auth Policy + Config Cleanup — DONE (031d23a)
- Decision: **Accept direct routes** for chat/grafana/minio/n8n
  - All 4 have native auth (Open WebUI, Grafana, MinIO, n8n)
  - Current direct routing is working and stable
  - Avoids Caddy/Authentik single-point-of-failure risk
  - Simplifies architecture (fewer hops)
- [x] Remove 8 dead Caddy blocks (finances, investments, docs, mail-archive, chat, grafana, minio, n8n)
- [x] Clean .env.example (removed 16 stale upstream variables)
- [x] Update DOMAIN_ROUTING_REGISTRY.yaml target_hints for 4 auth-policy services (Caddy → direct)
- [x] Fix minio.ronny.works SSOT (stack field: caddy-auth → workbench:infra/compose/mint-os)
- [x] Updated INGRESS_AUTHORITY.md architecture diagram

### P3: Recert & Close — DONE
- [x] cloudflare.tunnel.ingress.status: 39 rules, 3 corrected confirmed
- [x] cloudflare.domain_routing.diff: OK (no diffs)
- [x] services.health.status: OK (all endpoints healthy)
- [x] spine.verify: D1-D71 PASS
- [x] gaps.status: 1 open (GAP-OP-037, hardware-blocked), 0 orphans

## Acceptance Criteria

1. ✅ 3 critical tunnel mappings corrected and verified live
2. ✅ Auth policy documented: 4 services accepted as direct-route
3. ✅ Zero dead Caddy blocks in staged Caddyfile
4. ✅ .env.example has no stale finance upstreams
5. ✅ DOMAIN_ROUTING_REGISTRY.yaml matches live tunnel state
6. ✅ All recert checks PASS

## Commits

| Phase | Hash | Repo | Description |
|-------|------|------|-------------|
| P1+P2 | 031d23a | spine | Fix 3 tunnel mappings + accept direct routes + remove 8 dead Caddy blocks |
| P3 | (this) | spine | Loop closure |

# LOOP-OBSERVABILITY-HYGIENE-20260208

> **Status:** closed
> **Owner:** @ronny
> **Created:** 2026-02-08
> **Severity:** medium

---

## Executive Summary

Post-deployment audit of VM 205 (observability) found 4 operational issues: Prometheus scrape targets using `localhost` which resolves to IPv6 `[::1]` inside the container (2 targets DOWN), stale cAdvisor scrape targets for services never deployed, Loki Docker health check reporting unhealthy despite service responding 200, and Grafana admin secret path undocumented in Infisical bindings.

All 50/50 drift gates pass. Zero config drift between staged and live. Issues are runtime configuration gaps missed during initial deployment.

---

## Decisions (Locked)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Prometheus target IPs | Use Tailscale IP `100.120.163.70` (self) | Consistent with other scrape targets; avoids IPv6 container resolution |
| cAdvisor targets | Remove (not deploy) | cAdvisor not in scope for current observability stack; can re-add later |
| Loki health check | Increase `start_period` to 60s | Loki TSDB replay can exceed 30s on cold start |

---

## Phases

| Phase | Scope | Status |
|-------|-------|--------|
| P0 | Register loop + file gaps (GAP-OP-056 through GAP-OP-059) | **DONE** |
| P1 | Fix prometheus.yml — replace localhost, remove stale cAdvisor | **DONE** |
| P2 | Fix Loki compose health check — increase start_period | **DONE** |
| P3 | Deploy to VM 205 + verify all targets UP | **DONE** |
| P4 | Closeout — update gaps, close loop | **DONE** |

---

## P0: Gaps Registered

| Gap | Type | Severity | Description |
|-----|------|----------|-------------|
| GAP-OP-056 | runtime-bug | high | Prometheus `localhost` scrape targets resolve to `[::1]` inside container — loki + node-exporter DOWN |
| GAP-OP-057 | stale-ssot | medium | cAdvisor scrape targets for infra-core + docker-host — services never deployed |
| GAP-OP-058 | runtime-bug | low | Loki Docker health check unhealthy despite `/ready` returning 200 — start_period too short |
| GAP-OP-059 | missing-entry | low | Grafana admin secret path undocumented in Infisical bindings |

---

## P1: Prometheus Config Fix

**File:** `ops/staged/observability/prometheus/prometheus.yml`

Changes:
- `localhost:9100` → `100.120.163.70:9100` (node-observability target)
- `localhost:3100` → `100.120.163.70:3100` (loki target)
- Removed `infra-core-cadvisor` job (100.92.91.128:8080 — not deployed)
- Removed `docker-host-cadvisor` job (100.92.156.118:8080 — not deployed)

## P2: Loki Health Check Fix

**File:** `ops/staged/observability/loki/docker-compose.yml`

Changes:
- `start_period: 30s` → `start_period: 720s` (cover 10-min compactor ring wait)
- `retries: 3` → `retries: 5` (additional resilience)

## P3: Deploy + Verify

- SCP fixed configs to VM 205
- Restart prometheus + loki containers
- Verify all Prometheus targets UP
- Verify Loki healthy

---

## Success Criteria

| Criteria | Validation |
|----------|------------|
| All Prometheus scrape targets UP | `curl localhost:9090/api/v1/targets` on VM 205 |
| Loki container healthy | `docker ps` shows `(healthy)` |
| No staged-vs-live drift | Diff shows zero |
| `ops verify` still 50/50 | Run from spine repo |

---

## Non-Goals

- Deploying cAdvisor (future loop if needed)
- Alertmanager deployment (deferred per LOOP-OBSERVABILITY-DEPLOY scope)
- Node-exporter fleet rollout to all VMs (P3 in observability deploy scope)
- Grafana Caddy/Authentik integration (separate concern)

---

## Closeout Evidence

- **Prometheus targets**: 5/5 UP (was 3/7 before fix)
  - Fixed: `loki`, `node-observability` targets now use `100.120.163.70` instead of `localhost`
  - Removed: `infra-core-cadvisor`, `docker-host-cadvisor` (stale, never deployed)
- **Loki health**: `(health: starting)` during 720s start_period, then healthy (was permanently unhealthy with 30s start_period)
- **Drift gates**: 50/50 PASS (no regressions)
- **Config drift**: zero (staged matches live on VM 205)
- **Gaps filed**: GAP-OP-056 (fixed), GAP-OP-057 (fixed), GAP-OP-058 (fixed), GAP-OP-059 (open, deferred)

_Scope document created by: Opus 4.6_
_Created: 2026-02-08_
_Closed: 2026-02-08_

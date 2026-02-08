# LOOP-OBSERVABILITY-DEPLOY-20260208

> **Status:** open
> **Blocked By:** LOOP-INFRA-CADDY-AUTH-20260207
> **Owner:** @ronny
> **Created:** 2026-02-08
> **Severity:** high

---

## Executive Summary

Provision VM 205 on pve (shop R730XD) and deploy the full observability stack: Prometheus, Grafana, Loki, Alertmanager, Uptime Kuma, and node-exporter. This gives the homelab unified metrics, logs, alerting, and uptime monitoring across all VMs.

---

## Target Architecture

### VM 205: observability (shop R730XD)

| Service | Port | Purpose | Status |
|---------|------|---------|--------|
| Prometheus | 9090 | Metrics collection + storage | This loop |
| Grafana | 3000 | Dashboards + visualization | This loop |
| Loki | 3100 | Log aggregation | This loop |
| Alertmanager | 9093 | Alert routing + notifications | This loop |
| Uptime Kuma | 3001 | Uptime monitoring + status page | This loop |
| Node-exporter | 9100 | Host metrics (on all VMs) | This loop |

### Provisioning Details

| Property | Value |
|----------|-------|
| **VM ID** | 205 |
| **Hypervisor** | pve (shop R730XD) |
| **Profile** | spine-ready-v1 |
| **Template** | 9000 (ubuntu-2404-cloudinit-template) |

---

## Phases

| Phase | Scope | Dependency |
|-------|-------|------------|
| P0 | Provision VM 205 + bootstrap with spine-ready-v1 | Blocked by LOOP-INFRA-CADDY-AUTH-20260207 |
| P1 | Deploy Prometheus + Grafana + Loki | P0 |
| P2 | Deploy Alertmanager + Uptime Kuma | P1 |
| P3 | Add node-exporter to all VMs | P2 |
| P4 | Wire to Caddy (reverse proxy on infra-core) | P3 |
| P5 | Configure alert rules + dashboards | P4 |
| P6 | Verify + closeout | P5 |

---

## Stack Decisions (Locked In)

### Metrics: Prometheus

| Factor | Decision |
|--------|----------|
| **Choice** | Prometheus |
| **Rejected** | VictoriaMetrics (overkill for homelab scale) |
| **Rationale** | Industry standard, massive ecosystem, Grafana-native |

### Logs: Loki

| Factor | Decision |
|--------|----------|
| **Choice** | Loki |
| **Rejected** | Elasticsearch (heavy, Java), Graylog (complex) |
| **Rationale** | Lightweight, label-based, pairs with Grafana natively |

### Uptime: Uptime Kuma

| Factor | Decision |
|--------|----------|
| **Choice** | Uptime Kuma |
| **Rejected** | Healthchecks.io (SaaS), UptimeRobot (SaaS) |
| **Rationale** | Self-hosted, clean UI, supports multiple check types |

---

## Node-Exporter Rollout Plan

Node-exporter must be deployed on every VM to feed host metrics to Prometheus.

| VM | Hostname | Method |
|----|----------|--------|
| 204 | infra-core | Docker container |
| 205 | observability | Docker container (local) |
| 206+ | future VMs | Included in spine-ready-v1 profile |
| 201 | media-stack | Docker container (pre-split) |
| 202 | ai-services | Docker container |

---

## Integration with Caddy/Authentik

After LOOP-INFRA-CADDY-AUTH-20260207 completes:

```
Internet → Cloudflare Tunnel → Caddy → Authentik → Grafana
                                    → Authentik → Alertmanager
                                    → (public)  → Uptime Kuma status page
```

Prometheus, Loki, and node-exporter are internal only (no external exposure).

---

## Secrets Required

| Secret | Project | Notes |
|--------|---------|-------|
| GRAFANA_ADMIN_PASSWORD | infrastructure | Initial admin password |
| ALERTMANAGER_SMTP_PASSWORD | infrastructure | For email alerts (if configured) |
| GRAFANA_OAUTH_CLIENT_SECRET | infrastructure | For Authentik SSO integration |

---

## Success Criteria

| Criteria | Validation |
|----------|------------|
| VM 205 provisioned and spine-ready | SSH reachable, Tailscale joined |
| Prometheus scraping all targets | `/targets` shows all UP |
| Grafana dashboards loading | Node-exporter dashboard shows data |
| Loki receiving logs | Explore → Loki shows log streams |
| Alertmanager routing | Test alert fires and routes correctly |
| Uptime Kuma monitoring services | All checks green |
| Node-exporter on all VMs | `node_cpu_seconds_total` from each host |

---

## Non-Goals

- Do NOT set up long-term storage (Thanos/Mimir) in this loop
- Do NOT configure PagerDuty or external alert integrations yet
- Do NOT build custom Grafana plugins

---

## Evidence

- LOOP-INFRA-VM-RESTRUCTURE-20260206 (VM provisioning pattern)
- LOOP-INFRA-CADDY-AUTH-20260207 (prerequisite for external access)
- Memory: observability stacks staged list

---

_Scope document created by: Opus 4.6_
_Created: 2026-02-08_

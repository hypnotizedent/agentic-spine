---
status: draft
owner: "@ronny"
created: 2026-02-12
scope: pricing-health-spec
---

# Pricing Health Spec

> Defines health endpoint contract, minimum metrics, degradation criteria,
> and timeout/retry expectations for the pricing service.

## 1. Health Endpoint (`/health`)

```
GET /health
```

### Response (200 OK — Healthy)

```jsonc
{
  "status": "healthy",
  "version": "1.0.0",
  "uptime_seconds": 3600,
  "checks": {
    "pricing_rules_loaded": true,
    "catalog_reachable": true
  }
}
```

### Response (503 — Degraded or Failed)

```jsonc
{
  "status": "degraded",           // or "failed"
  "version": "1.0.0",
  "uptime_seconds": 15,
  "checks": {
    "pricing_rules_loaded": true,
    "catalog_reachable": false    // false triggers degraded
  }
}
```

### Status Values

| Status | HTTP | Meaning |
|--------|------|---------|
| `healthy` | 200 | All checks pass; service fully operational |
| `degraded` | 503 | Partial functionality; at least one non-critical check failing |
| `failed` | 503 | Critical check failing; service cannot price requests |

### Check Definitions

| Check | Critical | Description |
|-------|----------|-------------|
| `pricing_rules_loaded` | yes | Pricing rule tables loaded in memory |
| `catalog_reachable` | no | Product catalog data source is reachable |

**Critical check failure = `failed` status.**
**Non-critical check failure = `degraded` status.**

## 2. Metrics Endpoint (`/metrics`)

```
GET /metrics
```

Returns Prometheus-compatible text format. Minimum required metrics:

| Metric | Type | Description |
|--------|------|-------------|
| `pricing_requests_total` | counter | Total price calculation requests |
| `pricing_request_duration_seconds` | histogram | Latency of `/api/v1/price` |
| `pricing_errors_total` | counter | Total error responses (label: `code`) |
| `pricing_rules_count` | gauge | Number of active pricing rules loaded |
| `pricing_health_status` | gauge | 1 = healthy, 0.5 = degraded, 0 = failed |

## 3. Degraded vs Fail Criteria

```
                  pricing_rules_loaded?
                     /           \
                   YES            NO
                   /                \
        catalog_reachable?       status: FAILED
           /        \            (503, no pricing possible)
         YES         NO
          |           |
     HEALTHY      DEGRADED
     (200)        (503, can still price
                   with cached catalog)
```

**Degraded behavior:** The service continues to respond to `/api/v1/price`
using cached/stale catalog data. Responses include a `Warning` header:

```
Warning: 199 pricing "catalog data may be stale"
```

**Failed behavior:** The service returns `503 SERVICE_UNAVAILABLE` for all
`/api/v1/price` requests until pricing rules are reloaded.

## 4. Timeout Budget

| Hop | Budget | Notes |
|-----|--------|-------|
| Cloudflare tunnel -> pricing | 5s | CF default; no override needed |
| quote-page -> pricing | 3s | Client-side timeout for real-time UX |
| order-intake -> pricing | 5s | Slightly longer; order confirmation is less latency-sensitive |
| `/health` probe (spine) | 2s | Spine health probe timeout per `services.health.yaml` |

**Target p99 latency for `/api/v1/price`:** < 500ms.

## 5. Retry Expectations

| Caller | Retry Policy | Notes |
|--------|-------------|-------|
| quote-page | 1 retry after 1s, then show stale/cached price or error | UX must not block indefinitely |
| order-intake | 2 retries with exponential backoff (1s, 2s), then fail order confirmation | Order cannot proceed without a locked price |
| spine health probe | No retry; mark unhealthy on first failure | Probe runs on 30s interval; transient failures resolve on next cycle |

**Idempotency keys make retries safe** — repeated requests with the same key return cached results without recomputation.

## 6. Spine Integration

The pricing health probe is registered in `ops/bindings/services.health.yaml`.
When the service is deployed to mint-apps VM 213, the probe URL will be:

```yaml
- id: pricing
  host: mint-apps
  url: "http://100.79.183.14:3001/health"
  expect: 200
  timeout: 2000
  enabled: false  # enable when service is deployed to fresh-slate
```

Current legacy probe (docker-host) is tracked via the existing estimator entry.

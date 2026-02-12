---
status: draft
owner: "@ronny"
created: 2026-02-12
scope: pricing-api-boundary
---

# Pricing API Boundary

> Defines ownership, request/response contracts, error handling, idempotency,
> versioning, and integration touchpoints for the pricing service.

## 1. Ownership Boundary

The pricing service owns **pricing logic only**:

| Owns | Does NOT Own |
|------|-------------|
| Price calculation for line items | Order persistence (order-intake) |
| Quantity break tables | Customer display/quoting (quote-page) |
| Decoration method cost modifiers | Financial ledger entries (finance-adapter) |
| Margin and markup application | Product catalog data |
| Pricing rule evaluation | Inventory or fulfillment |

**Deployment:** `pricing.mintprints.co` on docker-host (legacy, port 3001).
**Fresh-slate target:** mint-apps VM 213 behind `/api/v1/` prefix.
**Secrets namespace:** `/spine/services/pricing/` (declared in `secrets.namespace.policy.yaml`).

## 2. API Contract (Draft)

### Base

```
POST /api/v1/price
Content-Type: application/json
```

### Request Schema

```jsonc
{
  "items": [
    {
      "product_sku": "string",         // required — catalog SKU
      "quantity": 1,                    // required — integer > 0
      "decoration_method": "string",   // required — e.g. "screen_print", "dtg", "embroidery"
      "color_count": 1,                // optional — number of ink colors (screen_print)
      "location_count": 1,             // optional — number of imprint locations
      "options": {}                    // optional — method-specific overrides
    }
  ],
  "customer_id": "string|null",        // optional — for customer-specific pricing tiers
  "idempotency_key": "string"          // required — caller-generated UUID v4
}
```

### Response Schema (200 OK)

```jsonc
{
  "idempotency_key": "string",
  "currency": "USD",
  "items": [
    {
      "product_sku": "string",
      "quantity": 1,
      "unit_price_cents": 1500,        // integer — price per unit in cents
      "line_total_cents": 1500,        // integer — unit_price * quantity
      "breakdown": {
        "base_price_cents": 1200,
        "decoration_cents": 300,
        "quantity_discount_cents": 0
      }
    }
  ],
  "subtotal_cents": 1500,
  "computed_at": "2026-02-12T12:00:00Z"
}
```

**All monetary values are integers in cents (USD).** No floating-point currency math.

## 3. Error Contract

All errors follow a uniform envelope:

```jsonc
{
  "error": {
    "code": "VALIDATION_ERROR",       // machine-readable error code
    "message": "human-readable text",
    "details": []                     // optional — per-field validation errors
  }
}
```

| HTTP Status | Code | When |
|-------------|------|------|
| 400 | `VALIDATION_ERROR` | Malformed request, missing required fields |
| 400 | `UNKNOWN_SKU` | Product SKU not found in catalog |
| 400 | `UNKNOWN_DECORATION` | Decoration method not recognized |
| 409 | `IDEMPOTENCY_CONFLICT` | Same key reused with different payload |
| 422 | `PRICING_RULE_ERROR` | Valid input but no pricing rule matches |
| 500 | `INTERNAL_ERROR` | Unexpected failure |
| 503 | `SERVICE_UNAVAILABLE` | Pricing service degraded or starting |

## 4. Idempotency

- Every `POST /api/v1/price` request **must** include an `idempotency_key` (UUID v4).
- Identical key + identical payload = cached response (no recomputation).
- Identical key + **different** payload = `409 IDEMPOTENCY_CONFLICT`.
- Keys expire after **24 hours**. After expiry, the same key may be reused.
- Idempotency is scoped to the pricing service only; it does not propagate to downstream consumers.

## 5. Versioning

Follows the mint-modules API contract rules (MINT_PRODUCT_GOVERNANCE.md section 3):

- All endpoints use `/api/v<N>/` prefix.
- Breaking changes (field removal, type change, endpoint removal) require a major version bump and 30-day deprecation window.
- Additive changes (new optional fields, new endpoints) are minor bumps with no prefix change.
- Current version: **v1** (draft).

## 6. Integration Touchpoints

```
quote-page ──POST /api/v1/price──> pricing
                                      │
order-intake ─reads pricing at────────┘
              order confirmation time
                                      │
finance-adapter ─reads final price────┘
                 to create Firefly
                 transaction entries
```

| Consumer | Interaction | Direction | Notes |
|----------|------------|-----------|-------|
| **quote-page** | `POST /api/v1/price` | quote-page -> pricing | Real-time pricing during customer quote flow |
| **order-intake** | `POST /api/v1/price` | order-intake -> pricing | Price lock at order confirmation; stores `unit_price_cents` in order record |
| **finance-adapter** | Reads locked price from order record | finance-adapter -> order-intake (not pricing directly) | Finance-adapter does NOT call pricing; it trusts the locked price on the order |

**Key rule:** Once order-intake locks a price into an order record, that price is immutable.
The pricing service may update rules at any time, but existing orders retain their locked price.

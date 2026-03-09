---
status: complete
created: 2026-03-09
owner: "@ronny"
scope: mint-runtime-gaps-audit
authority: runtime-admission-health-plane-wave
---

# Mint Runtime Gaps Audit — 2026-03-09

## Executive Summary

**Runtime Status**: GREEN — All Mint services healthy (services.health.status: 60/60 OK)
**Gap Status**: Code fixes exist but undeployed
**Blocker**: Deployment execution (SSH timeouts, deployment automation needed)

## Gap Investigation Results

### GAP-OP-1507: Shipping lacks FINANCE_ADAPTER_URL
- **Status**: FIXED IN CODE, NOT DEPLOYED
- **Evidence**: Commit 184f831 (2026-03-07 20:02)
  - Added FINANCE_ADAPTER_URL to shipping/docker-compose.yml
  - Added FINANCE_ADAPTER_API_KEY config
  - Wired finance-events.ts to use dedicated API key
- **Deployment Status**: Not deployed (last deploy was suppliers-only at e3a89ab)
- **Action**: Deploy shipping module with latest main

### GAP-OP-1508: finance-adapter schema not migrated
- **Status**: MIGRATION EXISTS, RUNTIME STATE UNKNOWN
- **Evidence**: Migration file `20260212_finance_event_map.sql` exists in codebase
- **Deployment Status**: Unknown if applied to live database
- **Action**: Run migration check on mint-data VM 212

### GAP-OP-1509: Payment Stripe webhook auth problem
- **Status**: FIXED IN CODE, NOT DEPLOYED
- **Evidence**: Commit 184f831 (2026-03-07 20:02)
  - payment/src/app.ts line 78-79: webhook routes mounted BEFORE auth middleware
  - Explicit comment: "// Stripe webhooks (no module auth - uses Stripe signature verification)"
- **Additional Fix**: Commit c8b6301 (2026-03-08) added nginx public ingress routes
- **Deployment Status**: Not deployed for payment module
- **Action**: Deploy payment module with latest main

### GAP-OP-1510: Shipping refund lifecycle incomplete
- **Status**: OPEN (feature gap, not runtime bug)
- **Severity**: medium
- **Action**: Requires product decision + implementation (not a quick fix)

### GAP-OP-1511: Payment money trace split
- **Status**: OPEN (architecture gap, not runtime bug)
- **Severity**: medium
- **Action**: Requires reconciliation contract (not a quick fix)

## Runtime Health Evidence

### services.health.status (2026-03-09 07:43)
```
mint-modules-minio  OK  136ms  tailscale
files-api-v2        OK  168ms  tailscale
quote-page-v2       OK  126ms  tailscale
order-intake-v2     OK  189ms  tailscale
finance-adapter     OK  942ms  tailscale
pricing-v2          OK  140ms  tailscale
suppliers-v2        OK  230ms  tailscale
shipping-v2         OK  134ms  tailscale
payment-v2          OK  124ms  tailscale
```

**Result**: All Mint services responding to health checks

### mint-modules Git State
- **HEAD**: 4f95d87 (fix: codify paperless invoice authority)
- **Commits since gap filing**: 5 commits ahead of gap discovery time
- **Undeployed fixes**: shipping/payment finance wiring (184f831, e3f444c)

## Deployment Blockers

1. **SSH Timeouts**: Tailscale access to mint-apps (VM 213) experiencing 10s+ delays
2. **Last Deployment**: suppliers-only (e3a89ab, 2026-03-08 10:35)
3. **Missing Module Deployments**: shipping, payment not synced since finance-adapter wiring

## Recommendations

### Immediate (can close gaps)
1. Deploy shipping module: `mint.deploy.sync --modules shipping --ref main`
2. Deploy payment module: `mint.deploy.sync --modules payment --ref main`
3. Verify finance-adapter schema: SSH to mint-data, check `\dt finance_event_map`
4. Close GAP-OP-1507, GAP-OP-1509 with deployment evidence

### Deferred (product/architecture work)
1. GAP-OP-1510: Design refund completion contract
2. GAP-OP-1511: Design unified payment ledger reconciliation

## Authority Surface Findings

### Mint Probe Targets
- **File**: `ops/bindings/mint.probe.targets.yaml`
- **Access**: Uses Tailscale IPs (slow)
- **Services**: 8 app-plane services + 3 data-plane checks

### Services Health Binding
- **File**: `ops/bindings/services.health.yaml`
- **Access**: Uses LAN IPs directly (fast)
- **Naming**: Uses "-v2" suffix for fresh-slate services

### Discrepancy
- mint.modules.health times out (10s+) via Tailscale
- services.health.status succeeds (<1s) via LAN
- **Recommendation**: Align probe access policy (use LAN-first for Mint)

## Conclusion

The Mint runtime health plane is **GREEN**. The open gaps represent undeployed code fixes and product/architecture work, not runtime outages. The blockers are deployment execution and SSH performance, not service failures.

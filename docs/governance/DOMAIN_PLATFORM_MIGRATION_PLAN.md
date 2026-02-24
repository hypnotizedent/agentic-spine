---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-23
scope: domain-platform-migration-plan
---

# Domain Platform Migration Plan: Namecheap -> Cloudflare Registrar

**Status:** PLAN-ONLY (no execution authorized)
**Created:** 2026-02-23
**Owner:** @ronny
**Task ID:** SPINE-W49-DOMAIN-PLATFORM-MIGRATION-PLAN-ONLY-20260224
**Canonical roots:** `ops/bindings/domain.canonical.roots.yaml`

## Executive Summary

Migrate 2 of 3 canonical domain roots from Namecheap (registrar) to Cloudflare Registrar. DNS authority is delegated to Cloudflare for all 3 zones. mintprints.com DNS was migrated from Namecheap to Cloudflare on 2026-02-24 (W49.4). ronny.works is excluded — Cloudflare Registrar does not support the `.works` TLD (stays at Namecheap, DNS at Cloudflare). This migration is registrar-only (domain registration transfer, not DNS migration).

Non-canonical domains (brand protection, parked) are tracked in workbench legacy docs only and are out of scope for this plan.

---

## Current State

| Domain | Zone | Registrar | DNS | Email | Criticality | Wave |
|--------|------|-----------|-----|-------|-------------|------|
| ronny.works | ronny | Namecheap (permanent — .works TLD unsupported by CF Registrar) | Cloudflare | None active (legacy MX unused) | P1 | N/A |
| mintprints.co | mintprints | Namecheap | Cloudflare | Resend/AWS SES | P1 | W2 |
| mintprints.com | mintprints | Namecheap | Cloudflare (migrated 2026-02-24) | Microsoft 365 | **P0** | W3 |

**SSOT:** `ops/bindings/domain.portfolio.registry.yaml`

---

## Workstreams

### Workstream A: Registrar Transfer (Namecheap -> Cloudflare Registrar)

**Scope:** Move domain registration for 3 canonical roots to Cloudflare Registrar.

**Prerequisites (all domains):**
1. DNS must be on Cloudflare (satisfied for all 3 as of 2026-02-24)
2. Domain must be unlocked at Namecheap
3. EPP/auth code obtained from Namecheap
4. Domain must not be within 60 days of registration/last transfer
5. Domain must not be within 60 days of expiry (Cloudflare requirement)
6. WHOIS admin email must be accessible (for ICANN approval)

**Per-domain transfer procedure:**
1. Verify domain eligibility (expiry date, lock status, 60-day windows)
2. Disable registrar lock at Namecheap
3. Request EPP/auth code from Namecheap
4. Initiate transfer at Cloudflare Registrar dashboard
5. Enter EPP code
6. Approve ICANN transfer confirmation email
7. Wait for transfer completion (up to 5 days, usually <24h)
8. Verify DNS records unchanged post-transfer
9. Verify email delivery unchanged (for email-bearing domains)
10. Re-enable registrar lock at Cloudflare

**Wave execution order:**

#### ~~Wave 1 — Personal Infrastructure (ronny.works)~~ CANCELLED
- **Reason:** Cloudflare Registrar does not support `.works` TLD. Domain stays at Namecheap.
- DNS at Cloudflare, no service impact. No email in use on @ronny.works.

#### Wave 2 — Business Operations (mintprints.co, medium risk)
- 16 tunnel-routed services + Resend transactional email
- DNS records (MX, SPF, DKIM, DMARC) already at Cloudflare — no change expected
- **Action required:** Enable registrar lock at Namecheap (currently OFF as of 2026-02-24 snapshot)
- Validation: customer.mintprints.co reachable, test transactional email send/receive

#### Wave 3 — Business Primary (mintprints.com, HIGH risk)
- Microsoft 365 email + Shopify storefront
- DNS migrated to Cloudflare (completed 2026-02-24, W49.4)
- **Requires email parity gate (see Gate G1)**
- **Requires transfer-readiness gate D202 to pass**
- Validation: Outlook send/receive matrix, Shopify storefront loads, DNS records unchanged

---

### ~~Workstream A.email: ronny.works Email Forwarding Migration~~ CANCELLED

**Reason:** ronny.works registrar transfer cancelled (`.works` TLD unsupported by Cloudflare Registrar). No active email on @ronny.works — legacy MX records are unused Namecheap defaults. No migration needed.

---

### Workstream B: mintprints.co -> mintprints.com Product Cutover

**Scope:** Migrate customer-facing services from mintprints.co to mintprints.com subdomains.

**Cutover approach:**
1. Create new CNAME records on mintprints.com pointing to CF tunnel
2. Update CF tunnel ingress to accept new hostnames
3. Configure old hostnames (mintprints.co) as redirects to mintprints.com equivalents
4. Run dual-domain period (both .co and .com serve traffic) for 30 days minimum
5. Monitor for hardcoded .co references in code, email templates, printed materials
6. Cut .co redirects to permanent (301) after validation period
7. Keep .co registration active (brand protection) but redirect-only

**Dependencies:**
- mintprints.com Cloudflare zone ID must be inventoried first
- Tunnel ingress config must be updated
- Resend transactional email sender domain decision (.co vs .com)

**Timeline:** Not before W3 registrar transfer is complete.

---

### Workstream C: Shopify -> Self-Hosted Website Migration (DEFERRED)

**This workstream is DEFERRED.** Documented for completeness only.

---

## Hard Gates

### G1: mintprints.com Email Parity Gate (P0)

**Trigger:** Must pass before W3 (mintprints.com registrar transfer).

**Checks:**
1. MX records at Cloudflare match current Microsoft 365 MX configuration
2. SPF record includes Microsoft 365 SPF
3. DKIM records present for Microsoft 365
4. DMARC record present and policy appropriate
5. Send test: internal -> ronny@mintprints.com delivers
6. Send test: ronny@mintprints.com -> external delivers
7. Send test: external -> ronny@mintprints.com delivers
8. Outlook mobile/desktop sync confirmed

**Pass criteria:** All 8 checks green. Any failure = no-go.

### ~~G2: ronny.works Email Migration Gate~~ CANCELLED

**Reason:** W1 cancelled — `.works` TLD unsupported by Cloudflare Registrar. No email in use on @ronny.works.

### G3: Service Continuity Gate (per wave)

**Trigger:** Must pass 24h after each wave completes.

**Checks:**
1. All tunnel-routed services for the wave's domain(s) respond HTTP 200
2. DNS resolution returns expected records
3. WHOIS shows Cloudflare as registrar
4. No customer-reported issues
5. Uptime Kuma shows no alerts for affected services

**Pass criteria:** All 5 checks green for 24h.

---

## Freeze Windows

- **No transfers during:** Active customer campaigns, invoice periods, or holidays
- **Preferred window:** Weekday mornings (EST), outside business hours
- **TTL staging:** Lower DNS TTLs to 60s 48h before any transfer. Restore to 3600s after validation.
- **Minimum gap between waves:** 7 days (validate previous wave fully before starting next)

---

## Rollback Criteria

### Per-domain rollback (registrar transfer):
- Registrar transfers are **not easily reversible** once complete (60-day lock at new registrar)
- Mitigation: DNS stays at Cloudflare regardless of registrar — service continuity is maintained
- If email breaks: Manually update MX/SPF/DKIM at Cloudflare DNS (immediate, no registrar dependency)

### No-go criteria (abort transfer):
- EPP code not received within 48h
- ICANN approval email not received
- Any email delivery failure during pre-transfer testing
- Expiry within 60 days — renew at Namecheap first, then transfer

---

## Unknowns and Blockers

### Blockers (must resolve before execution)

| ID | Blocker | Domain | Resolution |
|----|---------|--------|------------|
| B1 | mintprints.com Cloudflare zone ID not in inventory | mintprints.com | Query CF API or dashboard |
| B2 | mintprints.com DNS export missing | mintprints.com | Export current DNS records from Cloudflare |
| B3 | ronny.works email forwarding rules unknown | ronny.works | Export current rules from Namecheap dashboard |
| B4 | ~~Domain expiry dates stale~~ | All | **RESOLVED** via Namecheap API (W49.2, 2026-02-24) |
| B5 | mintprints.com MX/SPF/DKIM records not documented | mintprints.com | Export from Cloudflare DNS or M365 admin |
| B6 | Shopify DNS requirements undocumented | mintprints.com | Check Shopify admin for required DNS records |
| B7 | ~~mintprints.com DNS still at Namecheap~~ | mintprints.com | **RESOLVED** — NS migrated to Cloudflare 2026-02-24 (W49.4) |

---

## Risk Assessment: mintprints.com

| Factor | Assessment | Score |
|--------|-----------|-------|
| Email provider (Microsoft 365) | High complexity | 8/10 |
| Customer-facing storefront (Shopify) | Medium | 4/10 |
| DNS at Cloudflare (migrated 2026-02-24) | Low | 2/10 |
| Transfer lock period | Medium | 5/10 |
| Business continuity | High | 9/10 |
| **Composite risk score** | | **5.6/10** |

---

## Cross-References

| Document | Path |
|----------|------|
| Canonical Roots | `ops/bindings/domain.canonical.roots.yaml` |
| Domain Portfolio | `ops/bindings/domain.portfolio.registry.yaml` |
| Domain Routing | `docs/governance/DOMAIN_ROUTING_REGISTRY.yaml` |
| Cloudflare Inventory | `ops/bindings/cloudflare.inventory.yaml` |
| Service Registry | `docs/governance/SERVICE_REGISTRY.yaml` |
| Communications Stack | `ops/bindings/communications.stack.contract.yaml` |
| Communications Providers | `ops/bindings/communications.providers.contract.yaml` |

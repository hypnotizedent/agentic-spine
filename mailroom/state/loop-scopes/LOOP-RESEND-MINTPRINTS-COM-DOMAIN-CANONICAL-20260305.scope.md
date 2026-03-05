---
loop_id: LOOP-RESEND-MINTPRINTS-COM-DOMAIN-CANONICAL-20260305
created: 2026-03-05
status: active
owner: "@ronny"
scope: communications
priority: high
objective: "Canonicalize mintprints.com as the Resend sender domain — DNS verification, VM 213 runtime flip from .co to .com, D352 parity gate"
execution_mode: orchestrator_subagents
horizon: now
execution_readiness: runnable
---

# Loop Scope: LOOP-RESEND-MINTPRINTS-COM-DOMAIN-CANONICAL-20260305

## Objective

Canonicalize mintprints.com as the Resend sender domain — DNS verification, VM 213 runtime flip from .co to .com, D352 parity gate.

## Steps

### Step 1: Add DNS records to Cloudflare for Resend verification
- Add 3 DNS records for mintprints.com: DKIM (TXT), SPF MX, SPF TXT
- Use `cloudflare.dns.record.set` capability
- Records must match Resend verification requirements

### Step 2: Trigger and confirm Resend domain verification
- Trigger Resend domain verification for mintprints.com
- Confirm verification status transitions to verified
- Evidence: API response showing verified status

### Step 3: Flip VM 213 runtime sender from .co to .com
- Update runtime .env on VM 213 quote-page stack
- Change FROM sender from noreply@mintprints.co to noreply@mintprints.com
- Update communications.providers.contract.yaml default_sender_email
- Restart affected services

### Step 4: Add D352 gate — resend-domain-canonical-parity-lock
- Gate validates mintprints.com is canonical Resend sender
- Validates no .co sender references in runtime config
- Validates DNS records exist for Resend verification
- Report mode initially

### Step 5: File/close gaps, E2E test
- File gap for .co sender drift
- Close gaps after runtime flip
- E2E test: send test email from mintprints.com, confirm delivery

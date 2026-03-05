---
loop_id: LOOP-RONNY-PRODUCTS-INBOX-SHIELD-EXECUTION-20260305
created: 2026-03-05
status: active
owner: "@ronny"
scope: communications
priority: high
horizon: now
execution_readiness: runnable
execution_mode: orchestrator_subagents
objective: Implement Inbox Shield Step 1 — SMS/voice webhook application, classification engine, template responses, deployment configuration.
activation_trigger: manual
contracts:
  scaffold_contract_ref: ops/bindings/ronny.products.scaffold.contract.yaml#registered_products[id=inbox-shield]
  service_onboarding_ref: ops/bindings/service.onboarding.contract.yaml#services[id=inbox-shield]
---

# Loop Scope: LOOP-RONNY-PRODUCTS-INBOX-SHIELD-EXECUTION-20260305

## Objective

Implement Inbox Shield Step 1: a FastAPI webhook application that intercepts inbound SMS and voice calls via Twilio, classifies intent using rules + OpenAI API, auto-replies with templates or model-generated responses, and escalates urgent messages via ntfy push notifications.

## Architecture Decisions

- **Profile**: standalone-app (full application with own codebase)
- **Language**: Python 3.12 (FastAPI)
- **Data store**: SQLite (lightweight, single-instance)
- **External integrations**: Twilio (webhooks), OpenAI API (classification), ntfy (push notifications)
- **Deployment**: Docker on communications-stack VM 214
- **Exposure**: private (Tailscale + Cloudflare tunnel at shield.ronny.works)

## Lanes

### Lane A: Application Core (ronny-products)
- FastAPI application with webhook endpoints
- Classification engine (rules + OpenAI API)
- Template response system
- SQLite message store
- Docker compose + Dockerfile
- Health endpoint
- Twilio signature validation

### Lane B: Spine Governance (agentic-spine)
- Register capabilities in ops/capabilities.yaml + capability_map.yaml
- Register gate D378 inbox-shield-phase1-parity-lock
- Create gate script
- Update service onboarding contract
- Update product scaffold profile
- Wire domain metadata

## Guard Commands

- **Verify**: `./bin/ops cap run verify.run -- fast`

## Definition of Done

- [x] Approvals granted (governance, security, integration)
- [ ] FastAPI application built with SMS + voice webhook handlers
- [ ] Classification engine operational (rules + API fallback)
- [ ] Template response system working
- [ ] Docker deployment ready
- [ ] Spine capabilities registered
- [ ] Gate D377 passing
- [ ] Verify fast PASS

---
loop_id: LOOP-INBOX-SHIELD-PLANNING-20260302
created: 2026-03-02
closed_at: "2026-03-05"
status: closed
owner: "@ronny"
scope: communications
priority: high
horizon: now
execution_readiness: runnable
execution_mode: single_worker
objective: Plan and design the Inbox Shield system - an AI-powered communication buffer that intercepts inbound communications (calls, SMS, email) and uses fine-tuned models to auto-reply, only escalating to human when necessary.
close_summary: "Phase 0 complete. Architecture doc, capability contracts (14 caps, 4 contracts, 3 gates), carrier research, and model approach analysis landed. Proposal CP-20260302-032318 applied. app.contract.yaml stub created in ronny-products."
---

# Loop Scope: LOOP-INBOX-SHIELD-PLANNING-20260302

## Objective

Design and plan the Inbox Shield system: an AI-powered communication buffer that prevents direct contact by intercepting all inbound communications (calls, SMS, email), classifying intent, auto-responding via fine-tuned models, and escalating only when necessary.

## Problem Statement

The user needs to be unreachable by default while maintaining the ability to:
1. Use their phone normally for outbound communication
2. Have AI handle inbound requests automatically
3. Only be interrupted for genuinely urgent matters
4. Avoid the "message dump" problem when reconnecting after DND/airplane mode

Current phone-level solutions (DND, Airplane Mode) fail because:
- Messages queue server-side and flood in on reconnect
- No intelligent filtering or auto-response
- No escalation path for genuine emergencies

## Proposed Architecture

### Core Concept

```
[Inbound] --> [Interception Layer] --> [Classification] --> [Action]
                   |                        |                   |
            Twilio/Email              Fine-tuned         Auto-reply /
            webhooks                  model               Escalate
```

### Components

1. **Interception Layer**
   - Phone number forwarding: User's real number → Twilio virtual number
   - Email: Already flows through communications domain
   - SMS: Twilio webhook → spine processing

2. **Classification Engine**
   - Fine-tuned model for intent classification
   - Categories: urgent, business, personal, spam, info-request
   - Confidence thresholds for escalation

3. **Response Pipeline**
   - Template-based auto-replies for common patterns
   - Fine-tuned model for personalized responses
   - Escalation queue for human review

4. **Escalation Criteria**
   - Keyword triggers (emergency, urgent, etc.)
   - Sender whitelist (family, key contacts)
   - Classification confidence below threshold
   - Explicit "human needed" detection

## Phases

### Phase 0: Research & Design (Complete)
- [x] Twilio number provisioning research
- [x] Carrier forwarding options research
- [x] Fine-tuned model approach research (local vs API)
- [x] Architecture document creation
- [x] Contract definitions

### Phase 1: Foundation
- [ ] Twilio number acquisition
- [ ] Carrier call forwarding setup
- [ ] SMS webhook endpoint
- [ ] Basic classification capability
- [ ] Template response system

### Phase 2: Intelligence
- [ ] Fine-tuned model integration
- [ ] Intent classification pipeline
- [ ] Context-aware responses
- [ ] Conversation memory

### Phase 3: Polish
- [ ] Escalation tuning
- [ ] Response quality metrics
- [ ] Sender whitelist management
- [ ] Dashboard/reporting

## Success Criteria

1. **Inbound Isolation**: Zero direct calls/SMS reach user's phone
2. **Response Coverage**: >90% of inbound messages receive automated response
3. **Escalation Accuracy**: <5% of escalated messages are false positives
4. **Latency**: Auto-response within 60 seconds of receipt
5. **User Experience**: User only sees genuinely urgent communications

## Definition of Done

- [x] Architecture document approved
- [x] Contracts and bindings defined
- [x] Phase 0 research complete with findings documented
- [x] Ready for Phase 1 implementation planning

## Constraints

- Must not require user to change phone number
- Must work with existing carrier (T-Mobile)
- Must integrate with existing communications domain
- Must follow all spine governance patterns
- Must not bypass existing security/privacy controls

## Dependencies

- Twilio account (existing, needs number)
- Fine-tuned model infrastructure (to be determined)
- n8n for orchestration (existing)
- communications domain capabilities (existing)

## Risks

1. **Carrier forwarding limitations**: Some carriers may not support unconditional forwarding
2. **iMessage lock-in**: Apple's iMessage cannot be intercepted server-side
3. **Model quality**: Poor classification could miss urgent messages or spam user
4. **Latency**: Complex classification may delay responses unacceptably

## Artifacts Landed

- docs/governance/domains/communications/INBOX_SHIELD_ARCHITECTURE_V1.md — system architecture
- docs/governance/domains/communications/TWILIO_CARRIER_RESEARCH.md — carrier research findings
- docs/governance/domains/communications/MODEL_APPROACH_ANALYSIS.md — model approach comparison
- ops/bindings/inbox-shield.contracts.yaml — capability + contract definitions (planning status)
- Proposal: CP-20260302-032318__inbox-shield-planning-phase-0 (applied)

## Related Documents

- docs/governance/domains/communications/RUNBOOK.md
- ops/bindings/communications.providers.contract.yaml
- ops/agents/communications-agent.contract.md

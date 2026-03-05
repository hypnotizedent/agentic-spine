# Inbox Shield Architecture V1

> Status: draft
> Created: 2026-03-02
> Loop: LOOP-INBOX-SHIELD-PLANNING-20260302
> Proposal: CP-20260302-030646__inbox-shield-planning-phase0

## Executive Summary

Inbox Shield creates an AI-powered buffer between the user and inbound communications. All calls, SMS, and email are intercepted, classified by intent, and handled automatically. Only genuinely urgent matters escalate to human attention.

## System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        INBOUND CHANNELS                          │
├─────────────────┬─────────────────┬─────────────────────────────┤
│   Phone Calls   │      SMS        │          Email              │
│   (Forwarded)   │   (Forwarded)   │    (Direct to domain)       │
└────────┬────────┴────────┬────────┴──────────────┬──────────────┘
         │                 │                       │
         ▼                 ▼                       ▼
┌─────────────────────────────────────────────────────────────────┐
│                    INTERCEPTION LAYER                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │ Twilio Voice│  │Twilio SMS   │  │ Email Webhook/IMAP      │  │
│  │   Webhook   │  │  Webhook    │  │   (existing comm domain)│  │
│  └──────┬──────┘  └──────┬──────┘  └───────────┬─────────────┘  │
└─────────┼────────────────┼─────────────────────┼────────────────┘
          │                │                     │
          ▼                ▼                     ▼
┌─────────────────────────────────────────────────────────────────┐
│                   CLASSIFICATION ENGINE                          │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                    Fine-Tuned Model                         ││
│  │  Intent: urgent | business | personal | spam | info-request ││
│  │  Confidence: 0.0 - 1.0                                      ││
│  │  Action: auto-reply | escalate | queue                      ││
│  └─────────────────────────────────────────────────────────────┘│
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                    Rule Engine                              ││
│  │  - Whitelist check (family, key contacts)                   ││
│  │  - Keyword triggers (emergency, urgent)                     ││
│  │  - Time-based rules (business hours)                        ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     ACTION ROUTER                                │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────────┐    │
│  │  AUTO-REPLY   │  │   ESCALATE    │  │      QUEUE        │    │
│  │  (template +  │  │  (push notify │  │  (batch review    │    │
│  │   model gen)  │  │   + alert)    │  │   later)          │    │
│  └───────┬───────┘  └───────┬───────┘  └─────────┬─────────┘    │
└──────────┼──────────────────┼────────────────────┼──────────────┘
           │                  │                    │
           ▼                  ▼                    ▼
    ┌─────────────┐    ┌─────────────┐      ┌─────────────┐
    │  Sender gets│    │  User gets  │      │  Stored for │
    │  response   │    │  interrupt  │      │  later      │
    └─────────────┘    └─────────────┘      └─────────────┘
```

## Component Specifications

### 1. Interception Layer

#### 1.1 Phone Call Interception

**Flow:**
1. User's mobile number forwards all calls to Twilio number (carrier-level)
2. Twilio webhook receives call event
3. TwiML responds with voicemail prompt
4. Transcription sent to classification engine
5. Response generated and sent via SMS to caller

**Configuration:**
```yaml
twilio_voice:
  forwarding_from: "+1XXXXXXXXXX"  # User's real number
  twilio_number: "+1YYYYYYYYYY"    # Twilio virtual number
  webhook_url: "https://shield.ronny.works/voice/inbound"
  voicemail_prompt: "The person you're calling cannot be reached directly. Please leave a message and they will respond shortly."
  transcription_callback: "https://shield.ronny.works/voice/transcription"
```

#### 1.2 SMS Interception

**Flow:**
1. SMS to user's number → forwarded to Twilio number
2. Twilio webhook receives SMS
3. Classification engine processes
4. Auto-reply via Twilio or escalation

**Configuration:**
```yaml
twilio_sms:
  webhook_url: "https://shield.ronny.works/sms/inbound"
  auto_reply_timeout_seconds: 30
  max_message_length: 1600
```

#### 1.3 Email Interception

**Flow:**
1. Inbound email to user's address
2. Existing communications domain handles
3. New inbox-shield.email.triage capability classifies
4. Auto-reply via communications.send.execute

### 2. Classification Engine

#### 2.1 Fine-Tuned Model

**Options:**

| Approach | Pros | Cons |
|----------|------|------|
| Local LLM (Ollama) | Privacy, no API costs | Requires GPU, higher latency |
| OpenAI Fine-tune | Quality, speed | API costs, data leaves premise |
| Claude Fine-tune | Quality, context | API costs |
| Custom classifier (BERT) | Fast, cheap | Lower quality for nuanced intent |

**Recommendation:** Start with rule engine + OpenAI/Claude API for Phase 1, evaluate local deployment in Phase 2.

#### 2.2 Classification Schema

```yaml
classification:
  intent:
    - urgent          # Requires immediate human attention
    - business        # Business-related, can wait
    - personal        # Personal contact, moderate priority
    - spam            # Unsolicited, auto-discard
    - info_request    # Simple question, auto-reply
    - follow_up       # Continuing conversation
  
  confidence_threshold:
    auto_reply: 0.85  # Confidence above = auto-reply
    escalate: 0.60    # Confidence below = escalate
    queue: 0.70       # Between = queue for review
  
  sender_context:
    - whitelisted     # Known contacts, prefer escalation
    - unknown         # Standard processing
    - blocked         # Auto-discard
```

### 3. Response Pipeline

#### 3.1 Template Responses

```yaml
templates:
  info_request:
    sms: "Thanks for reaching out! I'll get back to you within 24 hours. For urgent matters, please call [emergency contact]."
    email: |
      Hi {{sender_name}},
      
      Thanks for your message. I'm currently in deep work mode and will respond within 24 hours.
      
      For urgent matters, please reach out through [emergency channel].
      
      Best,
      [AI Assistant]
  
  business:
    sms: "Received your message. Response expected within 4 business hours."
    email: |
      Hi {{sender_name}},
      
      Your message has been received and logged. Expect a response within 4 business hours.
      
      Best regards,
      [AI Assistant]
```

#### 3.2 Model-Generated Responses

For nuanced messages requiring personalized response:

```yaml
model_response:
  provider: openai  # or claude
  model: gpt-4-turbo
  system_prompt: |
    You are an AI assistant managing communications for [User].
    Respond professionally and helpfully.
    Never promise specific timelines unless confident.
    For complex requests, acknowledge and set expectations.
  context_window: 10  # Previous messages for conversation continuity
```

### 4. Escalation System

#### 4.1 Escalation Triggers

```yaml
escalation_rules:
  always_escalate:
    - sender in whitelist_family
    - contains_keyword: ["emergency", "urgent", "asap", "immediately"]
    - classification.intent == urgent
    - classification.confidence < 0.60
  
  never_escalate:
    - sender in blocked_list
    - classification.intent == spam
  
  time_based:
    business_hours:
      escalate_after_minutes: 30
    off_hours:
      escalate_after_minutes: 120
```

#### 4.2 Escalation Channels

```yaml
escalation_channels:
  push_notification:
    provider: ntfy  # or pushover
    topic: inbox-shield-urgent
    priority: high
  
  sms_backup:
    enabled: true
    to: "+1XXXXXXXXXX"  # Emergency contact
  
  dashboard:
    url: "https://shield.ronny.works/dashboard"
    refresh_seconds: 30
```

## Integration Points

### Existing Spine Systems

| System | Integration | New Capability |
|--------|-------------|----------------|
| communications.* | Outbound replies | inbox-shield.reply.send |
| alerts.* | Escalation pipeline | inbox-shield.alert.trigger |
| n8n | Webhook handling | inbox-shield.webhook.* |
| receipts | Audit trail | Standard receipt generation |

### External Systems

| System | Purpose | Integration |
|--------|---------|-------------|
| Twilio | Voice/SMS | Webhook endpoints |
| OpenAI/Claude | Model inference | API calls |
| ntfy | Push notifications | REST API |

## Phase Roadmap

### Phase 0: Research & Design (Current)
- Architecture document
- Twilio/carrier research
- Model approach analysis
- Contract definitions

### Phase 1: Foundation
**Goal:** Basic SMS interception and auto-reply

**Deliverables:**
- Twilio number acquired and configured
- Carrier forwarding enabled
- SMS webhook endpoint (inbox-shield.sms.webhook)
- Basic classification (rule-based)
- Template response system

**Milestone:** User can send test SMS and receive automated response

### Phase 2: Voice + Intelligence
**Goal:** Call interception + model-based classification

**Deliverables:**
- Voice webhook endpoint (inbox-shield.voice.webhook)
- Voicemail transcription
- Fine-tuned model integration
- Conversation memory
- Whitelist management

**Milestone:** Calls are intercepted, transcribed, and intelligently routed

### Phase 3: Email + Polish
**Goal:** Full coverage + quality metrics

**Deliverables:**
- Email triage integration (inbox-shield.email.triage)
- Response quality scoring
- Dashboard for monitoring
- Tuning interface for thresholds
- Historical analytics

**Milestone:** All communication channels protected, metrics dashboard live

## Security Considerations

1. **Webhook Authentication**: All endpoints require Twilio signature validation
2. **Data Privacy**: Message content stored only for context window, then purged
3. **Access Control**: Dashboard requires Tailscale VPN + auth
4. **Rate Limiting**: Prevent abuse via per-sender rate limits
5. **Audit Trail**: All actions logged via spine receipts

## Cost Estimation

| Component | Monthly Cost |
|-----------|--------------|
| Twilio Number | $1-2 |
| SMS (1000/mo) | $5-10 |
| Voice minutes (100/mo) | $2-5 |
| Transcription (100/mo) | $5-10 |
| Model API (1000 calls) | $10-30 |
| **Total Estimate** | **$25-60/month** |

## Success Metrics

| Metric | Target |
|--------|--------|
| Inbound isolation rate | 100% (no direct contact) |
| Auto-response rate | >90% of messages |
| Escalation accuracy | >95% (few false positives) |
| Response latency | <60 seconds |
| User satisfaction | "I feel unreachable but not isolated" |

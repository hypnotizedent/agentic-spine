# Twilio & Carrier Forwarding Research

> Status: research-findings
> Created: 2026-03-02
> Loop: LOOP-INBOX-SHIELD-PLANNING-20260302

## Executive Summary

**Verdict: FEASIBLE with T-Mobile Conditional Call Forwarding**

T-Mobile supports conditional call forwarding (forward on no answer, busy, or unreachable) but NOT unconditional forwarding (forward all calls). This is sufficient for Inbox Shield use case - calls forward to Twilio when user doesn't answer.

## Carrier Research: T-Mobile

### Current Carrier

User is on T-Mobile (confirmed via existing communications contracts).

### Forwarding Options

| Type | Code | Supported | Notes |
|------|------|-----------|-------|
| Unconditional | `*72[number]#` | NO | T-Mobile requires "Digits" add-on |
| Conditional (No Answer) | `*61[number]#` | YES | Forward if not answered |
| Conditional (Busy) | `*67[number]#` | YES | Forward if line busy |
| Conditional (Unreachable) | `*62[number]#` | YES | Forward if phone off/no signal |
| Cancel All | `*004#` | YES | Disable all forwarding |

### Recommended Setup

```
Set forwarding to Twilio number for all conditional cases:
*61[+1TWILIO_NUMBER]*11*[seconds]#
*67[+1TWILIO_NUMBER]#
*62[+1TWILIO_NUMBER]#

Where seconds = time before forward (default 20, max 30)
```

### SMS Forwarding

**Challenge:** SMS forwarding is NOT natively supported by carriers.

**Options:**
1. **Port number to Twilio** - Cleanest but requires number change
2. **Get new Twilio number, inform contacts** - Requires contact migration
3. **Use call forwarding only, SMS stays on phone** - Partial solution
4. **T-Mobile DIGITS** - Could mirror SMS but proprietary

**Recommendation:** 
- Phase 1: Start with call forwarding only (SMS can be handled via DND + manual)
- Phase 2: Migrate primary communication to Twilio number
- Phase 3: Consider number port if user wants full SMS interception

## Twilio Research

### Number Acquisition

**Steps:**
1. Log into Twilio Console
2. Navigate to Phone Numbers → Buy a Number
3. Search for number with:
   - Voice enabled
   - SMS enabled
   - MMS enabled (optional)
4. Purchase (~$1/month)

**Existing Account:**
- User already has Twilio account (per secrets.runway.contract.yaml)
- Account SID and Auth Token in Infisical
- Existing number: +15619335513 (for outbound SMS)

**Decision:** Acquire NEW number for inbound interception vs use existing.

| Option | Pros | Cons |
|--------|------|------|
| Use existing | No new cost, already wired | Confuses inbound/outbound |
| New number | Clean separation | +$1/month |

**Recommendation:** Acquire new number specifically for Inbox Shield.

### Webhook Configuration

**Voice Webhook:**
```
POST https://shield.ronny.works/voice/inbound
Headers: X-Twilio-Signature (validate)
Body: form-urlencoded (From, To, CallSid, CallStatus)
```

**SMS Webhook:**
```
POST https://shield.ronny.works/sms/inbound
Headers: X-Twilio-Signature (validate)
Body: form-urlencoded (From, To, Body, MessageSid)
```

### TwiML for Voicemail

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Response>
    <Say voice="alice">The person you're calling cannot be reached directly. Please leave a brief message after the tone.</Say>
    <Record 
        maxLength="60" 
        transcribe="true"
        transcribeCallback="https://shield.ronny.works/voice/transcription"
        action="https://shield.ronny.works/voice/complete"
    />
</Response>
```

### Pricing (Monthly Estimates)

| Component | Rate | Est. Volume | Cost |
|-----------|------|-------------|------|
| Phone Number | $1/month | 1 | $1.00 |
| Voice (inbound) | $0.0085/min | 100 min | $0.85 |
| SMS (inbound) | $0.0075/msg | 500 msg | $3.75 |
| SMS (outbound) | $0.0075/msg | 500 msg | $3.75 |
| Transcription | $0.05/min | 50 min | $2.50 |
| **Total** | | | **~$12/month** |

## Implementation Steps

### Phase 1: Foundation

1. **Acquire Twilio Number**
   - Search for local number
   - Enable Voice + SMS
   - Configure webhook URLs

2. **Configure Carrier Forwarding**
   ```bash
   # From phone, dial:
   *61[+1TWILIO_NUMBER]*11*20#   # Forward after 20 seconds no answer
   *67[+1TWILIO_NUMBER]#          # Forward when busy
   *62[+1TWILIO_NUMBER]#          # Forward when unreachable
   ```

3. **Deploy Webhook Endpoints**
   - Create `shield.ronny.works` DNS (Cloudflare tunnel)
   - Deploy webhook handlers
   - Implement Twilio signature validation

4. **Test Flow**
   - Call user's number → should forward to Twilio after 20s
   - Verify voicemail prompt plays
   - Verify transcription received
   - Test auto-response SMS

### Verification Commands

```bash
# Check forwarding status (T-Mobile)
*#61#  - Check no-answer forwarding
*#67#  - Check busy forwarding  
*#62#  - Check unreachable forwarding

# Disable all forwarding
*004#
```

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| T-Mobile changes forwarding codes | Medium | Document alternatives, support DIGITS |
| SMS not intercepted | High | Phase 1: manual handling; Phase 2: number migration |
| Twilio webhook downtime | High | Retry logic, fallback to voicemail-only mode |
| International callers | Low | Twilio supports international, just costs more |

## Conclusion

**Call Interception:** Fully viable via T-Mobile conditional call forwarding.

**SMS Interception:** Requires either:
1. Accepting SMS still reaches phone (Phase 1)
2. Migrating contacts to new Twilio number (Phase 2+)
3. Porting existing number to Twilio (Phase 3+)

**Recommendation:** Start Phase 1 with call-only interception, plan SMS migration for Phase 2.

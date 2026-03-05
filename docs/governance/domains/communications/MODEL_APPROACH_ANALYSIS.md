# Fine-Tuned Model Approach Analysis

> Status: research-findings
> Created: 2026-03-02
> Loop: LOOP-INBOX-SHIELD-PLANNING-20260302

## Executive Summary

**Recommendation: Hybrid Approach**
- Phase 1: Rule-based + OpenAI API (fast, reliable, low setup)
- Phase 2: Fine-tuned classifier on local infrastructure (cost, privacy)
- Phase 3: Evaluate dedicated response model

## Model Requirements

### Classification Task

| Input | Output |
|-------|--------|
| Message text, sender info, conversation history | Intent, confidence, suggested action |

**Classes:**
- `urgent` - Requires immediate attention
- `business` - Work-related, can queue
- `personal` - Friends/family, moderate priority
- `spam` - Unsolicited, auto-discard
- `info_request` - Simple question, auto-reply template
- `follow_up` - Continuing conversation

**Latency Requirement:** <5 seconds (user experience)

### Response Generation Task

| Input | Output |
|-------|--------|
| Classified message, context, user preferences | Personalized response text |

**Quality Requirements:**
- Professional tone
- Appropriate for relationship level
- Consistent with user's communication style
- No false promises

**Latency Requirement:** <30 seconds (acceptable for async)

## Approach Comparison

### Option 1: Rule-Based Only (Baseline)

```yaml
rules:
  - if: "sender in whitelist_family"
    then: escalate
  - if: "contains any: [emergency, urgent, asap]"
    then: escalate
  - if: "sender in blocked"
    then: discard
  - if: "length < 20 chars"
    then: info_request
  - else:
    then: queue
```

**Pros:** Zero cost, instant, predictable
**Cons:** Low accuracy, no nuance
**Verdict:** Use as fallback/training baseline, not primary

### Option 2: OpenAI API (GPT-4 Turbo)

**Setup:**
```python
import openai

response = openai.chat.completions.create(
    model="gpt-4-turbo-preview",
    messages=[
        {"role": "system", "content": CLASSIFICATION_PROMPT},
        {"role": "user", "content": message}
    ],
    response_format={"type": "json_object"}
)
```

**Costs:**
- Input: $10/1M tokens
- Output: $30/1M tokens
- Est. 1000 messages/month = ~$5-15/month

**Pros:** High quality, fast, easy setup, conversation context
**Cons:** API dependency, data leaves premise, recurring cost
**Verdict:** Best for Phase 1 MVP

### Option 3: Claude API (Sonnet)

**Setup:**
```python
import anthropic

client = anthropic.Anthropic()
message = client.messages.create(
    model="claude-sonnet-4-20250514",
    max_tokens=1024,
    system=CLASSIFICATION_PROMPT,
    messages=[{"role": "user", "content": message}]
)
```

**Costs:**
- Input: $3/1M tokens
- Output: $15/1M tokens
- Est. 1000 messages/month = ~$2-8/month

**Pros:** Cheaper than GPT-4, large context, good quality
**Cons:** API dependency, less fine-tuning options
**Verdict:** Strong alternative to OpenAI, use for comparison

### Option 4: Local LLM (Ollama + Llama 3)

**Setup:**
```bash
# Install Ollama
curl -fsSL https://ollama.com/install.sh | sh

# Pull model
ollama pull llama3.1:8b

# API call
curl http://localhost:11434/api/generate -d '{
  "model": "llama3.1:8b",
  "prompt": "Classify this message...",
  "stream": false
}'
```

**Hardware Requirements:**
- 8B model: 8GB RAM, 6GB VRAM
- Running on Mac: Metal acceleration available

**Pros:** Zero API cost, privacy, offline capable
**Cons:** Requires GPU, setup complexity, lower quality
**Verdict:** Good for Phase 2 cost optimization, not MVP

### Option 5: Fine-Tuned Classifier (BERT/RoBERTa)

**Setup:**
1. Collect training data (1000+ labeled messages)
2. Fine-tune via HuggingFace
3. Deploy via FastAPI endpoint

**Pros:** Fast inference (ms), cheap at scale
**Cons:** Training effort, only classification (not generation)
**Verdict:** Consider for Phase 2 classification optimization

### Option 6: Hybrid Pipeline

```
Message → Rule Check → Local LLM → API Fallback → Action
              ↓            ↓             ↓
         Escalate?    Classify      Generate Response
         Block?       (fast)        (quality)
```

**Pros:** Best of all worlds, cost optimized
**Cons:** Complexity
**Verdict:** Recommended for Phase 2+

## Fine-Tuning Data Requirements

### For Classification

| Approach | Min Samples | Recommended |
|----------|-------------|-------------|
| Zero-shot API | 0 | 0 (uses prompts) |
| Few-shot API | 10 | 50 |
| Fine-tuned classifier | 500 | 2000+ |
| Fine-tuned LLM | 1000 | 5000+ |

### Data Sources

1. **Synthetic generation** - Use GPT-4 to generate training examples
2. **Historical messages** - Export from existing communications
3. **Manual labeling** - User labels incoming messages for first month
4. **Augmentation** - Paraphrase, translate-back

### User Communication Style

For personalized responses, need:
- Sample of user's actual responses (50-100)
- Formality level preferences
- Common phrases/signatures
- Response time expectations by sender type

## Recommendation

### Phase 1: Foundation (Now)

**Classification:** OpenAI GPT-4 Turbo
- Reliable, fast, good quality
- Use structured JSON output
- Include conversation context

**Response Generation:** Template-based primarily, API for complex cases
- Start with 5-10 templates
- Use API for non-template situations

```yaml
classification:
  provider: openai
  model: gpt-4-turbo
  system_prompt: |
    You are a message classifier. Analyze the message and respond with JSON:
    {"intent": "urgent|business|personal|spam|info_request|follow_up", 
     "confidence": 0.0-1.0,
     "reasoning": "brief explanation",
     "suggested_action": "escalate|auto_reply|queue"}
  
response_generation:
  template_first: true
  fallback_provider: openai
  fallback_model: gpt-4-turbo
```

### Phase 2: Optimization (After 1000+ messages)

**Classification:** Evaluate fine-tuned BERT classifier
- Collect labeled data from Phase 1
- Train lightweight classifier
- Use for primary classification, API for edge cases

**Response Generation:** Evaluate local LLM (Ollama + Llama 3)
- Fine-tune on user's response style
- Deploy locally for privacy + cost
- API fallback for quality

### Phase 3: Polish

**Full Pipeline:**
```
Rule Engine (instant) → Local Classifier (50ms) → Local Generator (2s)
                            ↓ fails                    ↓ low confidence
                      API Classifier (500ms) → API Generator (3s)
```

## Cost Projections

### Phase 1 (API-heavy)

| Component | Volume | Cost |
|-----------|--------|------|
| Classification API | 1000/mo | $5-10 |
| Response Generation | 500/mo | $5-10 |
| **Total** | | **$10-20/mo** |

### Phase 2 (Hybrid)

| Component | Volume | Cost |
|-----------|--------|------|
| Local Classification | 90% | $0 |
| API Classification | 10% | $1-2 |
| Local Generation | 50% | $0 |
| API Generation | 50% | $5 |
| **Total** | | **$6-7/mo** |

### Phase 3 (Local-optimized)

| Component | Volume | Cost |
|-----------|--------|------|
| Local Classification | 95% | $0 |
| API Classification | 5% | $0.50 |
| Local Generation | 80% | $0 |
| API Generation | 20% | $2 |
| **Total** | | **$2.50/mo** |

## Implementation Notes

### Prompt Engineering

**Classification Prompt:**
```
Analyze this message and classify its intent.

Sender: {{sender_name}} ({{sender_relationship}})
Previous context: {{last_3_messages}}
Message: {{message_body}}

Consider:
1. Urgency indicators (time-sensitive words)
2. Relationship context (family = higher priority)
3. Content type (question, request, update, spam)
4. Emotional tone

Respond with JSON only:
{
  "intent": "urgent|business|personal|spam|info_request|follow_up",
  "confidence": 0.0-1.0,
  "reasoning": "one sentence explanation",
  "suggested_action": "escalate|auto_reply|queue",
  "response_tone": "formal|casual|warm"
}
```

**Response Generation Prompt:**
```
Generate a response to this message.

User's communication style:
- Formality: {{formality_level}}
- Common phrases: {{user_phrases}}
- Response time expectation: {{response_time}}

Original message: {{original_message}}
Classification: {{classification}}

Guidelines:
1. Be helpful but non-committal on timelines
2. Match the sender's relationship level
3. For complex requests, acknowledge and set expectations
4. Keep responses concise (under 160 chars for SMS)

Response:
```

## Conclusion

**Start with:** OpenAI API for both classification and generation (Phase 1)
**Optimize to:** Local classification + hybrid generation (Phase 2)
**Goal:** 90%+ local, 10% API fallback, <$5/month operational cost

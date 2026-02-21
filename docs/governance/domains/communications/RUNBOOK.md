---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-21
scope: communications-live-pilot-runbook
domain: communications
---

# Communications Live Pilot Runbook

## Purpose

Define the canonical live-pilot operating flow for communications surfaces in spine.

## Contract Authority

- `/Users/ronnyworks/code/agentic-spine/ops/bindings/communications.stack.contract.yaml`
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/communications.providers.contract.yaml`
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/communications.policy.contract.yaml`
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/communications.templates.catalog.yaml`
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/communications.delivery.contract.yaml`

Live pilot requires:

- `pilot.send_test.mode: live-pilot`
- `pilot.execution_backend: microsoft-graph`
- Active mailbox rows in `pilot.mailboxes[]`
- Transactional provider and policy contracts present and parseable

## Surfaces

- `communications.stack.status`
  - Validates contract + infra target parity.
  - In live mode, runs Graph probe and fails on non-JSON/no-response payload.
- `communications.mailboxes.list`
  - Shows stage/mode/backend and pilot mailbox roster.
- `communications.mail.search`
  - Simulation mode: searches mailbox catalog in contract.
  - Live mode: executes Graph mailbox query via governed Graph helper.
- `communications.mail.send.test`
  - Manual approval required.
  - Simulation mode: writes simulated artifact under runtime outbox.
  - Live mode: sends real pilot test message via Graph and writes receipt artifact under runtime outbox.
- `communications.provider.status`
  - Shows Graph/Resend/Twilio route status and env-readiness for live execution.
- `communications.policy.status`
  - Shows canonical consent/compliance policy (opt-in, quiet-hours, STOP footer rules).
- `communications.templates.list`
  - Lists template catalog by channel/message type.
- `communications.send.preview`
  - Resolves message_type + channel to canonical provider and renders message under policy gates.
- `communications.send.execute`
  - Manual approval required.
  - Simulation-first transactional execution with optional live provider dispatch when contract mode is `live`.
- `communications.delivery.log`
  - Read-only query of normalized communications delivery artifacts.

## Required Preconditions

Communications live surfaces rely on Graph and therefore require:

- `secrets.binding`
- `secrets.auth.status`

## Canonical Commands

```bash
cd /Users/ronnyworks/code/agentic-spine
./bin/ops cap run communications.stack.status
./bin/ops cap run communications.mailboxes.list
./bin/ops cap run communications.mail.search --query "*" --top 5
echo "yes" | ./bin/ops cap run communications.mail.send.test --to ronny@mintprints.com --subject "pilot test" --body "hello" --execute
./bin/ops cap run communications.provider.status
./bin/ops cap run communications.policy.status
./bin/ops cap run communications.templates.list --channel sms
./bin/ops cap run communications.send.preview --channel sms --message-type payment_needed --to +15551234567 --consent-state opted-in --vars-json '{"customer_name":"Test","order_number":"30020","balance_amount":"150.00","payment_link":"https://example.com/pay"}'
echo "yes" | ./bin/ops cap run communications.send.execute --channel sms --message-type payment_needed --to +15551234567 --consent-state opted-in --vars-json '{"customer_name":"Test","order_number":"30020","balance_amount":"150.00","payment_link":"https://example.com/pay"}' --execute
./bin/ops cap run communications.delivery.log --limit 10
```

## Evidence Pattern

- Send-test artifact path:
  - `$SPINE_OUTBOX/communications/communications-send-test-last.yaml`
- Transactional execution artifact path:
  - `$SPINE_OUTBOX/communications/communications-transaction-last.yaml`
- Transactional append-only delivery log:
  - `$SPINE_OUTBOX/communications/communications-delivery-log.jsonl`
- Delivery confirmation pattern:
  - Query `graph.mail.search` for unique send-test subject token.

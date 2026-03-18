---
status: draft
owner: "@ronny"
last_verified: 2026-03-13
scope: mint-agents-2-0-execution-model
---

# Mint Agents 2.0 Execution Model

## Why This Exists

Mint has enough individual hardening work in place that the next failure mode is
no longer "missing tools."

The failure mode is:

- Morpheus acts like a smart email runner instead of a record-first lane worker.
- Artie is still not the default truth owner for proof correctness and revision precision.
- Fin still depends on bridge records being made explicit instead of reading one boring finance truth path.
- Flying Dutchman still absorbs too much repair work because the downstream lanes are not strict enough.

Mint Agents 2.0 defines the upgrade from:

`chatbot + prompts + tools`

to:

`record-driven lane workers + bounded handoffs + thin rendering`

## Core Shift

Agents must stop improvising from the latest message and start from governed
records.

For every Mint lane, the first question becomes:

`what governed record already exists and what state is it in?`

Not:

`what should I do next?`

## Canonical Working Model

### 1. Record First

The business is the data.

Every recurring Mint workflow must trace back to records:

1. `customer_record`
2. `seed_record`
3. `printavo_bridge_record`
4. `artifact_record`
5. `quote_packet`
6. `order_record`
7. `finance_evidence_record`
8. `communication_record`

If a lane cannot answer from records, it is not boring yet.

### 2. Hard Lane Ownership

#### Morpheus

Owns:

- inbox triage
- customer coordination
- quote momentum
- draft rendering from governed state
- next-step clarity

Does not own:

- visual proof correctness
- deep artwork revision reasoning
- finance reconciliation
- orchestration/system repair

Default first move:

1. find oldest eligible customer work item
2. read current message
3. load customer/seed/Printavo/artifact context
4. classify reused vs changed vs missing
5. return operator briefing or render draft from existing state

#### Artie

Owns:

- artwork truth
- proof correctness
- revision pass/fail
- artwork family / sizing reuse / color continuity
- mockup vs print-ready vs production asset truth

Does not own:

- customer coordination prose
- quote/payment/status messaging

Default first move:

1. load artifact and proof records
2. compare against requested changes
3. return `passed`, `failed`, or `ambiguous`
4. create exact revision instruction when failed

#### Fin

Owns:

- payment visibility
- vendor receipt capture
- COGS evidence
- reconciliation truth
- finance-facing retained-doc state

Does not own:

- artwork decisions
- customer thread handling

Default first move:

1. load order / Printavo bridge / finance evidence state
2. classify payment or vendor event
3. attach cost or payment truth back to governed records
4. expose one fast finance snapshot

#### Flying Dutchman

Owns:

- orchestration
- queueing and dispatch
- runtime verification
- structural hardening
- cross-lane audits

Does not own:

- long-term inline customer drafting
- visual art review
- acting as the worker for every downstream task

Default first move:

1. capture friction
2. classify loop/gap/task
3. dispatch bounded worker
4. verify and close

### 3. State Machines Before Drafts

Every lane needs explicit states.

#### Customer / order-progress states

- `new_inbound`
- `needs_clarification`
- `quote_live`
- `approved`
- `paid`
- `production_ready`
- `closed`

#### Artwork states

- `original`
- `mockup_reference`
- `proof_pending_review`
- `revision_failed`
- `revision_passed`
- `print_ready`
- `production_asset`
- `superseded`

#### Finance states

- `payment_expected`
- `payment_captured`
- `vendor_cost_seen`
- `cogs_linked`
- `reconciled`

#### Quote packet states

- `drafting`
- `needs_input`
- `estimate_ready`
- `ready_for_review`
- `approved_to_send`
- `sent`
- `paid`
- `closed`

Agents should move records through states.

Drafts should be a render of those states, not the place where reasoning begins.

### 4. Thin Rendering Layer

Customer emails should be the last 10% of the workflow.

The reasoning must already be done by the time a draft is rendered.

Canonical outbound structure:

1. human wrapper
2. machine payload
3. machine footer

This keeps:

- customer-facing copy readable
- machine truth explicit
- provenance and evidence intact

### 5. Bounded Autonomy

Autonomy does not mean "guess harder."

It means:

- stay in your lane
- read records first
- fail closed when the next step belongs to another lane
- ask only when the boundary truly requires operator judgment

## Existing 2.0 Building Blocks Already Landed

These are already in the repo/runtime and are part of the 2.0 path:

- `mint.customer.record.snapshot`
- `mint.customer.seed.ensure`
- `mint.customer.inbox.work_items`
- `mint.customer.quote.brief`
- `mint.customer.reorder.resolve`
- `mint.customer.reply.draft`
- `mint.customer.contact.graph.set`
- `mint.customer.quote.context.set`
- `mint.customer.artwork.revision.prepare`
- `mint.artie.revision.review`
- `mint.artifact.record.snapshot`
- `mint.artwork.intelligence.snapshot`
- Printavo bridge snapshot/update surfaces
- vendor receipt / COGS evidence surfaces for Fin

The missing work is not the existence of tools.

The missing work is wiring them into one predictable operating model.

## Canonical First Moves

### Morpheus

`current email -> record load -> reuse/change/missing -> draft on explicit state`

### Artie

`artifact/proof load -> requested change compare -> pass/fail -> exact revision instruction`

### Fin

`payment/vendor event -> bridge/order lookup -> finance evidence attach -> snapshot`

### Flying Dutchman

`friction capture -> task/loop classify -> dispatch -> verify`

## Boring Operator Expectations

If the system is working, Ronny should be able to expect:

- Morpheus does not ask for details already present in prior records
- Artie does not narrate around a failed proof; it names the exact miss
- Fin can answer whether payment/vendor cost truth exists without opening Printavo
- Flying Dutchman queues and dispatches instead of becoming the only real worker

## Program-Level Gaps That 2.0 Still Has To Close

1. Morpheus must default to full customer context build before clarifying or drafting.
2. Artie must own proof correctness and revision translation strongly enough that Morpheus stops doing art-review narration.
3. Fin must get a faster default bridge from manual Ronny events into finance-readable state.
4. Outbound drafts must update in place from one canonical work object.
5. Startup/default workflows must launch into lane behavior without prompt rituals.

## Definition Of Success

Mint Agents 2.0 succeeds when:

- the same request produces the same lane behavior on different terminals
- customer context is built from records first
- drafts reflect governed state instead of improvisation
- artwork and finance truth stop living in operator memory
- Dutchman is no longer the universal repairman for missing lane boundaries

## Relationship To Existing Authorities

- Record-first business baseline:
  [MINT_RECORD_FIRST_BUSINESS_BASELINE_20260312.md](/Users/ronnyworks/code/agentic-spine/docs/reference/mint/MINT_RECORD_FIRST_BUSINESS_BASELINE_20260312.md)
- Order truth:
  [mint.order.truth.authority.yaml](/Users/ronnyworks/code/agentic-spine/ops/bindings/mint.order.truth.authority.yaml)
- Quote packet work object:
  [mint.quote.packet.authority.yaml](/Users/ronnyworks/code/agentic-spine/ops/bindings/mint.quote.packet.authority.yaml)
- Fleet identity:
  [mint.fleet.identity.contract.yaml](/Users/ronnyworks/code/agentic-spine/ops/bindings/mint.fleet.identity.contract.yaml)

This document does not replace those authorities.
It defines how they must be used together as one operating model.

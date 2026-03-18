---
status: draft
owner: "@ronny"
last_verified: 2026-03-12
scope: mint-record-first-business-baseline
---

# Mint Record-First Business Baseline

## Why This Exists

Mint has been hardening modules, agents, and receipts without a single boring answer to:

`What is the business record an agent should check first?`

This document establishes the current baseline and the target direction.

The business is the data.

Every module, agent, email receipt, artwork file, pricing run, shipping event, and finance event must trace back to governed Mint records.

## Verified Current Baseline

TowMaxx / George is the proving example.

Verified on 2026-03-12:

- Fresh-slate customer identity exists in `mint_modules.public.customers`
- Fresh-slate seed truth for `george@towmaxxtowing.com` does not exist yet
- Fresh-slate order truth for George does not exist yet
- Legacy-hold order history exists in `mint_legacy.legacy_mint_os.orders`
- Legacy-hold line-item history exists in `mint_legacy.legacy_mint_os.line_items`

This means the current state is:

- customer identity is partially fresh-slate
- current/live intake truth is seed-first
- repeat-order memory is still mostly trapped in legacy-hold order rows

That split is the main reason agents cannot yet make reorders boring.

## Canonical Record Model

The first agent question must become:

`check the records`

The records that matter are:

1. `customer_record`
2. `seed_record`
3. `order_record`
4. `order_line_record`
5. `asset_record`
6. `communication_record`
7. `pricing_receipt_record`
8. `shipping_record`
9. `finance_record`

## What Each Record Means

### customer_record

The customer identity anchor.

Minimum responsibilities:

- one canonical customer id
- resolved email/name/company identity
- legacy aliases and imported ids
- relationship to orders, seeds, communications, and assets

### seed_record

The first-touch intake record.

Every inbound business event must become a seed:

- inbound email
- quote form
- forwarded message
- manual operator entry

If an agent receives new customer intent, it does not guess. It checks whether a seed already exists. If not, it creates one.

### order_record

The canonical business work item.

Every operational lane must attach here:

- artwork
- pricing
- shipping
- finance
- communications
- approvals

### order_line_record

The canonical line-level fulfillment truth.

This is where:

- garment style
- color
- quantity
- size breakdown
- decoration method
- supplier resolution
- pricing evidence

must live in a boring way.

### asset_record

The canonical file/artwork/production-file reference.

MinIO remains the object store, but agents should not think in terms of folders first.

Agents should think:

- `which asset_record applies?`
- `which order_record or seed_record references it?`

### communication_record

Every customer or vendor email must map to a governed record reference:

- inbound email
- draft reply
- sent reply
- resend/preview/send receipt

### pricing_receipt_record

Every price result must preserve:

- what line/order was priced
- which inputs were used
- which supplier facts were used
- which pricing module receipt produced the number

### shipping_record

The shipping module must not float on its own.

Tracking, labels, and delivery events must attach to the order record.

### finance_record

Invoices, payment links, receipts, and ledger events must attach to the order record.

## Current Boundary Rules

These must stay true:

- `mint_legacy.legacy_mint_os.*` is cold-storage read history only
- new agent work must not write back into legacy-hold tables
- fresh-slate seed/order truth is where active work belongs
- MinIO object paths are not business truth by themselves; records own the truth, MinIO stores the bytes

## Immediate Architecture Direction

The next boring baseline is:

`customer_record -> seed_record -> order_record -> order_line_record`

with supporting linked records for:

- assets
- communications
- pricing receipts
- shipping
- finance

## Agent Rule

For every Mint agent:

1. Check the records.
2. If no seed exists, create a seed.
3. If existing customer history exists only in legacy-hold, use it as read-only context.
4. Create or update fresh-slate governed records.
5. Attach every receipt/change back to the records.

## What "Boring" Means Here

An agent should be able to answer all of these from records, not improvisation:

- Is this a new customer or an existing customer?
- Is there already a prior order we should reuse?
- Does a folder or asset already exist?
- What did we send last time?
- What color/style/qty did they use?
- Did pricing change?
- What receipt produced the last quote?
- What emails were sent for this job?
- What files are approved for production?
- What tracking number was sent?

## First Concrete Surface Added

The first read-only surface for this baseline is:

- `mint.customer.record.snapshot`

Purpose:

- show fresh-slate customer truth
- show fresh-slate seed/order truth
- show legacy-hold order/line-item history
- give agents one canonical starting answer before they reason

This is not the final business record system.
It is the first spine-aligned read path toward it.

## Second Concrete Surface Added

The first write surface for this baseline is:

- `mint.customer.seed.ensure`

Purpose:

- anchor an inbound mailbox message to a governed fresh-slate seed record
- resolve customer state before writing
- reuse the existing thread seed when the message belongs to the same conversation
- preserve message/thread/customer context in the seed metadata
- give later agents one boring answer to `check the records first`

Operator surface:

- `mintctl morpheus contact ensure-seed --message-id <message-id> --mailbox team@mintprints.com`

This is the current bridge from:

- inbox message

to:

- seed record

before packetization, order promotion, artwork placement, pricing, shipping, and finance attach later in the lifecycle.

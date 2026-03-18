---
status: generated
owner: "@ronny"
last_verified: 2026-03-13
scope: worker-usage-mint-morpheus-01
source_catalog: ops/bindings/terminal.worker.catalog.yaml
---

# MINT-MORPHEUS-01 Usage Surface

- Terminal ID: `MINT-MORPHEUS-01`
- Terminal Type: `domain-runtime`
- Status: `active`
- Domain: `mint`
- Agent ID: `mint-agent`
- Verify Command: `./bin/ops cap run verify.pack.run mint`

## Write Scope
- `../agentic-foundation/docs/agents/mint-agent.contract.md`

## Capabilities (16)
- `mint.artwork.place`
- `mint.customer.artwork.revision.prepare`
- `mint.customer.contact.graph.set`
- `mint.customer.forwarded.attachment.resolve`
- `mint.customer.identity.set`
- `mint.customer.inbox.junk`
- `mint.customer.inbox.triage`
- `mint.customer.inbox.work_items`
- `mint.customer.quote.brief`
  Context-first quote workflow: builds prior email history plus prior order/artwork truth before draft or clarification.
- `mint.customer.quote.context.set`
- `mint.customer.reorder.resolve`
- `mint.customer.reply.draft`
- `mint.customer.thread.delta.capture`
- `mint.intake.validate`
- `mint.modules.health`
- `mint.seeds.query`

## Gates (46)
- `D124`
- `D125`
- `D126`
- `D148`
- `D16`
- `D17`
- `D18`
- `D22`
- `D23`
- `D235`
- `D236`
- `D237`
- `D238`
- `D239`
- `D241`
- `D242`
- `D243`
- `D244`
- `D245`
- `D246`
- `D247`
- `D248`
- `D249`
- `D250`
- `D252`
- `D253`
- `D254`
- `D256`
- `D258`
- `D259`
- `D260`
- `D261`
- `D262`
- `D31`
- `D42`
- `D44`
- `D48`
- `D58`
- `D62`
- `D63`
- `D67`
- `D79`
- `D80`
- `D81`
- `D84`
- `D85`

## Boundaries
- Runtime surface is generated from registration and role contracts.
- Do not hand-edit this file; regenerate via the generator script.
